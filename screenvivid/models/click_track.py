from PySide6.QtCore import (
    Qt, Property, Slot, Signal, QAbstractListModel,
    QModelIndex, QObject
)
from screenvivid import config
from screenvivid.models.utils.manager.undo_redo import UndoRedoManager

class ClipTrack:
    def __init__(self, x, width, clip_len):
        self.x = x
        self.width = width
        self.clip_len = clip_len

    def to_dict(self):
        return {"x": self.x, "width": self.width, "clip_len": self.clip_len}

class ClipTrackModel(QAbstractListModel):
    xChanged = Signal()
    widthChanged = Signal()
    clipLenChanged = Signal()
    canUndoChanged = Signal(bool)
    canRedoChanged = Signal(bool)

    def __init__(self, parent=None):
        super().__init__(parent)
        self._clips = [ClipTrack(0, 0, 0)]
        self._clicked_events = []
        self._video_fps = config.DEFAULT_FPS
        self.undo_redo_manager = UndoRedoManager()
        self._video_controller = None

    @Property(QObject)
    def videoController(self):
        return self._video_controller

    @videoController.setter
    def videoController(self, controller):
        self._video_controller = controller

    def rowCount(self, parent=QModelIndex()):
        return len(self._clips)

    def data(self, index, role=Qt.DisplayRole):
        if not index.isValid() or index.row() >= len(self._clips):
            return None

        clip = self._clips[index.row()]
        if role == Qt.UserRole:
            return {"x": clip.x, "width": clip.width, "clip_len": clip.clip_len}
        return None

    def roleNames(self):
        return {Qt.UserRole: b"clipData"}

    @Slot(int, result="QVariant")
    def get_clip(self, index):
        if self._clips and index < len(self._clips):
            return self._clips[index].to_dict()

    @Slot(float)
    def set_fps(self, fps):
        self._video_fps = fps

    @Slot()
    def cut_clip(self):
        """Cut clip at the current position."""
        from screenvivid.utils.logging import logger
        
        if len(self._clicked_events) == 0:
            logger.warning("No clicked events to cut clip")
            return

        # Get last clicked event
        clicked_event = self._clicked_events[-1]
        logger.info(f"Cutting clip at event: {clicked_event}")
        
        # Clear clicked events
        self._clicked_events = []

        index = clicked_event.get("index")
        x = clicked_event.get("x")

        logger.info(f"Cutting clip at index {index} at position {x}")

        def do_cut_clip():
            clipTrack = ClipTrack(
                self._clips[index].x + x,
                self._clips[index].width - x,
                self._clips[index].clip_len - int(x / config.DEFAULT_PIXELS_PER_FRAME),
            )
            self._clips[index].width = x
            self._clips[index].clip_len = int(x / config.DEFAULT_PIXELS_PER_FRAME)
            self._clips.insert(index + 1, clipTrack)
            
            # Log the resulting clips
            for i, clip in enumerate(self._clips):
                logger.info(f"Clip {i}: x={clip.x}, width={clip.width}, len={clip.clip_len}")
                
            # Important - notify positions immediately
            self._notify_clip_positions()
            
            self.dataChanged.emit(self.index(index), self.index(self.rowCount()))
            self.layoutChanged.emit()
            self.canUndoChanged.emit(self.undo_redo_manager.can_undo())
            self.canRedoChanged.emit(self.undo_redo_manager.can_redo())

        def undo_cut_clip():
            if index + 1 < len(self._clips):
                self._clips[index].width += self._clips[index + 1].width
                self._clips[index].clip_len += self._clips[index + 1].clip_len
                self._clips.pop(index + 1)
                
                # Important - notify positions immediately
                self._notify_clip_positions()
                
                self.dataChanged.emit(self.index(index), self.index(self.rowCount()))
                self.layoutChanged.emit()
                self.canUndoChanged.emit(self.undo_redo_manager.can_undo())
                self.canRedoChanged.emit(self.undo_redo_manager.can_redo())

        logger.info("Performing clip cut operation")
        self.undo_redo_manager.do_action(do_cut_clip, (do_cut_clip, undo_cut_clip))

    @Slot(int)
    def delete_clip(self, index):
        self.reset_cut_clip_data()

        if self._clips and len(self._clips) > 1 and index < 1 or index == len(self._clips) - 1:
            deleted_clip = self._clips[index]
            def do_delete():
                self._clips.pop(index)
                self._update_clip_positions()
                self.layoutChanged.emit()
                self._update_undo_redo_signals()

            def undo_delete():
                self._clips.insert(index, deleted_clip)
                self._update_clip_positions()
                self.layoutChanged.emit()
                self._update_undo_redo_signals()

            self.undo_redo_manager.do_action(do_delete, (do_delete, undo_delete))

    def _update_clip_positions(self):
        x = 0
        for clip in self._clips:
            clip.x = x
            x = clip.x + clip.width

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

    @Property(bool, notify=canUndoChanged)
    def canUndo(self):
        return self.undo_redo_manager.can_undo()

    @Property(bool, notify=canRedoChanged)
    def canRedo(self):
        return self.undo_redo_manager.can_redo()

    @Slot(int, float)
    def set_video_len(self, index, length):
        if self._clips:
            self._clips[index].width = length * self._video_fps * config.DEFAULT_PIXELS_PER_FRAME
            self._clips[index].clip_len = length
            self.widthChanged.emit()
            self._notify_clip_positions()

    @Slot(int, float)
    def set_cut_clip_data(self, index, x):
        """Store clicked event data for cut operation"""
        from screenvivid.utils.logging import logger
        
        logger.info(f"Setting cut clip data: index={index}, x={x}")
        self._clicked_events.append({"index": index, "x": x})
        
    @Slot()
    def reset_cut_clip_data(self):
        """Reset clicked event data"""
        from screenvivid.utils.logging import logger
        
        logger.info("Resetting cut clip data")
        self._clicked_events = []

    @Slot()
    def _notify_clip_positions(self):
        """Notify the VideoController about the current clip positions for cut detection"""
        from screenvivid.utils.logging import logger
        
        logger.info(f"Notifying clip positions: {len(self._clips)} clips found")
        
        # Access the video_controller directly if it's available as a property
        video_controller = self._video_controller
        
        if video_controller and hasattr(video_controller, 'video_processor'):
            try:
                # Convert clips to a format that VideoController can use
                clip_positions = []
                for i, clip in enumerate(self._clips):
                    pos = {
                        "start_frame": int(clip.x / config.DEFAULT_PIXELS_PER_FRAME),
                        "end_frame": int((clip.x + clip.width) / config.DEFAULT_PIXELS_PER_FRAME)
                    }
                    clip_positions.append(pos)
                    logger.info(f"  Clip {i}: frames {pos['start_frame']} to {pos['end_frame']}")
                
                # Update the VideoController with clip positions
                video_controller.video_processor.set_clip_positions(clip_positions)
                logger.info(f"Clip positions sent to VideoController: {len(clip_positions)} clips")
            except Exception as e:
                logger.warning(f"Error processing clip positions: {e}")
        else:
            logger.warning("VideoController not accessible from ClipTrackModel")

    # Notify on model changes
    def layoutChanged(self):
        super().layoutChanged.emit()
        self._notify_clip_positions()

    @Slot(int, int)
    def create_gap_at_frame(self, frame, frame_count):
        """
        Create a gap at the specified frame by shifting all clips after that point.
        
        Args:
            frame (int): The frame position where to create the gap
            frame_count (int): The number of frames for the gap
        """
        from screenvivid.utils.logging import logger
        
        logger.info(f"Creating gap at frame {frame} with duration of {frame_count} frames")
        
        # Calculate gap width in pixels
        gap_width_pixels = frame_count * config.DEFAULT_PIXELS_PER_FRAME
        
        # Handle special case for empty timeline or invalid frame
        if not self._clips or len(self._clips) == 0:
            logger.warning(f"No clips found in timeline, cannot create gap at frame {frame}")
            return
            
        # If we only have one clip and it's empty, handle specially
        if len(self._clips) == 1 and self._clips[0].width <= 0:
            logger.info("Timeline has only one empty clip, cannot create gap")
            return
        
        # Find which clip contains this frame
        containing_clip_index = -1
        clip_internal_position = 0
        
        for i, clip in enumerate(self._clips):
            start_frame = int(clip.x / config.DEFAULT_PIXELS_PER_FRAME)
            end_frame = int((clip.x + clip.width) / config.DEFAULT_PIXELS_PER_FRAME)
            
            # Special case: if the frame is exactly at the start of a clip
            if frame == start_frame and i > 0:
                # Create gap before this clip instead of splitting the previous one
                logger.info(f"Frame {frame} is at the beginning of clip {i}, creating gap before it")
                containing_clip_index = i - 1
                clip_internal_position = int(self._clips[i-1].width / config.DEFAULT_PIXELS_PER_FRAME)
                break
            elif start_frame <= frame < end_frame:
                containing_clip_index = i
                clip_internal_position = frame - start_frame
                break
        
        if containing_clip_index == -1:
            logger.warning(f"Could not find clip containing frame {frame}")
            # Try to create gap at the end of the last clip
            if frame >= int((self._clips[-1].x + self._clips[-1].width) / config.DEFAULT_PIXELS_PER_FRAME):
                logger.info(f"Creating gap at the end of the last clip")
                containing_clip_index = len(self._clips) - 1
                clip_internal_position = int(self._clips[-1].width / config.DEFAULT_PIXELS_PER_FRAME)
            else:
                return
        
        logger.info(f"Frame {frame} is in clip {containing_clip_index} at position {clip_internal_position}")
        
        # Calculate the position in pixels where to cut the clip
        cut_position = clip_internal_position * config.DEFAULT_PIXELS_PER_FRAME
        
        def do_create_gap():
            # First cut the clip at the specified position
            containing_clip = self._clips[containing_clip_index]
            
            # Create a new clip that will be after the gap
            new_clip = ClipTrack(
                containing_clip.x + cut_position + gap_width_pixels,
                containing_clip.width - cut_position,
                int((containing_clip.width - cut_position) / config.DEFAULT_PIXELS_PER_FRAME)
            )
            
            # Adjust the clip before the gap
            containing_clip.width = cut_position
            containing_clip.clip_len = int(cut_position / config.DEFAULT_PIXELS_PER_FRAME)
            
            # Insert the new clip after the current one
            self._clips.insert(containing_clip_index + 1, new_clip)
            
            # Shift all subsequent clips
            for i in range(containing_clip_index + 2, len(self._clips)):
                self._clips[i].x += gap_width_pixels
                
            # Notify changes
            self.dataChanged.emit(self.index(containing_clip_index), self.index(self.rowCount()))
            self.layoutChanged.emit()
            self._notify_clip_positions()
            self._update_undo_redo_signals()
            
            logger.info(f"Gap created successfully: {frame_count} frames ({frame_count/self._video_fps:.2f} seconds)")
            
        def undo_create_gap():
            # Merge the clips and remove the gap
            containing_clip = self._clips[containing_clip_index]
            next_clip = self._clips[containing_clip_index + 1]
            
            # Restore the original clip width
            containing_clip.width += next_clip.width
            containing_clip.clip_len = int(containing_clip.width / config.DEFAULT_PIXELS_PER_FRAME)
            
            # Remove the second part of the split clip
            self._clips.pop(containing_clip_index + 1)
            
            # Shift all subsequent clips back
            for i in range(containing_clip_index + 1, len(self._clips)):
                self._clips[i].x -= gap_width_pixels
            
            # Notify changes
            self.dataChanged.emit(self.index(containing_clip_index), self.index(self.rowCount()))
            self.layoutChanged.emit()
            self._notify_clip_positions()
            self._update_undo_redo_signals()
            
            logger.info(f"Gap removal undone")
            
        self.undo_redo_manager.do_action(do_create_gap, (do_create_gap, undo_create_gap))

    @Slot(int, int)
    def close_gap_at_frame(self, frame, frame_count):
        """
        Close a gap at the specified frame by shifting all clips after that point.
        This is the opposite operation of create_gap_at_frame.
        
        Args:
            frame (int): The frame position where the gap starts
            frame_count (int): The number of frames to close
        """
        from screenvivid.utils.logging import logger
        
        logger.info(f"Closing gap at frame {frame} with size of {frame_count} frames")
        
        # Calculate gap width in pixels
        gap_width_pixels = frame_count * config.DEFAULT_PIXELS_PER_FRAME
        
        # Find which clip is right after the gap
        right_clip_index = -1
        
        for i, clip in enumerate(self._clips):
            start_frame = int(clip.x / config.DEFAULT_PIXELS_PER_FRAME)
            
            if start_frame >= frame + frame_count:
                right_clip_index = i
                break
        
        if right_clip_index == -1 or right_clip_index == 0:
            logger.warning(f"Could not find clips to join at frame {frame}")
            return
        
        # The left clip is the one before the right clip
        left_clip_index = right_clip_index - 1
        
        logger.info(f"Found clips to join: {left_clip_index} and {right_clip_index}")
        
        def do_close_gap():
            # Store the original position of the right clip
            right_clip = self._clips[right_clip_index]
            original_right_clip_x = right_clip.x
            
            # Shift the right clip to remove the gap
            right_clip.x -= gap_width_pixels
            
            # Shift all subsequent clips
            for i in range(right_clip_index + 1, len(self._clips)):
                self._clips[i].x -= gap_width_pixels
            
            # Notify changes
            self.dataChanged.emit(self.index(left_clip_index), self.index(self.rowCount()))
            self.layoutChanged.emit()
            self._notify_clip_positions()
            self._update_undo_redo_signals()
            
            logger.info(f"Gap closed successfully")
            
        def undo_close_gap():
            # Restore the original position of the right clip
            right_clip = self._clips[right_clip_index]
            right_clip.x += gap_width_pixels
            
            # Shift all subsequent clips back
            for i in range(right_clip_index + 1, len(self._clips)):
                self._clips[i].x += gap_width_pixels
            
            # Notify changes
            self.dataChanged.emit(self.index(left_clip_index), self.index(self.rowCount()))
            self.layoutChanged.emit()
            self._notify_clip_positions()
            self._update_undo_redo_signals()
            
            logger.info(f"Gap closure undone")
        
        self.undo_redo_manager.do_action(do_close_gap, (do_close_gap, undo_close_gap))
