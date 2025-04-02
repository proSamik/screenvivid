import time
import os
import cv2
import numpy as np
from PySide6.QtCore import QObject, Property, Signal, Slot, QTimer

from screenvivid.utils.logging import logger

class VideoProcessor(QObject):
    frameReady = Signal(object, int)
    videoLoaded = Signal()
    videoUnloaded = Signal()
    processingStatusChanged = Signal(str)
    processingProgressChanged = Signal(float)
    textCardsChanged = Signal()
    totalFramesChanged = Signal()  # Signal for total frames property
    playingChanged = Signal(bool)
    frameProcessed = Signal(np.ndarray)  # Signal for processed frame
    startFrameChanged = Signal(int)  # Signal for start frame changes
    endFrameChanged = Signal(int)  # Signal for end frame changes
    videoLenChanged = Signal(float)  # Signal for video length changes
    
    def __init__(self, parent=None):
        super().__init__(parent)
        
        # Initialize variables
        self._video_path = None
        self._video = None
        self._video_len = 0  # This should be calculated dynamically based on start and end frames
        self._current_frame = 0
        self._fps = 30
        self._is_playing = False
        self._start_frame = 0
        self._end_frame = 0
        self._frame_width = 0
        self._frame_height = 0
        self._aspect_ratio = "auto"
        self._aspect_ratio_float = 16 / 9
        self._output_size = [1920, 1080]
        self._text_cards = []
        self._removed_text_cards = []
        self._start_frame_history = []
        self._end_frame_history = []
        
        # Initialize playback timer
        self.play_timer = QTimer(self)
        self.play_timer.timeout.connect(self.process_next_frame)
        
        # Other initialization
        self._padding = {"left": 0, "right": 0, "top": 0, "bottom": 0}
        self._inset = {"left": 0, "right": 0, "top": 0, "bottom": 0}
        self._border_radius = 0
        self._background = "#000000"
        self._device_pixel_ratio = 1
        self._cursor_scale = 1
        self._zoom_scale = 1
        self._zoom_effects = []
        self._removed_zoom_effects = []
        self._mouse_events = {}
        self._cursors_map = {}

    @property
    def total_frames(self):
        """
        Calculate the total number of frames, including extensions from text cards.
        This is crucial for correct playback and UI display.
        """
        # Start with the original video length
        original_length = self._video_len
        
        # If we don't have any text cards or end frames, just return original length
        if not hasattr(self, '_text_cards') or not self._text_cards:
            logger.debug(f"No text cards, total frames = {original_length}")
            return original_length
        
        # Find the maximum end frame considering text cards
        max_end_frame = self._end_frame if hasattr(self, '_end_frame') else 0
        extending_card = None
        
        for card in self._text_cards:
            if card['end_frame'] > max_end_frame:
                max_end_frame = card['end_frame']
                extending_card = card
        
        # Add the extension from text cards
        if extending_card:
            # Calculate total frames based on the maximum end frame
            total = max_end_frame - self._start_frame + 1
            logger.debug(f"Extended by text card: {extending_card}, new total = {total}")
            return total
        else:
            logger.debug(f"No extending text cards, total frames = {original_length}")
            return original_length

    def update_video_length(self):
        """
        Update the video length based on text cards that might extend beyond the original video
        """
        # Check if there are any text cards
        if not hasattr(self, '_text_cards') or not self._text_cards:
            logger.debug("No text cards to extend video length")
            return
            
        # Find the end frame of the last text card
        max_end_frame = self._end_frame
        extending_card = None
        
        for card in self._text_cards:
            if card['end_frame'] > max_end_frame:
                max_end_frame = card['end_frame']
                extending_card = card
        
        # If text cards extend the video, update the end frame and length
        if max_end_frame > self._end_frame:
            logger.info(f"Extending video length: original_end={self._end_frame}, new_end={max_end_frame}")
            if extending_card:
                logger.info(f"Extension caused by text card: {extending_card}")
            
            old_end = self._end_frame
            
            # Update end frame
            self._end_frame = max_end_frame
            
            logger.info(f"Updated video properties: start={self._start_frame}, end={self._end_frame}, len={self.video_len}")
            
            # Emit signals to notify QML about changes
            if old_end != self._end_frame:
                self.endFrameChanged.emit(self._end_frame)
                
            # video_len is calculated dynamically, so just emit the change signal
            self.videoLenChanged.emit()
                
            # Total frames is recalculated from these values
            self.totalFramesChanged.emit()
            
            # Log the new total frames for debugging
            logger.info(f"Total frames updated to: {self.total_frames}")
            
            return True
        else:
            logger.debug(f"No extension needed: video_end={self._end_frame}, max_text_end={max_end_frame}")
            return False

    def add_text_card(self, start_frame, end_frame, card_data):
        """
        Add a text card to the video
        
        Parameters:
        - start_frame: Start frame for the text card
        - end_frame: End frame for the text card
        - card_data: Dictionary with text card parameters
        """
        logger.info(f"Adding text card: {start_frame}-{end_frame}, data: {card_data}")
        
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
                self.update_video_length()  # Update video length
                return
        
        # Add new card
        self._text_cards.append(text_card)
        self._text_cards.sort(key=lambda x: x['start_frame'])
        
        # Check if this extends beyond video length and update if needed
        video_extended = False
        if end_frame > self._end_frame:
            logger.info(f"Text card extends beyond video end. Extending video length. Current end: {self._end_frame}, New end: {end_frame}")
            old_end = self._end_frame
            self._end_frame = end_frame  # Update the end frame
            self.endFrameChanged.emit(self._end_frame)
            self.videoLenChanged.emit()  # Video length is calculated dynamically
            self.totalFramesChanged.emit()
            video_extended = True
            logger.info(f"Total frames updated to: {self.total_frames}")
        
        # Always emit textCardsChanged even if video length didn't change
        self.textCardsChanged.emit()
        logger.info(f"Added text card: {start_frame}-{end_frame}, params: {card_data}")  # Add debugging info
        
        # If we didn't already update the video length but there might be other cards
        # that extend the video, check again
        if not video_extended:
            self.update_video_length()
            
        return True

    def remove_text_card(self, start_frame, end_frame):
        """
        Remove a text card that matches the given frame range
        
        Parameters:
        - start_frame: Start frame of the text card to remove
        - end_frame: End frame of the text card to remove
        
        Returns:
        - bool: True if the card was found and removed, False otherwise
        """
        logger.info(f"Removing text card: {start_frame}-{end_frame}")
        
        # Find the text card
        for i, card in enumerate(self._text_cards):
            if card['start_frame'] == start_frame and card['end_frame'] == end_frame:
                # Store the removed card for undo operations
                removed_card = self._text_cards.pop(i)
                
                # Check if this card was the one extending the video length
                if end_frame >= self._end_frame:
                    # We need to recalculate the end frame
                    self.update_video_length()
                
                # Notify about the change
                self.textCardsChanged.emit()
                logger.info(f"Text card removed successfully")
                return True
                
        logger.warning(f"Text card not found: {start_frame}-{end_frame}")
        return False

    def process_next_frame(self):
        """Process the next frame during playback, ensuring we handle the extended length from text cards."""
        try:
            # Calculate absolute frame position
            current_absolute_frame = self.start_frame + self._current_frame
            
            # Calculate the true end frame including text card extensions
            # We need to check this instead of just self.end_frame
            max_frame = self.start_frame + self.total_frames
            
            logger.info(f"Playing: frame {current_absolute_frame}, max frame: {max_frame}")

            # Check if we've reached the end of ALL content (including text cards)
            if current_absolute_frame >= max_frame:
                logger.info(f"Reached end of ALL content (including text cards) at frame {current_absolute_frame}")
                self.pause()
                return

            # Handle text cards that extend beyond the original video
            if current_absolute_frame >= self.end_frame:
                # We're in the text card area that extends beyond the original video
                logger.info(f"Playing in extended text card area: frame {current_absolute_frame}")
                
                # Create a blank frame for text cards
                blank_frame = np.zeros((self._frame_height, self._frame_width, 3), dtype=np.uint8)
                
                # Process the blank frame with any text card overlays
                processed_frame = self.process_frame(blank_frame)
                
                if processed_frame is not None:
                    self.frameProcessed.emit(processed_frame)
                    # Move to next frame
                    self._current_frame += 1
                
                return

            # Standard video playback for frames within the original video
            try:
                # Set video position and read frame
                self._video.set(cv2.CAP_PROP_POS_FRAMES, current_absolute_frame)
                ret, frame = self._video.read()
                
                if not ret:
                    logger.error(f"Failed to read frame at position {current_absolute_frame}")
                    # Create a blank frame if read fails
                    frame = np.zeros((self._frame_height, self._frame_width, 3), dtype=np.uint8)
                
                # Process the frame and emit it
                processed_frame = self.process_frame(frame)
                
                if processed_frame is not None:
                    self.frameProcessed.emit(processed_frame)
                    self._current_frame += 1
                
            except Exception as e:
                logger.error(f"Error during frame read: {str(e)}")
                # Skip to next frame to avoid getting stuck
                self._current_frame += 1
            
        except Exception as e:
            logger.error(f"Error in process_next_frame: {str(e)}")
            import traceback
            logger.error(traceback.format_exc())

    def get_frame(self):
        """Reads a single frame from the video.
        
        Returns:
            bool: True if frame was read successfully, False otherwise
        """
        try:
            t0 = time.time()
            
            # Check if we've reached the end of original video
            if self._start_frame + self._current_frame >= self._end_frame - 1:
                # Reached end of original video - check if we have text cards extending past this
                if self.total_frames > self._end_frame - self._start_frame:
                    # We're in text card extended territory - continue playback
                    logger.info(f"Beyond original video but still have text cards: {self._current_frame}/{self.total_frames}")
                    self._current_frame += 1
                    return False  # No frame but continue
                else:
                    # No extended content, stop playback
                    self.pause()
                    return False

            # Check if video is valid
            if self._video is None or not self._video.isOpened():
                logger.error("Video is not open")
                return False
                
            # Read frame
            success, frame = self._video.read()
            if not success:
                logger.warning(f"Failed to read frame at position {self._current_frame}")
                return False

            # Process and emit
            processed_frame = self.process_frame(frame)
            self.frameProcessed.emit(processed_frame)
            self._current_frame += 1
            
            t1 = time.time()
            logger.debug(f"Render FPS: {1/(t1 - t0):.2f}")
            return True
            
        except Exception as e:
            logger.error(f"Error in get_frame: {e}")
            return False

    def play(self):
        """Start playback of video"""
        logger.info(f"Starting playback at frame {self._current_frame}")
        self._is_playing = True
        self.playingChanged.emit(True)
        
        # Calculate frame interval based on FPS
        interval = int(1000 / self._fps)
        self.play_timer.start(interval)
        logger.info(f"Play timer started with interval {interval}ms")

    def pause(self):
        """Pause playback of video"""
        logger.info(f"Pausing playback at frame {self._current_frame}")
        self._is_playing = False
        self.play_timer.stop()
        self.playingChanged.emit(False)

    def toggle_play_pause(self):
        """Toggle between play and pause states"""
        if self._is_playing:
            self.pause()
        else:
            self.play()
            
    @Property(bool, notify=playingChanged)
    def is_playing(self):
        """Get the current playing state"""
        return self._is_playing 

    @Property(int, notify=startFrameChanged)
    def start_frame(self):
        """Get the start frame of the video"""
        return self._start_frame
        
    @Property(int, notify=endFrameChanged)
    def end_frame(self):
        """Get the end frame of the video"""
        return self._end_frame
        
    @Property(int)
    def current_frame(self):
        """Get the current frame position (relative to start_frame)"""
        return self._current_frame
        
    @current_frame.setter
    def current_frame(self, value):
        """Set the current frame position"""
        self._current_frame = value

    @Property(int)
    def frame_width(self):
        """Get the frame width"""
        return self._frame_width
        
    @Property(int)
    def frame_height(self):
        """Get the frame height"""
        return self._frame_height
        
    @Property(int)
    def fps(self):
        """Get the frames per second"""
        return self._fps 

    def update_zoom_effect(self, old_start_frame, old_end_frame, new_start_frame, new_end_frame, params):
        """
        Update an existing zoom effect with new parameters
        
        Parameters:
        - old_start_frame: Original start frame for lookups
        - old_end_frame: Original end frame for lookups
        - new_start_frame: New start frame position
        - new_end_frame: New end frame position
        - params: Dictionary with zoom parameters
        """
        logger.info(f"Updating zoom effect: {old_start_frame}-{old_end_frame} -> {new_start_frame}-{new_end_frame}")
        
        # Find the zoom effect to update
        for i, effect in enumerate(self._zoom_effects):
            if effect['start_frame'] == old_start_frame and effect['end_frame'] == old_end_frame:
                # Update with new frames and parameters
                self._zoom_effects[i] = {
                    'start_frame': new_start_frame,
                    'end_frame': new_end_frame,
                    'params': params
                }
                
                # Sort effects by start frame
                self._zoom_effects.sort(key=lambda x: x['start_frame'])
                
                # Check if this extends beyond video length and update if needed
                # This checks both video end and any text cards that might extend beyond
                max_end_frame = self._end_frame
                for card in self._text_cards:
                    max_end_frame = max(max_end_frame, card['end_frame'])
                    
                if new_end_frame > max_end_frame:
                    logger.info(f"Zoom effect extends beyond current content. Extending to: {new_end_frame}")
                    self._end_frame = new_end_frame
                    self._video_len = self._end_frame - self._start_frame + 1
                    self.totalFramesChanged.emit()
                
                # Notify that zoom effects changed
                self.zoomEffectsChanged.emit()
                return True
                
        logger.warning(f"Zoom effect not found: {old_start_frame}-{old_end_frame}")
        return False 

    def add_zoom_effect(self, start_frame, end_frame, zoom_params):
        """
        Add a zoom effect to the video
        
        Parameters:
        - start_frame: Start frame for the zoom effect
        - end_frame: End frame for the zoom effect
        - zoom_params: Dictionary with zoom parameters
        """
        zoom_effect = {
            'start_frame': start_frame,
            'end_frame': end_frame,
            'params': zoom_params
        }
        
        # Check if this overlaps with an existing zoom
        for i, effect in enumerate(self._zoom_effects):
            if (start_frame <= effect['end_frame'] and end_frame >= effect['start_frame']):
                # Overlapping effect, replace it
                self._zoom_effects[i] = zoom_effect
                self.zoomEffectsChanged.emit()
                return
        
        # Add new effect
        self._zoom_effects.append(zoom_effect)
        self._zoom_effects.sort(key=lambda x: x['start_frame'])
        
        # Check if this extends beyond current content (video or text cards)
        max_end_frame = self._end_frame
        for card in self._text_cards:
            max_end_frame = max(max_end_frame, card['end_frame'])
            
        if end_frame > max_end_frame:
            logger.info(f"Zoom effect extends beyond current content. Extending to: {end_frame}")
            self._end_frame = end_frame
            self._video_len = self._end_frame - self._start_frame + 1
            self.totalFramesChanged.emit()
        
        self.zoomEffectsChanged.emit()
        logger.info(f"Added zoom effect: {start_frame}-{end_frame}, params: {zoom_params}")  # Add debugging info 

    @Property(float, notify=videoLenChanged)
    def video_len(self):
        """Get the video length in frames"""
        # Calculate dynamically to ensure consistency
        return self._end_frame - self._start_frame + 1
        
    def append_start_frame(self, frame):
        """Append a new start frame to the history"""
        self._start_frame_history.append(self._start_frame)
        self._start_frame = frame
        self.startFrameChanged.emit(self._start_frame)
        self.videoLenChanged.emit()  # Video length is calculated dynamically
        
    def pop_start_frame(self):
        """Revert to the previous start frame"""
        if self._start_frame_history:
            self._start_frame = self._start_frame_history.pop()
            self.startFrameChanged.emit(self._start_frame)
            self.videoLenChanged.emit()  # Video length is calculated dynamically
            
    def append_end_frame(self, frame):
        """Append a new end frame to the history"""
        self._end_frame_history.append(self._end_frame)
        self._end_frame = frame
        self.endFrameChanged.emit(self._end_frame)
        self.videoLenChanged.emit()  # Video length is calculated dynamically
        
    def pop_end_frame(self):
        """Revert to the previous end frame"""
        if self._end_frame_history:
            self._end_frame = self._end_frame_history.pop()
            self.endFrameChanged.emit(self._end_frame)
            self.videoLenChanged.emit()  # Video length is calculated dynamically

    def load_video(self, path, metadata):
        """
        Load a video from a file path
        
        Parameters:
        - path: Path to the video file
        - metadata: Dictionary with additional metadata
        """
        try:
            # Store the path
            self._video_path = path
            
            # Open the video
            video = cv2.VideoCapture(path)
            
            if not video.isOpened():
                logger.error(f"Failed to open video: {path}")
                raise ValueError(f"Failed to open video: {path}")
            
            self._video = video
            
            # Extract video properties
            video_fps = video.get(cv2.CAP_PROP_FPS)
            self._fps = video_fps if video_fps > 0 else 30  # Default to 30 FPS if unable to determine
            total_frames = int(video.get(cv2.CAP_PROP_FRAME_COUNT))
            self._frame_width = int(video.get(cv2.CAP_PROP_FRAME_WIDTH))
            self._frame_height = int(video.get(cv2.CAP_PROP_FRAME_HEIGHT))
            
            # Reset frames
            self._current_frame = 0
            self._start_frame = 0
            self._end_frame = total_frames - 1
            
            # Load metadata if available
            self._mouse_events = metadata.get("mouse_events", {})
            self._cursors_map = metadata.get("cursors_map", {})
            
            # Apply transformations
            screen_size = (self._frame_width, self._frame_height)
            offset_x = metadata.get("offset_x", 0) if metadata else 0
            offset_y = metadata.get("offset_y", 0) if metadata else 0
            
            x_offset = offset_x if offset_x < self._frame_width else 0
            y_offset = offset_y if offset_y < self._frame_height else 0
            
            # Setup transforms
            # (implement this as needed)
            
            # Emit signals for property changes
            self.startFrameChanged.emit(self._start_frame)
            self.endFrameChanged.emit(self._end_frame)
            self.videoLenChanged.emit()  # Video length is calculated dynamically
            self.totalFramesChanged.emit()
            self.videoLoaded.emit()
            
            return True
        except Exception as e:
            logger.error(f"Error loading video: {str(e)}")
            return False 

    def jump_to_frame(self, target_frame):
        """
        Jump to a specific frame in the video or text card area.
        
        Args:
            target_frame: The absolute frame number to jump to
        """
        logger.debug(f"Jumping to frame {target_frame} (absolute)")
        
        # Calculate bounds
        max_frame = self.start_frame + self.total_frames
        
        # Ensure we stay within valid frame range
        internal_target_frame = max(self.start_frame, min(max_frame, target_frame))
        logger.debug(f"Adjusted target frame: {internal_target_frame}")
        
        # Calculate relative frame (for internal tracking)
        relative_frame = internal_target_frame - self.start_frame
        logger.debug(f"Relative frame position: {relative_frame}")
        
        # Check if we're in the extended area with text cards
        if internal_target_frame >= self.end_frame:
            logger.info(f"Jumping to text card area at frame {internal_target_frame}")
            
            # Create a blank frame for text card
            blank_frame = np.zeros((self._frame_height, self._frame_width, 3), dtype=np.uint8)
            
            # Set current frame and process
            self._current_frame = relative_frame
            processed_frame = self.process_frame(blank_frame)
            
            if processed_frame is not None:
                self.frameProcessed.emit(processed_frame)
                logger.debug(f"Successfully jumped to text card frame {target_frame}, current_frame={self._current_frame}")
            return
        
        # Regular video frame
        if self._video and self._video.isOpened():
            self._video.set(cv2.CAP_PROP_POS_FRAMES, internal_target_frame)
            ret, frame = self._video.read()
            
            if ret:
                processed_frame = self.process_frame(frame)
                self._current_frame = relative_frame
                self.frameProcessed.emit(processed_frame)
                logger.debug(f"Successfully jumped to video frame {target_frame}, current_frame={self._current_frame}")
            else:
                logger.error(f"Failed to read frame at position {internal_target_frame}")
        else:
            logger.error("Cannot jump to frame - video is not open") 