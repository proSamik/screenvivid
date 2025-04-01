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
