import time
import os

import cv2
import numpy as np
import pyautogui
from PySide6.QtCore import QObject, Property, Slot, Signal, QThread, QTimer
from PySide6.QtGui import QImage, QGuiApplication, QCursor
from PySide6.QtCore import QPointF

from screenvivid.models.utils import transforms
from screenvivid.models.utils.manager.undo_redo import UndoRedoManager
from screenvivid.models.export import ExportThread
from screenvivid.utils.logging import logger
from screenvivid.utils.general import safe_delete
from screenvivid.models.text_card import TextCard

class VideoControllerModel(QObject):
    frameReady = Signal()
    playingChanged = Signal(bool)
    currentFrameChanged = Signal(int)

    exportProgress = Signal(float)
    exportFinished = Signal()
    paddingChanged = Signal()
    insetChanged = Signal()
    borderRadiusChanged = Signal()
    aspectRatioChanged = Signal()
    backgroundChanged = Signal()
    devicePixelRatioChanged = Signal()
    cursorScaleChanged = Signal()
    frameWidthChanged = Signal()
    frameHeightChanged = Signal()
    canUndoChanged = Signal(bool)
    canRedoChanged = Signal(bool)
    outputSizeChanged = Signal()
    fpsChanged = Signal(int)
    zoomChanged = Signal()
    zoomEffectsChanged = Signal()
    cursorPositionReady = Signal(float, float)  # Signal for cursor position (normalized x, y)
    textCardsChanged = Signal()  # New signal for text cards changes

    def __init__(self, frame_provider):
        super().__init__()
        self.video_processor = VideoProcessor()
        self.video_thread = VideoThread(self.video_processor)
        self.frame_provider = frame_provider
        self.export_thread = None
        self.is_exporting = False

        self.video_processor.frameProcessed.connect(self.on_frame_processed)
        self.video_processor.playingChanged.connect(self.on_playing_changed)
        self.video_processor.zoomChanged.connect(self.on_zoom_changed)
        self.video_processor.zoomEffectsChanged.connect(self.on_zoom_effects_changed)

        self.undo_redo_manager = UndoRedoManager()
        self.video_path = None
        self.is_recording_video = True

    @Property(int, notify=fpsChanged)
    def fps(self):
        return self.video_processor.fps

    @Property(int)
    def total_frames(self):
        return self.video_processor.total_frames

    @Property(int)
    def start_frame(self):
        return self.video_processor.start_frame

    @Property(int)
    def end_frame(self):
        return self.video_processor.end_frame

    @Property(float)
    def video_len(self):
        return self.video_processor.video_len

    @Property(int, notify=frameWidthChanged)
    def frame_width(self):
        return self.video_processor.frame_width

    @Property(int, notify=frameHeightChanged)
    def frame_height(self):
        return self.video_processor.frame_height

    @Property(str, notify=aspectRatioChanged)
    def aspect_ratio(self):
        return self.video_processor.aspect_ratio

    @aspect_ratio.setter
    def aspect_ratio(self, aspect_ratio):
        if self.video_processor.aspect_ratio != aspect_ratio:
            self.video_processor.aspect_ratio = aspect_ratio
            self.aspectRatioChanged.emit()

    @Property(float, notify=aspectRatioChanged)
    def aspect_ratio_float(self):
        return self.video_processor.aspect_ratio_float

    @Property(float, notify=paddingChanged)
    def padding(self):
        return self.video_processor.padding

    @padding.setter
    def padding(self, value):
        if self.video_processor.padding != value:
            self.video_processor.padding = value
            self.paddingChanged.emit()

    @Property(int, notify=insetChanged)
    def inset(self):
        return self.video_processor.inset

    @inset.setter
    def inset(self, inset):
        if self.video_processor.inset != inset:
            self.video_processor.inset = inset
            self.insetChanged.emit()

    @Property(int, notify=borderRadiusChanged)
    def border_radius(self):
        return self.video_processor.border_radius

    @border_radius.setter
    def border_radius(self, value):
        if self.video_processor.border_radius != value:
            self.video_processor.border_radius = value
            self.borderRadiusChanged.emit()

    @Property(dict, notify=backgroundChanged)
    def background(self):
        return self.video_processor.background

    @background.setter
    def background(self, value):
        if self.video_processor.background != value:
            self.video_processor.background = value
            self.backgroundChanged.emit()

    @Property(float, notify=devicePixelRatioChanged)
    def device_pixel_ratio(self):
        return self.video_processor.device_pixel_ratio

    @device_pixel_ratio.setter
    def device_pixel_ratio(self, value):
        if self.video_processor.device_pixel_ratio != value:
            self.video_processor.device_pixel_ratio = value
            self.devicePixelRatioChanged.emit()

    @Property(float, notify=cursorScaleChanged)
    def cursor_scale(self):
        return self.video_processor.cursor_scale

    @cursor_scale.setter
    def cursor_scale(self, value):
        if self.video_processor.cursor_scale != value:
            self.video_processor.cursor_scale = value
            self.cursorScaleChanged.emit()

    @Property(bool, notify=playingChanged)
    def is_playing(self):
        return self.video_processor.is_playing

    @Property(list, notify=outputSizeChanged)
    def output_size(self):
        return self.video_processor.output_size

    @Property(list, notify=zoomEffectsChanged)
    def zoom_effects(self):
        return self.video_processor.zoom_effects

    @Property(list, notify=textCardsChanged)
    def text_cards(self):
        return self.video_processor.text_cards

    @Slot(int)
    def trim_left(self, start_frame):
        def do_trim_left():
            self.video_processor.append_start_frame(start_frame)

        def undo_trim_left():
            self.video_processor.pop_start_frame()

        self.undo_redo_manager.do_action(do_trim_left, (do_trim_left, undo_trim_left))

    @Slot(int)
    def trim_right(self, end_frame):
        def do_trim_right():
            self.video_processor.append_end_frame(end_frame)

        def undo_trim_right():
            self.video_processor.pop_end_frame()

        self.undo_redo_manager.do_action(do_trim_right, (do_trim_right, undo_trim_right))

    def _update_undo_redo_signals(self):
        self.canUndoChanged.emit(self.undo_redo_manager.can_undo())
        self.canRedoChanged.emit(self.undo_redo_manager.can_redo())

    @Slot()
    def undo(self):
        self.undo_redo_manager.undo()
        self._update_undo_redo_signals()

    @Slot()
    def redo(self):
        self.undo_redo_manager.redo()
        self._update_undo_redo_signals()

    @Slot(str, dict, result="bool")
    def load_video(self, path, metadata):
        try:
            if not os.path.exists(path):
                return False

            logger.info(f"Loading video from {path} with metadata: {metadata}")
            success = self.video_processor.load_video(path, metadata)
            if success:
                self.undo_redo_manager.clear()
                self._update_undo_redo_signals()
                
                # If this is a recording with cursor data, create automatic zooms
                if metadata and metadata.get("recording", False) and metadata.get("mouse_events"):
                    self.create_automatic_zooms_from_cursor()

            return success
        except Exception as e:
            import traceback
            logger.error(f"Error loading video: {e}")
            logger.error(traceback.format_exc())
            return False

    @Slot()
    def toggle_play_pause(self):
        self.video_processor.toggle_play_pause()

    def on_playing_changed(self, is_playing):
        self.playingChanged.emit(is_playing)

    @Slot()
    def play(self):
        if not self.video_thread.isRunning():
            self.video_thread.start()
        else:
            self.video_processor.play()

    @Slot()
    def pause(self):
        self.video_processor.pause()

    @Slot()
    def next_frame(self):
        self.video_processor.next_frame()

    @Slot()
    def prev_frame(self):
        self.video_processor.prev_frame()

    @Slot(int)
    def jump_to_frame(self, target_frame):
        self.video_processor.jump_to_frame(target_frame)

    @Slot()
    def get_current_frame(self):
        self.video_processor.get_current_frame()

    @Slot(dict)
    def export_video(self, export_params):
        if self.is_exporting:
            return
        self.is_exporting = True
        self.export_thread = ExportThread(self.video_processor, export_params)
        self.export_thread.progress.connect(self.update_export_progress)
        self.export_thread.finished.connect(self.on_export_finished)
        self.export_thread.start()

    @Slot()
    def cancel_export(self):
        if self.export_thread and self.export_thread.isRunning():
            self.export_thread.stop()
            self.export_thread.wait()
            self.is_exporting = False
            self.exportFinished.emit()

    @Slot()
    def clean(self):
        self.video_processor.clean()
        if self.is_recording_video:
            safe_delete(self.video_path)

    def update_export_progress(self, progress):
        self.exportProgress.emit(progress)

    def on_export_finished(self):
        self.is_exporting = False
        self.exportFinished.emit()

    def on_frame_processed(self, frame):
        height, width = frame.shape[:2]
        bytes_per_line = width * 3
        q_image = QImage(frame.data, width, height, bytes_per_line, QImage.Format_RGB888)
        self.currentFrameChanged.emit(self.video_processor.current_frame)
        self.frame_provider.updateFrame(q_image)
        self.frameReady.emit()

    def on_zoom_changed(self):
        self.zoomChanged.emit()
        
    def on_zoom_effects_changed(self):
        self.zoomEffectsChanged.emit()

    @Slot(int, int, dict)
    def add_zoom_effect(self, start_frame, end_frame, zoom_params):
        """Add a zoom effect between start and end frames"""
        def do_add_zoom():
            self.video_processor.add_zoom_effect(start_frame, end_frame, zoom_params)

        def undo_add_zoom():
            self.video_processor.remove_zoom_effect(start_frame, end_frame)

        self.undo_redo_manager.do_action(do_add_zoom, (do_add_zoom, undo_add_zoom))
        
    @Slot(int, int)
    def remove_zoom_effect(self, start_frame, end_frame):
        """Remove a zoom effect between start and end frames"""
        def do_remove_zoom():
            self.video_processor.remove_zoom_effect(start_frame, end_frame)

        def undo_remove_zoom():
            # Assuming we have a way to get back the zoom parameters
            zoom_effect = self.video_processor.get_removed_zoom_effect(start_frame, end_frame)
            if zoom_effect:
                self.video_processor.add_zoom_effect(start_frame, end_frame, zoom_effect['params'])

        self.undo_redo_manager.do_action(do_remove_zoom, (do_remove_zoom, undo_remove_zoom))

    @Property(int, notify=currentFrameChanged)
    def current_frame(self):
        return self.video_processor.current_frame

    @Property(int, notify=currentFrameChanged)
    def absolute_current_frame(self):
        # This returns the absolute frame number including the start_frame offset
        return self.video_processor.start_frame + self.video_processor.current_frame

    @Slot(int, int, dict)
    def update_zoom_effect(self, old_start_frame, old_end_frame, new_start_frame, new_end_frame, params):
        """Update an existing zoom effect with new parameters"""
        def do_update_zoom():
            self.video_processor.update_zoom_effect(old_start_frame, old_end_frame, new_start_frame, new_end_frame, params)

        def undo_update_zoom():
            # Get the old effect that was replaced
            old_params = params.copy()
            self.video_processor.update_zoom_effect(new_start_frame, new_end_frame, old_start_frame, old_end_frame, old_params)

        self.undo_redo_manager.do_action(do_update_zoom, (do_update_zoom, undo_update_zoom))

    def create_automatic_zooms_from_cursor(self):
        """
        Automatically create zoom effects based on cursor movements during recording.
        This looks for:
        1. Click events
        2. Areas where the cursor stays in the same region for a while
        """
        logger.info("Creating automatic zoom effects from cursor movements")
        
        if not self.video_processor._mouse_events:
            logger.warning("No cursor movement data found")
            return
            
        # Parameters for automatic zoom generation
        MIN_FRAMES_BETWEEN_ZOOMS = self.fps * 2  # At least 2 seconds between zoom effects
        ZOOM_DURATION_FRAMES = self.fps * 4      # Each zoom lasts 4 seconds
        DEFAULT_ZOOM_SCALE = 2.0                 # Default zoom level
        
        click_events = []
        
        # First, check if we have explicit click events recorded
        move_data = self.video_processor._mouse_events
        
        if isinstance(move_data, dict) and move_data.get("click"):
            logger.info(f"Found {len(move_data['click'])} explicit click events")
            
            # Process explicit click events
            for click_data in move_data["click"]:
                frame = click_data.get('frame')
                x = click_data.get('x')
                y = click_data.get('y')
                
                if frame is not None and x is not None and y is not None:
                    click_events.append({
                        'frame': int(frame),
                        'x': float(x),
                        'y': float(y)
                    })
        
        # If no explicit clicks found, try to infer from cursor states
        if not click_events and isinstance(move_data, dict) and move_data.get("move"):
            logger.info("No explicit click events found, inferring from cursor states")
            
            # Process cursor movement data to detect potential clicks
            for frame_idx in sorted(move_data["move"].keys()):
                event_data = move_data["move"][frame_idx]
                
                # If this is a tuple, it contains (x, y, frame, cursor_state, anim_step)
                if isinstance(event_data, tuple) and len(event_data) >= 3:
                    x, y, _, cursor_state, *_ = event_data
                    
                    # Check if this cursor state represents a click (depends on system)
                    # For most systems, cursor state changes during clicks
                    if ('hand' in str(cursor_state).lower() or 
                        'pointer' in str(cursor_state).lower() or 
                        'click' in str(cursor_state).lower() or 
                        cursor_state in [1, 2]):  # Common click cursor states
                        
                        click_events.append({
                            'frame': int(frame_idx),
                            'x': float(x),
                            'y': float(y)
                        })
        
        logger.info(f"Found {len(click_events)} potential click events for zoom creation")
        
        # Create zoom effects for each click, being careful not to overlap
        zoom_effects = []
        last_end_frame = -MIN_FRAMES_BETWEEN_ZOOMS  # Start with a negative value so first click can be processed
        
        for click in click_events:
            frame = click['frame']
            
            # Skip if too close to previous zoom
            if frame < last_end_frame + MIN_FRAMES_BETWEEN_ZOOMS:
                continue
                
            # Calculate start/end frames, ensuring we don't exceed video length
            start_frame = max(0, frame - int(self.fps * 0.5))  # Start 0.5 second before click
            end_frame = min(self.total_frames, start_frame + ZOOM_DURATION_FRAMES)
            
            # Skip if duration is too short
            if end_frame - start_frame < self.fps:
                continue
                
            # Create zoom effect
            zoom_effect = {
                'start_frame': start_frame,
                'end_frame': end_frame,
                'params': {
                    'x': click['x'],
                    'y': click['y'],
                    'scale': DEFAULT_ZOOM_SCALE,
                    'easeInFrames': int(self.fps * 0.5),    # 0.5 second ease in
                    'easeOutFrames': int(self.fps * 0.5),    # 0.5 second ease out
                    'auto': True  # Mark this as an auto-generated zoom
                }
            }
            
            zoom_effects.append(zoom_effect)
            last_end_frame = end_frame
            
            logger.info(f"Created auto zoom effect at frame {frame}: {start_frame}-{end_frame}")
        
        # Add all the zoom effects we created
        self.video_processor._zoom_effects.extend(zoom_effects)
        self.video_processor._zoom_effects.sort(key=lambda x: x['start_frame'])
        
        if zoom_effects:
            self.zoomEffectsChanged.emit()
            logger.info(f"Added {len(zoom_effects)} automatic zoom effects")
        else:
            logger.info("No automatic zoom effects were created")

    @Slot()
    def get_cursor_position_for_zoom(self):
        """
        Get the current cursor position relative to the video preview area
        and emit signal with normalized coordinates for the zoom crosshair
        """
        try:
            # Get global cursor position using pyautogui
            from PySide6.QtGui import QGuiApplication, QCursor
            from PySide6.QtCore import QPointF
            
            # Get the cursor position in screen coordinates
            cursor_pos = QCursor.pos()
            
            # Get the application window
            window = QGuiApplication.topLevelWindows()[0]
            
            # Find the video preview component
            video_preview = window.findChild(QObject, "videoPreview")
            
            if video_preview:
                # Map global position to video preview local coordinates
                local_pos = video_preview.mapFromGlobal(cursor_pos)
                
                # Get the size of the video preview
                width = video_preview.width()
                height = video_preview.height()
                
                # Calculate normalized coordinates (0-1)
                normalized_x = max(0, min(1, local_pos.x() / width))
                normalized_y = max(0, min(1, local_pos.y() / height))
                
                # Emit the signal with normalized coordinates
                self.cursorPositionReady.emit(normalized_x, normalized_y)
                
                logger.info(f"Cursor position: ({normalized_x:.2f}, {normalized_y:.2f})")
            else:
                logger.error("Could not find video preview component")
                # Use default center position
                self.cursorPositionReady.emit(0.5, 0.5)
                
        except Exception as e:
            logger.error(f"Error getting cursor position: {e}")
            import traceback
            logger.error(traceback.format_exc())
            # Fallback to center position
            self.cursorPositionReady.emit(0.5, 0.5)

    @Slot(int, int, dict)
    def add_text_card(self, start_frame, end_frame, card_data):
        """Add a text card between the specified frames"""
        def do_add_text_card():
            self.video_processor.add_text_card(start_frame, end_frame, card_data)
            logger.info(f"Added text card: {start_frame}-{end_frame}")

        def undo_add_text_card():
            self.video_processor.remove_text_card(start_frame, end_frame)
            logger.info(f"Undid add text card: {start_frame}-{end_frame}")

        self.undo_redo_manager.do_action(do_add_text_card, (do_add_text_card, undo_add_text_card))

    @Slot(int, int)
    def remove_text_card(self, start_frame, end_frame):
        """Remove a text card between the specified frames"""
        def do_remove_text_card():
            self.video_processor.remove_text_card(start_frame, end_frame)
            logger.info(f"Removed text card: {start_frame}-{end_frame}")

        def undo_remove_text_card():
            text_card = self.video_processor.get_removed_text_card(start_frame, end_frame)
            if text_card:
                self.video_processor.add_text_card(start_frame, end_frame, text_card['params'])
                logger.info(f"Restored text card: {start_frame}-{end_frame}")
            else:
                logger.warning(f"Could not find removed text card: {start_frame}-{end_frame}")

        self.undo_redo_manager.do_action(do_remove_text_card, (do_remove_text_card, undo_remove_text_card))

    @Slot(int, int, int, int, dict)
    def update_text_card(self, old_start_frame, old_end_frame, new_start_frame, new_end_frame, card_data):
        """Update an existing text card with new parameters"""
        def do_update_text_card():
            self.video_processor.update_text_card(old_start_frame, old_end_frame, new_start_frame, new_end_frame, card_data)
            logger.info(f"Updated text card: {old_start_frame}-{old_end_frame} → {new_start_frame}-{new_end_frame}")

        def undo_update_text_card():
            # Get the old card that was replaced
            old_card = self.video_processor.get_removed_text_card(old_start_frame, old_end_frame)
            if old_card:
                self.video_processor.update_text_card(new_start_frame, new_end_frame, old_start_frame, old_end_frame, old_card['params'])
                logger.info(f"Undid update of text card: {new_start_frame}-{new_end_frame} → {old_start_frame}-{old_end_frame}")
            else:
                logger.warning(f"Could not find old text card to restore: {old_start_frame}-{old_end_frame}")

        self.undo_redo_manager.do_action(do_update_text_card, (do_update_text_card, undo_update_text_card))

    @Slot(int, result=dict)
    def detect_cuts(self, margin_frames=5):
        """
        Detect cut points in the video and return frame ranges for potential text card insertion
        
        Args:
            margin_frames: Number of frames to add as margin around cuts
            
        Returns:
            Dictionary with lists of cut positions and their frame ranges
        """
        from screenvivid.utils.logging import logger
        
        if not self.video_processor or not self.video_processor.video:
            logger.warning("No video loaded, cannot detect cuts")
            return {"cuts": []}
            
        cuts = []
        
        # Get cut positions from the clip track model
        clips = self.video_processor._clip_positions
        
        logger.info(f"Detecting cuts from {len(clips)} clips")
        
        if not clips or len(clips) <= 1:
            logger.warning("No clips or only one clip found - no cuts to process")
            return {"cuts": []}
            
        # Process each pair of adjacent clips
        for i in range(len(clips) - 1):
            current_clip_end = clips[i]["end_frame"]
            next_clip_start = clips[i+1]["start_frame"]
            
            logger.info(f"Checking cut between clips {i} and {i+1}: " + 
                     f"end={current_clip_end}, start={next_clip_start}")
            
            # If there's a gap between clips, it's a potential card insertion point
            if next_clip_start > current_clip_end:
                # Create a cut with margins
                start_with_margin = current_clip_end + margin_frames
                end_with_margin = next_clip_start - margin_frames
                
                # Ensure we have a valid range after applying margins
                if end_with_margin > start_with_margin:
                    cut_info = {
                        "position": i,
                        "start_frame": start_with_margin,
                        "end_frame": end_with_margin,
                        "duration_frames": end_with_margin - start_with_margin
                    }
                    cuts.append(cut_info)
                    logger.info(f"Added cut: {cut_info}")
                else:
                    logger.warning(f"Cut between clips {i} and {i+1} too small after adding margins")
            else:
                logger.warning(f"No gap between clips {i} and {i+1}")
                
        logger.info(f"Found {len(cuts)} valid cuts")
        return {"cuts": cuts}

    @Slot(int, dict)
    def add_text_card_at_cut(self, cut_position, card_data):
        """Add a text card at a detected cut point"""
        cuts = self.detect_cuts()["cuts"]
        if 0 <= cut_position < len(cuts):
            cut = cuts[cut_position]
            self.add_text_card(cut["start_frame"], cut["end_frame"], card_data)
            return True
        return False

