from PyQt5.QtCore import Slot
from screenvivid.utils.logging import logger

class ClipTrackModel:
    @Slot()
    def _notify_clip_positions(self):
        """Notify the VideoController about the current clip positions for cut detection"""
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