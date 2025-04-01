import cv2
import numpy as np
from PySide6.QtCore import QObject, Property, Slot, Signal
from screenvivid.utils.logging import logger

class TextCard(QObject):
    """
    TextCard class for rendering text cards with typewriter animation effect
    to be inserted between video clips.
    """
    
    def __init__(self, background_color="black", text="", text_color="white", 
                 duration_seconds=3, horizontal_align="center", vertical_align="middle"):
        """
        Initialize TextCard with default parameters
        
        Args:
            background_color (str): "black" or "white"
            text (str): Text content to display with typewriter effect
            text_color (str): "black" or "white"
            duration_seconds (float): Duration in seconds
            horizontal_align (str): "left", "center", or "right"
            vertical_align (str): "top", "middle", or "bottom"
        """
        super().__init__()
        self.background_color = background_color  # "black" or "white"
        self.text = text
        self.text_color = text_color  # "black" or "white"
        self.duration_seconds = duration_seconds
        self.horizontal_align = horizontal_align  # "left", "center", "right"
        self.vertical_align = vertical_align  # "top", "middle", "bottom"
        
        # Internal properties
        self._rendered_frames = {}  # Cache for rendered frames
        self._font = cv2.FONT_HERSHEY_SIMPLEX
        self._font_scale = 1.0
        self._line_thickness = 2
        self._padding = 50  # Padding from edges
        
    def render_frame(self, frame_number, total_frames, width, height):
        """
        Render a frame of the text card with typewriter effect
        
        Args:
            frame_number (int): Current frame number
            total_frames (int): Total number of frames for this card
            width (int): Output width
            height (int): Output height
            
        Returns:
            np.ndarray: Rendered frame with typewriter effect
        """
        # Check cache first
        cache_key = f"{frame_number}_{width}_{height}"
        if cache_key in self._rendered_frames:
            return self._rendered_frames[cache_key]
        
        # Create background
        if self.background_color == "black":
            frame = np.zeros((height, width, 3), dtype=np.uint8)
        else:
            frame = np.ones((height, width, 3), dtype=np.uint8) * 255
        
        # No text to render
        if not self.text:
            return frame
        
        # Calculate how much text to show based on the current frame
        progress = min(1.0, frame_number / (total_frames * 0.8))  # Use 80% of time for typing
        chars_to_show = int(len(self.text) * progress)
        text_to_render = self.text[:chars_to_show]
        
        # Skip rendering if no text to show yet
        if not text_to_render:
            return frame
        
        # Prepare text color
        if self.text_color == "black":
            text_color = (0, 0, 0)
        else:
            text_color = (255, 255, 255)
        
        # Split text into lines
        lines = text_to_render.split('\n')
        
        # Calculate text size for correct positioning
        line_height = 0
        line_widths = []
        
        for line in lines:
            (text_width, text_height), _ = cv2.getTextSize(
                line, self._font, self._font_scale, self._line_thickness
            )
            line_height = max(line_height, text_height)
            line_widths.append(text_width)
        
        # Calculate vertical position
        if self.vertical_align == "top":
            y_pos = self._padding
        elif self.vertical_align == "bottom":
            y_pos = height - (line_height * len(lines)) - self._padding
        else:  # middle
            y_pos = (height - (line_height * len(lines))) // 2
        
        # Add text line by line
        for i, line in enumerate(lines):
            # Calculate horizontal position for this line
            if self.horizontal_align == "left":
                x_pos = self._padding
            elif self.horizontal_align == "right":
                x_pos = width - line_widths[i] - self._padding
            else:  # center
                x_pos = (width - line_widths[i]) // 2
            
            # Add the line to the frame
            cv2.putText(
                frame, line, (x_pos, y_pos + (i * int(line_height * 1.5))),
                self._font, self._font_scale, text_color, self._line_thickness, 
                cv2.LINE_AA
            )
        
        # Add blinking cursor at the end (only show during the typing phase)
        if chars_to_show < len(self.text):
            last_line = lines[-1]
            last_line_width = line_widths[-1]
            
            # Position for cursor
            if self.horizontal_align == "left":
                cursor_x = self._padding + last_line_width + 5
            elif self.horizontal_align == "right":
                cursor_x = width - self._padding - 5
            else:  # center
                cursor_x = (width - line_widths[-1]) // 2 + last_line_width + 5
            
            cursor_y = y_pos + ((len(lines) - 1) * int(line_height * 1.5))
            
            # Draw cursor (blink every 15 frames)
            if frame_number % 30 < 15:
                cv2.line(
                    frame, 
                    (cursor_x, cursor_y), 
                    (cursor_x, cursor_y - line_height), 
                    text_color, 
                    self._line_thickness
                )
        
        # Cache and return
        self._rendered_frames[cache_key] = frame
        return frame
    
    def to_dict(self):
        """Convert the TextCard to a dictionary for storage"""
        return {
            "background_color": self.background_color,
            "text": self.text,
            "text_color": self.text_color,
            "duration_seconds": self.duration_seconds,
            "horizontal_align": self.horizontal_align,
            "vertical_align": self.vertical_align
        }
    
    @classmethod
    def from_dict(cls, data):
        """Create a TextCard from a dictionary"""
        card = cls()
        card.background_color = data.get("background_color", "black")
        card.text = data.get("text", "")
        card.text_color = data.get("text_color", "white")
        card.duration_seconds = data.get("duration_seconds", 3)
        card.horizontal_align = data.get("horizontal_align", "center")
        card.vertical_align = data.get("vertical_align", "middle")
        return card 