class VideoLoadingError(Exception):
    pass

class VideoProcessor(QObject):
    frameProcessed = Signal(np.ndarray)
    playingChanged = Signal(bool)
    zoomChanged = Signal()
    zoomEffectsChanged = Signal()
    textCardsChanged = Signal()  # New signal for text cards

    def __init__(self):
        super().__init__()
        self.video = None
        self._is_playing = False
        self._start_frames = []
        self._end_frames = []
        self._current_frame = 0
        self._total_frames = 0
        self._max_frame = 0
        self.play_timer = QTimer()
        self.play_timer.timeout.connect(self.process_next_frame)

        self._aspect_ratio = "Auto"
        self._padding = 0.1
        self._inset = 0
        self._border_radius = 20
        self._background = {"type": "wallpaper", "value": 1}
        self._device_pixel_ratio = 1.0
        self._cursor_scale = 1.0
        self._transforms = None
        self._mouse_events = []
        self._region = None
        self._x_offset = None
        self._y_offset = None
        self._cursors_map = dict()
        
        # Zoom effects storage
        self._zoom_effects = []
        self._removed_zoom_effects = []

        # Text cards storage
        self._text_cards = []
        self._removed_text_cards = []
        self._clip_positions = []  # Store positions of clips for cut detection

    @property
    def aspect_ratio(self):
        return self._aspect_ratio

    @aspect_ratio.setter
    def aspect_ratio(self, value):
        self._aspect_ratio = value
        self._transforms["aspect_ratio"] = transforms.AspectRatio(
            aspect_ratio=value,
            screen_size=self._transforms["aspect_ratio"].screen_size
        )

    @property
    def aspect_ratio_float(self):
        if self._transforms and self._transforms.get("aspect_ratio"):
            return self._transforms["aspect_ratio"].aspect_ratio_float
        return 16 / 9

    @property
    def padding(self):
        return self._padding

    @padding.setter
    def padding(self, value):
        self._padding = value
        self._transforms["padding"] = transforms.Padding(padding=value)

    @property
    def inset(self):
        return self._inset

    @inset.setter
    def inset(self, inset):
        self._inset = inset
        self._transforms["inset"] = transforms.Inset(inset=inset)

    @property
    def border_radius(self):
        return self._border_radius

    @border_radius.setter
    def border_radius(self, value):
        self._border_radius = value
        self._transforms["border_shadow"] = transforms.BorderShadow(border_radius=value)

    @property
    def background(self):
        return self._background

    @background.setter
    def background(self, value):
        self._background = value
        self._transforms["background"] = transforms.Background(background=value)

    @property
    def device_pixel_ratio(self):
        return self._device_pixel_ratio

    @device_pixel_ratio.setter
    def device_pixel_ratio(self, value):
        self._device_pixel_ratio = value

    @property
    def cursor_scale(self):
        return self._cursor_scale

    @cursor_scale.setter
    def cursor_scale(self, value):
        self._cursor_scale = value

        self._transforms["cursor"] = transforms.Cursor(
            move_data=self._mouse_events,
            cursors_map=self._cursors_map,
            offsets=(self._x_offset, self._y_offset),
            scale=value
        )

    @property
    def total_frames(self):
        return self._total_frames

    @total_frames.setter
    def total_frames(self, value):
        self._total_frames = value

    @property
    def start_frame(self):
        return sum(self._start_frames) if self._start_frames else 0

    @property
    def start_frames(self):
        return self._start_frames

    def append_start_frame(self, start_frame):
        self._start_frames.append(start_frame)

    def pop_start_frame(self):
        if self._start_frames:
            return self._start_frames.pop()

    @property
    def end_frame(self):
        if self._end_frames:
            return self._end_frames[-1]
        else:
            return self.total_frames

    @property
    def end_frames(self):
        return self._end_frames

    def append_end_frame(self, end_frame):
        self._end_frames.append(end_frame)

    def pop_end_frame(self):
        if self._end_frames:
            return self._end_frames.pop()

    @property
    def mouse_events(self):
        return self._mouse_events

    @mouse_events.setter
    def mouse_events(self, value):
        self._mouse_events = value

    @property
    def current_frame(self):
        return self._current_frame

    @current_frame.setter
    def current_frame(self, current_frame):
        self._current_frame = current_frame

    @property
    def is_playing(self):
        return self._is_playing

    @is_playing.setter
    def is_playing(self, value):
        if self._is_playing != value:
            self._is_playing = value
            self.playingChanged.emit(value)

    @property
    def output_size(self):
        ar = self._transforms["aspect_ratio"]
        return ar.calculate_output_resolution(
            ar.aspect_ratio,
            self.frame_width,
            self.frame_height
        )[:2]

    def load_video(self, path, metadata):
        try:
            self.video = cv2.VideoCapture(path)

            self.fps = int(self.video.get(cv2.CAP_PROP_FPS))
            self.frame_width = int(self.video.get(cv2.CAP_PROP_FRAME_WIDTH))
            self.frame_height = int(self.video.get(cv2.CAP_PROP_FRAME_HEIGHT))
            self.total_frames = int(self.video.get(cv2.CAP_PROP_FRAME_COUNT))
            self.video_len = self.total_frames / self.fps if self.fps > 0 else 0
            self.current_frame = 0
            self._start_frames.append(0)
            self._end_frames.append(self.total_frames)

            # Get mouse movement and click data
            if metadata and 'mouse_events' in metadata:
                self._mouse_events = metadata.get("mouse_events", {})
                self._cursors_map = metadata.get("mouse_events", {}).get("cursors_map", {})
                
                # Log the structure of mouse_events for debugging
                logger.info(f"Mouse events data structure: {list(self._mouse_events.keys())}")
                logger.info(f"Number of move events: {len(self._mouse_events.get('move', {}))}")
                logger.info(f"Number of click events: {len(self._mouse_events.get('click', []))}")
            else:
                self._mouse_events = {}
                self._cursors_map = {}
                
            self._region = metadata.get("region", []) if metadata else []

            if self._region:
                x_offset, y_offset = self._region[:2]
            else:
                x_offset, y_offset = None, None
            self._x_offset = x_offset
            self._y_offset = y_offset
            screen_width, screen_height = pyautogui.size()
            screen_size = int(screen_width * self._device_pixel_ratio), int(screen_height * self._device_pixel_ratio)
            self._transforms = transforms.Compose({
                "aspect_ratio": transforms.AspectRatio(self._aspect_ratio, screen_size),
                "cursor": transforms.Cursor(move_data=self._mouse_events.get("move", {}), cursors_map=self._cursors_map, offsets=(x_offset, y_offset), scale=self._cursor_scale),
                "padding": transforms.Padding(padding=self.padding),
                # "inset": transforms.Inset(inset=self.inset, color=(0, 0, 0)),
                "border_shadow": transforms.BorderShadow(border_radius=self.border_radius),
                "background": transforms.Background(background=self._background),
            })

            # Get first frame
            self.jump_to_frame(0)
            return True
        except VideoLoadingError:
            return False

    def get_frame(self):
        try:
            t0 = time.time()
            if self.start_frame + self.current_frame >= self.end_frame - 1:
                self.pause()
                return

            success, frame = self.video.read()
            if not success:
                return

            processed_frame = self.process_frame(frame)
            self.frameProcessed.emit(processed_frame)
            self.current_frame += 1
            t1 = time.time()
            logger.debug(f"Render FPS: {t1 - t0}")
            return processed_frame
        except Exception as e:
            logger.error(e)
            return

    @Slot()
    def play(self):
        self.is_playing = True
        self.play_timer.start(1000 / self.fps)
        # self.play_timer.start(1)

    @Slot()
    def pause(self):
        self.is_playing = False
        self.play_timer.stop()

    @Slot()
    def toggle_play_pause(self):
        if self.is_playing:
            self.pause()
        else:
            self.play()

    @Slot()
    def next_frame(self):
        self.pause()
        self.get_frame()

    @Slot()
    def prev_frame(self):
        self.pause()
        if self.video.isOpened() and self.current_frame > 0:
            self.current_frame -= 1
            self.video.set(cv2.CAP_PROP_POS_FRAMES, self.current_frame)
            ret, frame = self.video.read()
            if ret:
                processed_frame = self.process_frame(frame)
                self.frameProcessed.emit(processed_frame)

    def jump_to_frame(self, target_frame):
        logger.debug(f"Jumping to frame {target_frame} (absolute)")
        
        # Ensure we stay within valid frame range
        internal_target_frame = max(self.start_frame, min(self.end_frame, target_frame))
        logger.debug(f"Adjusted target frame: {internal_target_frame}")
        
        # Calculate relative frame (for internal tracking)
        relative_frame = internal_target_frame - self.start_frame
        logger.debug(f"Relative frame position: {relative_frame}")
        
        # Set video position
        if self.video.isOpened():
            self.video.set(cv2.CAP_PROP_POS_FRAMES, internal_target_frame)
            ret, frame = self.video.read()
            if ret:
                processed_frame = self.process_frame(frame)
                self.current_frame = relative_frame
                self.frameProcessed.emit(processed_frame)
                logger.debug(f"Successfully jumped to frame {target_frame}, current_frame={self.current_frame}")
            else:
                logger.error(f"Failed to read frame at position {internal_target_frame}")
        else:
            logger.error("Cannot jump to frame - video is not open")

    def get_current_frame(self):
        if self.video is not None and self.video.isOpened():
            current_position = self.current_frame
            if current_position >= self.total_frames:
                current_position -= 1
                self.video.set(cv2.CAP_PROP_POS_FRAMES, current_position)

            ret, frame = self.video.read()

            if ret:
                processed_frame = self.process_frame(frame)

                self.video.set(cv2.CAP_PROP_POS_FRAMES, current_position)
                self.frameProcessed.emit(processed_frame)
                self.current_frame = current_position

    def process_next_frame(self):
        self.get_frame()

    def process_frame(self, frame):
        """Process a frame with zoom effects and return the processed frame."""
        try:
            # Get absolute frame number 
            current_absolute_frame = self.start_frame + self.current_frame
            logger.info(f"Processing frame {current_absolute_frame}")
            
            # Check if there's an active text card for this frame
            text_card_data = self.get_active_text_card(current_absolute_frame)
            
            # If we have a text card, render it instead of the video frame
            if text_card_data:
                logger.info(f"Rendering text card at frame {current_absolute_frame}")
                
                # Create a TextCard instance
                card = TextCard(
                    background_color=text_card_data.get("background_color", "black"),
                    text=text_card_data.get("text", "Lorem ipsum dolor sit amet"),
                    text_color=text_card_data.get("text_color", "white"),
                    horizontal_align=text_card_data.get("horizontal_align", "center"),
                    vertical_align=text_card_data.get("vertical_align", "middle")
                )
                
                # Get the frame dimensions
                height, width = frame.shape[:2]
                
                # Render the text card frame
                frame_position = text_card_data.get("frame_position", 0)
                total_frames = text_card_data.get("total_frames", 1)
                
                text_frame = card.render_frame(
                    frame_position, 
                    total_frames,
                    width, 
                    height
                )
                
                # Convert to RGB and return
                return cv2.cvtColor(text_frame, cv2.COLOR_BGR2RGB)
            
            # Otherwise, apply standard transforms
            result = self._transforms(input=frame, start_frame=current_absolute_frame)
            
            # Get the active zoom effect for the current frame number
            zoom_effect = self.get_active_zoom_effect(current_absolute_frame)
            
            if zoom_effect is None:
                # No zoom effect active, just return the transformed frame
                return cv2.cvtColor(result, cv2.COLOR_BGR2RGB)
                
            # Extract zoom parameters
            x = zoom_effect.get("x", 0.5)
            y = zoom_effect.get("y", 0.5)
            scale = zoom_effect.get("scale", 1.0)
            
            # Calculate frame position within the effect duration
            start_frame = zoom_effect.get("start_frame", 0)
            end_frame = zoom_effect.get("end_frame", 0)
            duration = end_frame - start_frame
            current_position = current_absolute_frame - start_frame  # Frame position from start
            
            if duration <= 0:
                return cv2.cvtColor(result, cv2.COLOR_BGR2RGB)
            
            # Get user-defined ease frames (or use defaults if not specified)
            ease_in_frames = zoom_effect.get("easeInFrames", 5)   # Default: 5 frames ease-in
            ease_out_frames = zoom_effect.get("easeOutFrames", 4) # Default: 4 frames ease-out
            
            # Log the zoom effect parameters
            logger.info(f"🔍 APPLYING ZOOM EFFECT: Start={start_frame}, End={end_frame}, Duration={duration} frames")
            logger.info(f"Ease-in: {ease_in_frames} frames, Ease-out: {ease_out_frames} frames")
            logger.info(f"Current position: Frame {current_position} of {duration}")
            
            # Ensure transitions don't overlap for very short effects
            if duration < (ease_in_frames + ease_out_frames + 1):
                # For very short effects, scale down the transitions proportionally
                total_ease_frames = ease_in_frames + ease_out_frames
                ratio = duration / (total_ease_frames + 1)
                
                ease_in_frames = max(1, int(ease_in_frames * ratio))
                ease_out_frames = max(1, int(ease_out_frames * ratio))
                
                logger.info(f"Adjusted transitions for short duration: Ease-in={ease_in_frames}, Ease-out={ease_out_frames}")
            
            # Apply zoom based on frame-based easing
            current_scale = 1.0
            
            if current_position < ease_in_frames:
                # Ease IN - linear interpolation over specified frames
                progress = current_position / ease_in_frames
                current_scale = 1.0 + (scale - 1.0) * progress
                logger.info(f"Ease IN frame {current_position}/{ease_in_frames} - scale: {current_scale:.2f}")
                
            elif current_position >= (duration - ease_out_frames):
                # Ease OUT - linear interpolation over specified frames
                frames_into_easeout = current_position - (duration - ease_out_frames)
                progress = frames_into_easeout / ease_out_frames
                current_scale = scale - (scale - 1.0) * progress
                logger.info(f"Ease OUT frame {frames_into_easeout}/{ease_out_frames} - scale: {current_scale:.2f}")
                
            else:
                # Hold steady at full zoom level
                current_scale = scale
                logger.info(f"Holding steady zoom at frame {current_position} - scale: {current_scale:.2f}")
            
            # Only apply zoom if we're actually zooming
            if current_scale <= 1.0:
                return cv2.cvtColor(result, cv2.COLOR_BGR2RGB)
            
            # Apply the zoom effect
            h, w = result.shape[:2]
            
            # Calculate region to extract
            region_w = w / current_scale
            region_h = h / current_scale
            
            # Center on the chosen point (x,y are normalized 0-1 coordinates)
            center_x = int(x * w)
            center_y = int(y * h)
            
            # Calculate extraction region
            x1 = max(0, int(center_x - (region_w / 2)))
            y1 = max(0, int(center_y - (region_h / 2)))
            x2 = min(w, int(center_x + (region_w / 2)))
            y2 = min(h, int(center_y + (region_h / 2)))
            
            # Adjust if needed to maintain aspect ratio
            if x1 == 0:
                x2 = min(w, int(region_w))
            if y1 == 0:
                y2 = min(h, int(region_h))
            if x2 == w:
                x1 = max(0, int(w - region_w))
            if y2 == h:
                y1 = max(0, int(h - region_h))
            
            logger.info(f"Extracting region ({x1}, {y1}) to ({x2}, {y2})")
            
            # Extract region and resize
            zoomed_region = result[y1:y2, x1:x2]
            if zoomed_region.size == 0:
                logger.error("Zoom resulted in empty region, returning original frame")
                return cv2.cvtColor(result, cv2.COLOR_BGR2RGB)
                
            result = cv2.resize(zoomed_region, (w, h), interpolation=cv2.INTER_LINEAR)
            logger.info(f"✅ Zoom applied successfully!")
            
            # Convert to RGB and return
            return cv2.cvtColor(result, cv2.COLOR_BGR2RGB)
            
        except Exception as e:
            logger.error(f"Error in process_frame: {str(e)}")
            import traceback
            logger.error(traceback.format_exc())
            # Return the original frame in RGB mode if there's an error
            return cv2.cvtColor(frame, cv2.COLOR_BGR2RGB) if frame is not None else None

    def clean(self):
        try:
            if self.video:
                self.video.release()
        except:
            logger.warning(f"Failed to release video capture")

    @property
    def zoom_effects(self):
        return self._zoom_effects
    
    def add_zoom_effect(self, start_frame, end_frame, zoom_params):
        """
        Add a zoom effect to the video
        
        Parameters:
        - start_frame: Start frame for the zoom effect
        - end_frame: End frame for the zoom effect
        - zoom_params: Dictionary with zoom parameters (x, y, scale, etc.)
        """
        zoom_effect = {
            'start_frame': start_frame,
            'end_frame': end_frame,
            'params': zoom_params
        }
        
        # Check if this overlaps with an existing zoom effect
        for i, effect in enumerate(self._zoom_effects):
            if (start_frame <= effect['end_frame'] and end_frame >= effect['start_frame']):
                # Overlapping effect, replace it
                self._zoom_effects[i] = zoom_effect
                self.zoomEffectsChanged.emit()
                return
        
        # Add new effect
        self._zoom_effects.append(zoom_effect)
        self._zoom_effects.sort(key=lambda x: x['start_frame'])
        self.zoomEffectsChanged.emit()
    
    def remove_zoom_effect(self, start_frame, end_frame):
        """Remove a zoom effect that matches the given frame range"""
        for i, effect in enumerate(self._zoom_effects):
            if effect['start_frame'] == start_frame and effect['end_frame'] == end_frame:
                removed = self._zoom_effects.pop(i)
                self._removed_zoom_effects.append(removed)
                self.zoomEffectsChanged.emit()
                return True
        return False
    
    def get_removed_zoom_effect(self, start_frame, end_frame):
        """Get a previously removed zoom effect for undo operations"""
        for i, effect in enumerate(self._removed_zoom_effects):
            if effect['start_frame'] == start_frame and effect['end_frame'] == end_frame:
                return self._removed_zoom_effects.pop(i)
        return None
    
    def get_active_zoom_effect(self, frame):
        """
        Get the active zoom effect for the current frame, if any.
        
        Args:
            frame: Absolute frame number (integer)
            
        Returns:
            Dictionary with zoom effect parameters or None if no active effect
        """
        # Check if frame is an integer
        if not isinstance(frame, (int, float)):
            logger.error(f"Invalid frame type passed to get_active_zoom_effect: {type(frame)}")
            return None
            
        # Print clear debug info about available zoom effects
        logger.info(f"Checking for zoom effect at frame {frame}")
        logger.info(f"Number of zoom effects: {len(self._zoom_effects)}")
        
        for i, effect in enumerate(self._zoom_effects):
            start = effect['start_frame']
            end = effect['end_frame']
            logger.info(f"Zoom effect #{i}: frames {start}-{end}, params: {effect['params']}")
            
            if start <= frame <= end:
                # Calculate how far we are through the effect (0.0 to 1.0)
                total_frames = end - start
                progress = 0 if total_frames == 0 else (frame - start) / total_frames
                
                logger.info(f"⭐ FOUND active zoom effect #{i} with progress {progress:.2f}")
                
                # Add progress to the effect data for animation calculation
                effect_data = effect['params'].copy()
                effect_data['start_frame'] = start
                effect_data['end_frame'] = end
                effect_data['progress'] = progress
                return effect_data
        
        logger.info(f"No active zoom effect found for frame {frame}")
        return None

    def update_zoom_effect(self, old_start_frame, old_end_frame, new_start_frame, new_end_frame, params):
        """Update an existing zoom effect with new start/end frames and parameters"""
        # Find the existing effect
        for i, effect in enumerate(self._zoom_effects):
            if effect['start_frame'] == old_start_frame and effect['end_frame'] == old_end_frame:
                # Update with new values
                updated_effect = {
                    'start_frame': new_start_frame,
                    'end_frame': new_end_frame,
                    'params': params
                }
                self._zoom_effects[i] = updated_effect
                self._zoom_effects.sort(key=lambda x: x['start_frame'])
                self.zoomEffectsChanged.emit()
                logger.info(f"Updated zoom effect: {old_start_frame}-{old_end_frame} → {new_start_frame}-{new_end_frame}")
                return True
        
        logger.warning(f"Could not find zoom effect to update: {old_start_frame}-{old_end_frame}")
        return False

    @property
    def text_cards(self):
        return self._text_cards
    
    def set_clip_positions(self, positions):
        """
        Set the clip positions for cut detection
        
        Args:
            positions: List of dictionaries with start_frame and end_frame keys
        """
        from screenvivid.utils.logging import logger
        
        logger.info(f"Setting clip positions: {len(positions)} clips")
        for i, pos in enumerate(positions):
            logger.info(f"  Clip {i}: frames {pos['start_frame']} to {pos['end_frame']}")
            
        self._clip_positions = positions
    
    def add_text_card(self, start_frame, end_frame, card_data):
        """
        Add a text card to the video
        
        Parameters:
        - start_frame: Start frame for the text card
        - end_frame: End frame for the text card
        - card_data: Dictionary with text card parameters
        """
        text_card = {
            'start_frame': start_frame,
            'end_frame': end_frame,
            'params': card_data  # Change 'card_data' to 'params' to match QML property expectations
        }
        
        # Check if this overlaps with an existing text card
        for i, card in enumerate(self._text_cards):
            if (start_frame <= card['end_frame'] and end_frame >= card['start_frame']):
                # Overlapping card, replace it
                self._text_cards[i] = text_card
                self.textCardsChanged.emit()
                return
        
        # Add new card
        self._text_cards.append(text_card)
        self._text_cards.sort(key=lambda x: x['start_frame'])
        self.textCardsChanged.emit()
        logger.info(f"Added text card: {start_frame}-{end_frame}, params: {card_data}")  # Add debugging info
    
    def remove_text_card(self, start_frame, end_frame):
        """Remove a text card that matches the given frame range"""
        for i, card in enumerate(self._text_cards):
            if card['start_frame'] == start_frame and card['end_frame'] == end_frame:
                removed = self._text_cards.pop(i)
                self._removed_text_cards.append(removed)
                self.textCardsChanged.emit()
                return True
        return False
    
    def get_removed_text_card(self, start_frame, end_frame):
        """Get a previously removed text card for undo operations"""
        for i, card in enumerate(self._removed_text_cards):
            if card['start_frame'] == start_frame and card['end_frame'] == end_frame:
                return self._removed_text_cards.pop(i)
        return None
    
    def update_text_card(self, old_start_frame, old_end_frame, new_start_frame, new_end_frame, card_data):
        """Update an existing text card with new start/end frames and parameters"""
        # Find the existing card
        for i, card in enumerate(self._text_cards):
            if card['start_frame'] == old_start_frame and card['end_frame'] == old_end_frame:
                # Save the old card for undo
                old_card = dict(card)
                self._removed_text_cards.append(old_card)
                
                # Update with new values
                updated_card = {
                    'start_frame': new_start_frame,
                    'end_frame': new_end_frame,
                    'params': card_data
                }
                self._text_cards[i] = updated_card
                self._text_cards.sort(key=lambda x: x['start_frame'])
                self.textCardsChanged.emit()
                logger.info(f"Updated text card: {old_start_frame}-{old_end_frame} → {new_start_frame}-{new_end_frame}")
                return True
        
        logger.warning(f"Could not find text card to update: {old_start_frame}-{old_end_frame}")
        return False
        
    def get_active_text_card(self, frame):
        """
        Get the active text card for the current frame, if any.
        
        Args:
            frame: Absolute frame number (integer)
            
        Returns:
            Dictionary with text card parameters or None if no active card
        """
        # Check if frame is an integer
        if not isinstance(frame, (int, float)):
            logger.error(f"Invalid frame type passed to get_active_text_card: {type(frame)}")
            return None
            
        logger.info(f"Checking for text card at frame {frame}")
        logger.info(f"Number of text cards: {len(self._text_cards)}")
        
        for i, card in enumerate(self._text_cards):
            start = card['start_frame']
            end = card['end_frame']
            
            if start <= frame <= end:
                # Calculate how far we are through the card (0.0 to 1.0)
                total_frames = end - start
                progress = 0 if total_frames == 0 else (frame - start) / total_frames
                
                logger.info(f"Found active text card #{i} with progress {progress:.2f}")
                
                # Add progress to the card data for animation calculation
                card_data = card['params'].copy()
                card_data['start_frame'] = start
                card_data['end_frame'] = end
                card_data['progress'] = progress
                card_data['frame_position'] = frame - start
                card_data['total_frames'] = total_frames
                return card_data
        
        return None

class VideoThread(QThread):
    def __init__(self, video_processor):
        super().__init__()
        self.video_processor = video_processor

    def run(self):
        self.video_processor.play()
