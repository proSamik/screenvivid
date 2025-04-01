class VideoProcessor(QObject):
    frameReady = Signal(object, int)
    videoLoaded = Signal()
    videoUnloaded = Signal()
    processingStatusChanged = Signal(str)
    processingProgressChanged = Signal(float)
    textCardsChanged = Signal()
    totalFramesChanged = Signal()  # Signal for total frames property
    
    def __init__(self, parent=None):
        super().__init__(parent)

    @Property(int, notify=totalFramesChanged)
    def total_frames(self):
        """
        Get the total number of frames, which includes frames from text cards
        that may extend beyond the original video length
        """
        # Calculate total frames based on video length and any text cards that extend beyond it
        if not self._text_cards:
            return self._video_len
        
        # Find the end frame of the last text card
        max_end_frame = self._end_frame
        for card in self._text_cards:
            max_end_frame = max(max_end_frame, card['end_frame'])
        
        # If text cards extend the video, use that length
        if max_end_frame > self._end_frame:
            return max_end_frame - self._start_frame + 1
        else:
            return self._video_len 

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
        
        # Check if this extends beyond video length and update if needed
        if end_frame > self._end_frame:
            logger.info(f"Text card extends beyond video end. Extending video length. Current end: {self._end_frame}, New end: {end_frame}")
            self._end_frame = end_frame
            self._video_len = self._end_frame - self._start_frame + 1
            self.totalFramesChanged.emit()
        
        self.textCardsChanged.emit()
        logger.info(f"Added text card: {start_frame}-{end_frame}, params: {card_data}")  # Add debugging info 