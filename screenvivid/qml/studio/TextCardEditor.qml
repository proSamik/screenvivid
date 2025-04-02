import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: "#2A2A2A"
    radius: 10
    opacity: 0.95
    width: 400
    height: Math.min(500, mainLayout.implicitHeight + 30)
    
    // Modal background to ensure it appears above all content
    Rectangle {
        id: modalBackground
        anchors.fill: parent
        anchors.margins: -2000 // Extend well beyond the dialog
        color: "#80000000" // Semi-transparent black
        z: -1 // Behind the dialog content
        
        // Capture all mouse events on the background
        MouseArea {
            anchors.fill: parent
            onClicked: {
                // Allow closing by clicking outside
                cancelCard()
            }
        }
    }
    
    property string selectedBgColor: "black"
    property string selectedTextColor: "white"
    property string horizontalAlign: "center"
    property string verticalAlign: "middle"
    property alias text: textArea.text
    property real cardDuration: 3.0  // seconds
    property real textSize: 1.0      // text size multiplier (1.0 = normal)
    property bool isEditMode: false
    property int startFrame: -1
    property int endFrame: -1
    property bool createGapOnApply: false  // Whether to create a gap when applying
    
    // Signals
    signal applyCard()
    signal cancelCard()
    
    // Return text card data as a dictionary
    function getCardData() {
        return {
            "background_color": selectedBgColor,
            "text": textArea.text,
            "text_color": selectedTextColor,
            "duration_seconds": cardDuration,
            "horizontal_align": horizontalAlign,
            "vertical_align": verticalAlign,
            "text_size": textSize
        }
    }
    
    function setCardData(data) {
        selectedBgColor = data.background_color || "black"
        textArea.text = data.text || "Lorem ipsum dolor sit amet"
        selectedTextColor = data.text_color || "white"
        cardDuration = data.duration_seconds || 3.0
        horizontalAlign = data.horizontal_align || "center"
        verticalAlign = data.vertical_align || "middle"
        textSize = data.text_size || 1.0
    }
    
    ScrollView {
        id: scrollView
        anchors.fill: parent
        anchors.margins: 15
        clip: true
        ScrollBar.vertical.policy: ScrollBar.AsNeeded
        
        ColumnLayout {
            id: mainLayout
            width: scrollView.width - 20 // Allow space for scrollbar
            spacing: 15
            
            // Header
            Text {
                text: isEditMode ? "Edit Text Card" : "Add Text Card"
                font.bold: true
                font.pixelSize: 16
                color: "white"
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }
            
            // Text editor
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: 120
                color: selectedBgColor === "black" ? "#000000" : "#FFFFFF"
                border.color: "#555555"
                border.width: 1
                
                ScrollView {
                    id: textScroll
                    anchors.fill: parent
                    anchors.margins: 10
                    clip: true
                    
                    TextArea {
                        id: textArea
                        color: selectedTextColor === "black" ? "#000000" : "#FFFFFF"
                        wrapMode: TextEdit.Wrap
                        placeholderText: "Enter text for typewriter effect..."
                        placeholderTextColor: selectedTextColor === "black" ? "#555555" : "#AAAAAA"
                        background: null
                        selectByMouse: true
                        text: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Edit this text."
                        font.pointSize: 12 * textSize // Base size * multiplier
                        
                        horizontalAlignment: {
                            if (horizontalAlign === "left") return Text.AlignLeft
                            else if (horizontalAlign === "right") return Text.AlignRight
                            else return Text.AlignHCenter
                        }
                        
                        verticalAlignment: {
                            if (verticalAlign === "top") return Text.AlignTop
                            else if (verticalAlign === "bottom") return Text.AlignBottom
                            else return Text.AlignVCenter
                        }
                    }
                }
            }
            
            // Controls for appearance
            GridLayout {
                columns: 2
                Layout.fillWidth: true
                rowSpacing: 8
                columnSpacing: 10
                
                // Background color
                Text {
                    text: "Background:"
                    color: "white"
                }
                
                RowLayout {
                    spacing: 10
                    
                    Rectangle {
                        width: 20
                        height: 20
                        color: "black"
                        border.width: selectedBgColor === "black" ? 2 : 0
                        border.color: "#7BD57F"
                        
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                selectedBgColor = "black"
                            }
                        }
                    }
                    
                    Rectangle {
                        width: 20
                        height: 20
                        color: "white"
                        border.width: selectedBgColor === "white" ? 2 : 0
                        border.color: "#7BD57F"
                        
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                selectedBgColor = "white"
                            }
                        }
                    }
                }
                
                // Text color
                Text {
                    text: "Text Color:"
                    color: "white"
                }
                
                RowLayout {
                    spacing: 10
                    
                    Rectangle {
                        width: 20
                        height: 20
                        color: "white"
                        border.width: selectedTextColor === "white" ? 2 : 0
                        border.color: "#7BD57F"
                        
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                selectedTextColor = "white"
                            }
                        }
                    }
                    
                    Rectangle {
                        width: 20
                        height: 20
                        color: "black"
                        border.width: selectedTextColor === "black" ? 2 : 0
                        border.color: "#7BD57F"
                        
                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                selectedTextColor = "black"
                            }
                        }
                    }
                }
                
                // Horizontal alignment
                Text {
                    text: "Horizontal Align:"
                    color: "white"
                }
                
                RowLayout {
                    spacing: 5
                    
                    Button {
                        icon.source: "qrc:/resources/icons/align_left.svg"
                        icon.color: horizontalAlign === "left" ? "#7BD57F" : "#CCCCCC"
                        background: Rectangle {
                            color: "transparent"
                        }
                        onClicked: {
                            horizontalAlign = "left"
                        }
                    }
                    
                    Button {
                        icon.source: "qrc:/resources/icons/align_center.svg"
                        icon.color: horizontalAlign === "center" ? "#7BD57F" : "#CCCCCC"
                        background: Rectangle {
                            color: "transparent"
                        }
                        onClicked: {
                            horizontalAlign = "center"
                        }
                    }
                    
                    Button {
                        icon.source: "qrc:/resources/icons/align_right.svg"
                        icon.color: horizontalAlign === "right" ? "#7BD57F" : "#CCCCCC"
                        background: Rectangle {
                            color: "transparent"
                        }
                        onClicked: {
                            horizontalAlign = "right"
                        }
                    }
                }
                
                // Vertical alignment
                Text {
                    text: "Vertical Align:"
                    color: "white"
                }
                
                RowLayout {
                    spacing: 5
                    
                    Button {
                        icon.source: "qrc:/resources/icons/align_top.svg"
                        icon.color: verticalAlign === "top" ? "#7BD57F" : "#CCCCCC"
                        background: Rectangle {
                            color: "transparent"
                        }
                        onClicked: {
                            verticalAlign = "top"
                        }
                    }
                    
                    Button {
                        icon.source: "qrc:/resources/icons/align_middle.svg"
                        icon.color: verticalAlign === "middle" ? "#7BD57F" : "#CCCCCC"
                        background: Rectangle {
                            color: "transparent"
                        }
                        onClicked: {
                            verticalAlign = "middle"
                        }
                    }
                    
                    Button {
                        icon.source: "qrc:/resources/icons/align_bottom.svg"
                        icon.color: verticalAlign === "bottom" ? "#7BD57F" : "#CCCCCC"
                        background: Rectangle {
                            color: "transparent"
                        }
                        onClicked: {
                            verticalAlign = "bottom"
                        }
                    }
                }
                
                // Duration control
                Text {
                    text: "Duration (sec):"
                    color: "white"
                }
                
                RowLayout {
                    spacing: 5
                    
                    SpinBox {
                        id: durationSpinBox
                        from: 1
                        to: 10
                        stepSize: 1
                        value: cardDuration
                        
                        onValueChanged: {
                            cardDuration = value;
                            if (startFrame >= 0 && endFrame >= 0) {
                                // Update the end frame based on duration
                                var newEndFrame = startFrame + Math.round(value * videoController.fps) - 1;
                                if (newEndFrame !== endFrame) {
                                    endFrame = newEndFrame;
                                    console.log("Updated end frame based on duration:", endFrame);
                                }
                            }
                        }
                        
                        background: Rectangle {
                            color: "#333333"
                            border.color: "#555555"
                            border.width: 1
                            radius: 3
                        }
                        
                        contentItem: TextInput {
                            text: durationSpinBox.textFromValue(durationSpinBox.value, durationSpinBox.locale)
                            color: "white"
                            selectByMouse: true
                            horizontalAlignment: Qt.AlignHCenter
                            verticalAlignment: Qt.AlignVCenter
                            readOnly: !durationSpinBox.editable
                            validator: durationSpinBox.validator
                            font: durationSpinBox.font
                        }
                    }
                    
                    Text {
                        text: "seconds"
                        color: "white"
                    }
                }
                
                // Text size control
                Text {
                    text: "Text Size:"
                    color: "white"
                }
                
                RowLayout {
                    spacing: 5
                    
                    Slider {
                        id: textSizeSlider
                        from: 0.5
                        to: 2.0
                        value: textSize
                        stepSize: 0.1
                        snapMode: Slider.SnapAlways
                        
                        onValueChanged: {
                            textSize = value
                            textArea.font.pointSize = 12 * textSize // Base size * multiplier
                        }
                        
                        Layout.preferredWidth: 120
                        
                        background: Rectangle {
                            x: textSizeSlider.leftPadding
                            y: textSizeSlider.topPadding + textSizeSlider.availableHeight / 2 - height / 2
                            width: textSizeSlider.availableWidth
                            height: 4
                            radius: 2
                            color: "#333333"
                            
                            Rectangle {
                                width: textSizeSlider.visualPosition * parent.width
                                height: parent.height
                                color: "#545EEE"
                                radius: 2
                            }
                        }
                        
                        handle: Rectangle {
                            x: textSizeSlider.leftPadding + textSizeSlider.visualPosition * (textSizeSlider.availableWidth - width)
                            y: textSizeSlider.topPadding + textSizeSlider.availableHeight / 2 - height / 2
                            width: 16
                            height: 16
                            radius: 8
                            color: textSizeSlider.pressed ? "#7BD57F" : "#545EEE"
                            border.color: "#7BD57F"
                            border.width: textSizeSlider.pressed ? 2 : 0
                        }
                    }
                    
                    Text {
                        text: textSize.toFixed(1) + "×"
                        color: "white"
                    }
                }
                
                // Show frame information
                Text {
                    text: "Position:"
                    color: "white"
                    visible: startFrame >= 0 && endFrame >= 0
                }
                
                Text {
                    function formatTime(frames) {
                        var fps = videoController ? videoController.fps : defaultFps;
                        var seconds = frames / fps;
                        var mins = Math.floor(seconds / 60);
                        var secs = Math.floor(seconds % 60);
                        return mins + ":" + (secs < 10 ? "0" : "") + secs;
                    }
                    
                    text: startFrame >= 0 && endFrame >= 0 ? 
                          formatTime(startFrame) + " to " + formatTime(endFrame) : ""
                    color: "#CCCCCC"
                    visible: startFrame >= 0 && endFrame >= 0
                }
            }
            
            // Save/Cancel buttons
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 15
                Layout.bottomMargin: 10
                spacing: 10
                
                Item { Layout.fillWidth: true }
                
                Button {
                    text: "Cancel"
                    Layout.preferredWidth: 100
                    Layout.preferredHeight: 40
                    onClicked: cancelCard()
                    
                    background: Rectangle {
                        color: "#444444"
                        radius: 4
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
                
                Button {
                    text: "Save"
                    Layout.preferredWidth: 100
                    Layout.preferredHeight: 40
                    onClicked: {
                        console.log("Saving text card with text: " + textArea.text)
                        
                        // Calculate endFrame based on duration in seconds
                        var durationFrames = Math.round(cardDuration * (videoController ? videoController.fps : 30));
                        endFrame = startFrame + durationFrames;
                        
                        console.log("Text card frames: start=" + startFrame + ", end=" + endFrame + 
                                   " (duration: " + cardDuration + "s, " + durationFrames + " frames)");
                        
                        // Create a gap in the timeline at the current position
                        if (clipTrackModel) {
                            console.log("Creating gap at frame " + startFrame + " with size " + durationFrames);
                            clipTrackModel.create_gap_at_frame(startFrame, durationFrames);
                        } else {
                            console.log("Warning: clipTrackModel not available, can't create gap");
                        }
                        
                        // Add or update the text card with start/end frames and text content
                        videoController.add_text_card(
                            startFrame,
                            endFrame,
                            {
                                "text": textArea.text,
                                "font_size": textSize,
                                "font_family": "Arial",
                                "color": selectedTextColor,
                                "position": "center",
                                "background_color": selectedBgColor,
                                "background_opacity": 1.0,
                                "duration_seconds": cardDuration
                            }
                        );
                        
                        // Close the editor
                        visible = false
                    }
                    
                    background: Rectangle {
                        color: "#545EEE"
                        radius: 4
                    }
                    
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
    }

    // Display duration of card in seconds (frames / fps)
    property real durationSeconds: {
        if (!videoController) return 3.0;  // Default if no controller
        if (startFrame < 0 || endFrame < 0) return 3.0;  // Default if frames not set
        
        var framesDuration = endFrame - startFrame + 1;
        return framesDuration / videoController.fps;
    }
    
    // Default fps for calculations when videoController is not available
    property int defaultFps: 30
    
    onDurationSecondsChanged: {
        // Update end frame based on duration
        if (videoController && startFrame >= 0) {
            var framesNeeded = Math.round(durationSeconds * videoController.fps);
            endFrame = startFrame + framesNeeded - 1;
        }
    }
    
    // Format time safely (protecting against videoController being null)
    function formatTime(frames) {
        var fps = videoController ? videoController.fps : defaultFps;
        var seconds = frames / fps;
        var mins = Math.floor(seconds / 60);
        var secs = Math.floor(seconds % 60);
        return mins + ":" + (secs < 10 ? "0" : "") + secs;
    }
} 