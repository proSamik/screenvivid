import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "."

Rectangle {
    id: videoEdit
    color: "#131519"
    radius: 4

    property bool animationEnabled: true
    property real pixelsPerFrame: studioWindow.pixelsPerFrame
    property int timelineHeaderWidth: 150  // Width of the timeline header

    Flickable {
        id: scrollView
        anchors.fill: parent
        contentWidth: calculateTimelineWidth()
        contentHeight: parent.height
        property real currentScrollX: 0

        ScrollBar.horizontal: ScrollBar {
            id: hScrollBar
            background: Rectangle {
                color: "transparent"
            }
            contentItem: Rectangle {
                implicitWidth: 100
                implicitHeight: 10
                radius: height / 2
                color: {
                    if (hScrollBar.pressed) return "#81848c"  // Pressed state
                    if (hScrollBar.hovered) return "#6e7177"  // Hover state
                    return "#5d6067"  // Normal state
                }
            }
        }

        Behavior on contentX {
            enabled: !isPlaying
            NumberAnimation {
                duration: 400
                easing.type: Easing.InOutQuad
            }
        }

        Item {
            width: parent.contentWidth
            height: videoEdit.height
            anchors.left: parent.left
            anchors.leftMargin: 20

            Timeline {}

            Item {
                id: tracks
                width: parent.width
                height: 60
                y: 75
                anchors.left: parent.left
                anchors.leftMargin: 10

                Repeater {
                    model: clipTrackModel
                    ClipTrack {
                        x: modelData.x
                        height: 60
                        width: modelData.width
                        clipLen: modelData.clip_len
                        onLeftMouseClicked: function (mouseX) {
                            timeSlider.animationEnabled = false
                            var targetFrame = Math.round(
                                        (x + mouseX) / studioWindow.pixelsPerFrame)
                            videoController.jump_to_frame(targetFrame)
                            clipTrackModel.set_cut_clip_data(index, mouseX)
                            timeSlider.animationEnabled = true
                        }
                    }
                }
            }
            
            // Zoom effects track - inline implementation
            Item {
                id: zoomTrack
                width: parent.width
                height: 30
                y: 145 // Position below the clip track
                anchors.left: parent.left
                anchors.leftMargin: 10
                
                Rectangle {
                    anchors.fill: parent
                    color: "#282C33"
                    opacity: 0.7
                    radius: 4
                }
                
                // Auto-zoom toggle control
                Rectangle {
                    id: autoZoomToggle
                    anchors.left: textTrackHeader.right
                    anchors.leftMargin: 10
                    anchors.top: parent.top
                    anchors.topMargin: 5
                    width: 90
                    height: 20
                    radius: 10
                    color: autoZoomEnabled ? "#545EEE" : "#444"
                    
                    property bool autoZoomEnabled: true
                    
                    Row {
                        anchors.centerIn: parent
                        spacing: 5
                        
                        Text {
                            text: "Auto Zoom"
                            color: "white"
                            font.pixelSize: 10
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        
                        Rectangle {
                            width: 10
                            height: 10
                            radius: 5
                            color: autoZoomToggle.autoZoomEnabled ? "#7BD57F" : "#666"
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            autoZoomToggle.autoZoomEnabled = !autoZoomToggle.autoZoomEnabled
                            // Apply or remove all auto zooms
                            if (autoZoomToggle.autoZoomEnabled) {
                                // Re-create auto zooms
                                videoController.create_automatic_zooms_from_cursor()
                            } else {
                                // Remove all auto-generated zooms
                                for (var i = videoController.zoom_effects.length - 1; i >= 0; i--) {
                                    var effect = videoController.zoom_effects[i]
                                    if (effect.params.auto === true) {
                                        videoController.remove_zoom_effect(effect.start_frame, effect.end_frame)
                                    }
                                }
                            }
                        }
                    }
                    
                    ToolTip {
                        visible: autoZoomArea.containsMouse
                        text: autoZoomToggle.autoZoomEnabled ? 
                            "Auto-zoom enabled: Automatically generates zooms from cursor clicks" : 
                            "Auto-zoom disabled: Only manually placed zooms will appear"
                    }
                    
                    MouseArea {
                        id: autoZoomArea
                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: parent.clicked()
                    }
                }
                
                // Zoom effects renderer
                Repeater {
                    model: videoController ? videoController.zoom_effects : []
                    
                    delegate: Rectangle {
                        id: zoomEffectRect
                        property var effect: modelData
                        
                        // Convert from absolute to relative frame positions for display
                        // This ensures proper positioning on the timeline
                        property int relativeStartFrame: videoController ? Math.max(0, effect.start_frame - videoController.start_frame) : 0
                        property int relativeEndFrame: videoController ? Math.min(videoController.end_frame - videoController.start_frame, 
                                                             effect.end_frame - videoController.start_frame) : 0
                        property bool isResizing: false
                        property bool isMoving: false
                        property int dragStartX: 0
                        property int originalStartFrame: 0
                        property int originalEndFrame: 0
                        
                        x: relativeStartFrame * studioWindow.pixelsPerFrame
                        y: 2
                        width: (relativeEndFrame - relativeStartFrame) * studioWindow.pixelsPerFrame
                        height: parent.height - 4
                        radius: 4
                        
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: "#2969E7" }
                            GradientStop { position: 1.0; color: "#545EEE" }
                        }
                        
                        // Left resize handle
                        Rectangle {
                            id: leftHandle
                            width: 8
                            height: parent.height
                            color: "white"
                            opacity: handleArea.containsMouse ? 0.7 : 0.3
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            radius: 2
                            
                            MouseArea {
                                id: handleArea
                                anchors.fill: parent
                                anchors.margins: -4 // Larger hit area
                                hoverEnabled: true
                                cursorShape: Qt.SizeHorCursor
                                
                                onPressed: {
                                    zoomEffectRect.isResizing = true
                                    zoomEffectRect.originalStartFrame = effect.start_frame
                                    zoomEffectRect.dragStartX = mouseX
                                }
                                
                                onPositionChanged: {
                                    if (zoomEffectRect.isResizing) {
                                        // Calculate frame delta based on mouse movement
                                        var deltaX = mouseX - zoomEffectRect.dragStartX
                                        var frameDelta = Math.round(deltaX / studioWindow.pixelsPerFrame)
                                        
                                        // Calculate new start frame
                                        var newStartFrame = zoomEffectRect.originalStartFrame + frameDelta
                                        
                                        // Ensure new start frame is within bounds
                                        newStartFrame = Math.max(videoController.start_frame, newStartFrame)
                                        newStartFrame = Math.min(effect.end_frame - 10, newStartFrame) // Keep at least 10 frames
                                        
                                        // Update the effect in the model
                                        if (newStartFrame !== effect.start_frame) {
                                            videoController.update_zoom_effect(
                                                effect.start_frame, 
                                                effect.end_frame, 
                                                newStartFrame, 
                                                effect.end_frame, 
                                                effect.params
                                            )
                                        }
                                    }
                                }
                                
                                onReleased: {
                                    zoomEffectRect.isResizing = false
                                }
                            }
                        }
                        
                        // Right resize handle
                        Rectangle {
                            id: rightHandle
                            width: 8
                            height: parent.height
                            color: "white"
                            opacity: rightHandleArea.containsMouse ? 0.7 : 0.3
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            radius: 2
                            
                            MouseArea {
                                id: rightHandleArea
                                anchors.fill: parent
                                anchors.margins: -4 // Larger hit area
                                hoverEnabled: true
                                cursorShape: Qt.SizeHorCursor
                                
                                onPressed: {
                                    zoomEffectRect.isResizing = true
                                    zoomEffectRect.originalEndFrame = effect.end_frame
                                    zoomEffectRect.dragStartX = mouseX
                                }
                                
                                onPositionChanged: {
                                    if (zoomEffectRect.isResizing) {
                                        // Calculate frame delta based on mouse movement
                                        var deltaX = mouseX - zoomEffectRect.dragStartX
                                        var frameDelta = Math.round(deltaX / studioWindow.pixelsPerFrame)
                                        
                                        // Calculate new end frame
                                        var newEndFrame = zoomEffectRect.originalEndFrame + frameDelta
                                        
                                        // Ensure new end frame is within bounds
                                        newEndFrame = Math.min(videoController.end_frame, newEndFrame)
                                        newEndFrame = Math.max(effect.start_frame + 10, newEndFrame) // Keep at least 10 frames
                                        
                                        // Update the effect in the model
                                        if (newEndFrame !== effect.end_frame) {
                                            videoController.update_zoom_effect(
                                                effect.start_frame, 
                                                effect.end_frame, 
                                                effect.start_frame, 
                                                newEndFrame, 
                                                effect.params
                                            )
                                        }
                                    }
                                }
                                
                                onReleased: {
                                    zoomEffectRect.isResizing = false
                                }
                            }
                        }
                        
                        // Zoom phase indicators - show time-based durations
                        Rectangle {
                            id: zoomInMarker
                            width: Math.min(parent.width * 0.15, effect.params.easeInFrames * studioWindow.pixelsPerFrame) 
                            height: parent.height
                            color: "#7BD57F" // Green for zoom in
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            opacity: 0.8
                            
                            // Calculate time in seconds from frames
                            property real inSeconds: effect.params.easeInFrames / videoController.fps
                            
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                                anchors.topMargin: -18
                                text: "IN (" + parent.inSeconds.toFixed(1) + "s)"
                                color: "#7BD57F"
                                font.pixelSize: 10
                                visible: parent.width >= 4 && zoomEffectRect.width > 40
                            }
                        }
                        
                        Rectangle {
                            id: zoomOutMarker
                            width: Math.min(parent.width * 0.15, effect.params.easeOutFrames * studioWindow.pixelsPerFrame)
                            height: parent.height
                            color: "#FFA071" // Orange for zoom out
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            opacity: 0.8
                            
                            // Calculate time in seconds from frames
                            property real outSeconds: effect.params.easeOutFrames / videoController.fps
                            
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                anchors.top: parent.top
                                anchors.topMargin: -18
                                text: "OUT (" + parent.outSeconds.toFixed(1) + "s)"
                                color: "#FFA071"
                                font.pixelSize: 10
                                visible: parent.width >= 4 && zoomEffectRect.width > 40
                            }
                        }
                        
                        // Center area indicating the zoom is held steady
                        Rectangle {
                            anchors.left: zoomInMarker.right
                            anchors.right: zoomOutMarker.left
                            height: 8
                            anchors.verticalCenter: parent.verticalCenter
                            color: "#545EEE" // Same blue as the effect
                            opacity: 0.3
                            radius: 2
                            
                            // Calculate hold duration in seconds
                            property real holdDuration: (effect.end_frame - effect.start_frame - 
                                (effect.params.easeInFrames || 5) - (effect.params.easeOutFrames || 4)) / videoController.fps
                            
                            Text {
                                anchors.centerIn: parent
                                text: "HOLD (" + parent.holdDuration.toFixed(1) + "s)"
                                color: "white"
                                font.pixelSize: 9
                                visible: parent.width > 40
                            }
                        }
                        
                        // Total duration display
                        Text {
                            anchors.top: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.topMargin: 4
                            text: formatDuration((effect.end_frame - effect.start_frame) / videoController.fps)
                            color: "white"
                            font.pixelSize: 10
                            visible: zoomEffectRect.width > 60
                            
                            // Format duration as M:SS
                            function formatDuration(seconds) {
                                var mins = Math.floor(seconds / 60)
                                var secs = Math.floor(seconds % 60)
                                return mins + ":" + (secs < 10 ? "0" : "") + secs
                            }
                        }
                        
                        // Zoom indicator
                        Row {
                            anchors.centerIn: parent
                            spacing: 4
                            visible: parent.width > 80
                            
                            Image {
                                source: "qrc:/resources/icons/zoom.svg"
                                width: 16
                                height: 16
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            
                            Text {
                                text: (effect.params.scale).toFixed(1) + "x"
                                color: "white"
                                font.pixelSize: 12
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        
                        // Main drag area for the whole effect
                        MouseArea {
                            anchors.fill: parent
                            anchors.leftMargin: 8
                            anchors.rightMargin: 8
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            
                            onEntered: {
                                parent.opacity = 0.8
                            }
                            
                            onExited: {
                                parent.opacity = 1.0
                            }
                            
                            onPressed: {
                                zoomEffectRect.isMoving = true
                                zoomEffectRect.originalStartFrame = effect.start_frame
                                zoomEffectRect.originalEndFrame = effect.end_frame
                                zoomEffectRect.dragStartX = mouseX
                            }
                            
                            onPositionChanged: {
                                if (zoomEffectRect.isMoving) {
                                    // Calculate frame delta based on mouse movement
                                    var deltaX = mouseX - zoomEffectRect.dragStartX
                                    var frameDelta = Math.round(deltaX / studioWindow.pixelsPerFrame)
                                    
                                    if (frameDelta !== 0) {
                                        // Calculate new start and end frames
                                        var newStartFrame = zoomEffectRect.originalStartFrame + frameDelta
                                        var newEndFrame = zoomEffectRect.originalEndFrame + frameDelta
                                        var effectDuration = effect.end_frame - effect.start_frame
                                        
                                        // Ensure new frames are within bounds
                                        if (newStartFrame < videoController.start_frame) {
                                            newStartFrame = videoController.start_frame
                                            newEndFrame = newStartFrame + effectDuration
                                        }
                                        
                                        if (newEndFrame > videoController.end_frame) {
                                            newEndFrame = videoController.end_frame
                                            newStartFrame = newEndFrame - effectDuration
                                        }
                                        
                                        // Update the effect in the model if it changed
                                        if (newStartFrame !== effect.start_frame || newEndFrame !== effect.end_frame) {
                                            videoController.update_zoom_effect(
                                                effect.start_frame,
                                                effect.end_frame,
                                                newStartFrame,
                                                newEndFrame,
                                                effect.params
                                            )
                                        }
                                    }
                                }
                            }
                            
                            onReleased: {
                                zoomEffectRect.isMoving = false
                            }
                            
                            onClicked: {
                                contextMenu.popup()
                            }
                        }
                        
                        // Context menu
                        Menu {
                            id: contextMenu
                            
                            MenuItem {
                                text: "Edit Zoom Effect"
                                onTriggered: {
                                    // Jump to middle of zoom effect (using absolute frame numbers)
                                    var middleFrame = effect.start_frame + Math.floor((effect.end_frame - effect.start_frame) / 2)
                                    videoController.jump_to_frame(middleFrame)
                                    
                                    console.log("Editing zoom effect. Jumping to frame:", middleFrame)
                                    
                                    // Activate zoom control in the VideoPreview
                                    var videoPreview = studioWindow.findChild("videoPreview")
                                    if (videoPreview) {
                                        // Set zoom parameters based on the effect
                                        videoPreview.zoomCenterX = effect.params.x
                                        videoPreview.zoomCenterY = effect.params.y
                                        videoPreview.zoomScale = effect.params.scale
                                        
                                        // Show the zoom control with the existing parameters
                                        videoPreview.zoomActive = true
                                        
                                        console.log("Zoom controls activated with:", 
                                                  effect.params.x, effect.params.y, effect.params.scale)
                                    } else {
                                        console.error("Could not find videoPreview component")
                                    }
                                }
                            }
                            
                            MenuItem {
                                text: "Remove Zoom Effect"
                                onTriggered: {
                                    console.log("Removing zoom effect from frame", effect.start_frame, "to", effect.end_frame)
                                    videoController.remove_zoom_effect(effect.start_frame, effect.end_frame)
                                }
                            }
                        }
                        
                        // Auto-zoom indicator (shown for automatically generated zooms)
                        Item {
                            visible: effect.params.auto === true
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 4
                            width: 16
                            height: 16
                            
                            Rectangle {
                                anchors.fill: parent
                                radius: width / 2
                                color: "#282C33"
                                opacity: 0.7
                            }
                            
                            Text {
                                anchors.centerIn: parent
                                text: "A"
                                color: "#7BD57F"
                                font.pixelSize: 10
                                font.bold: true
                            }
                            
                            ToolTip {
                                visible: autoZoomHover.containsMouse
                                text: "Auto-generated zoom from cursor click"
                            }
                            
                            MouseArea {
                                id: autoZoomHover
                                anchors.fill: parent
                                hoverEnabled: true
                            }
                        }
                    }
                }
            }
            
            // Text cards track visualization
            Rectangle {
                id: textCardsBg
                anchors.left: parent.left
                anchors.right: parent.right
                height: 30
                y: zoomTrack.y + zoomTrack.height + 5
                color: "#1e1e1e"
                
                Text {
                    text: "Text Cards"
                    color: "#ffffff"
                    font.pixelSize: 12
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                }
                
                // Repeater for text cards
                Repeater {
                    model: videoController ? videoController.text_cards : []
                    delegate: Rectangle {
                        id: textCardRect
                        property int startFrame: modelData.start_frame
                        property int endFrame: modelData.end_frame
                        property var card: modelData
                        
                        x: videoController ? (startFrame - videoController.start_frame) * pixelsPerFrame + timelineHeaderWidth : 0
                        width: (endFrame - startFrame + 1) * pixelsPerFrame
                        height: textCardsBg.height - 10
                        y: 5
                        radius: 2
                        color: "#FFFFFF"  // White color for text cards
                        border.color: "#CCCCCC"
                        border.width: 1
                        
                        // Text card label
                        Row {
                            anchors.centerIn: parent
                            spacing: 5
                            
                            // Show icon only if there's enough space
                            Image {
                                source: "qrc:/resources/icons/text_card.svg"
                                width: 14
                                height: 14
                                visible: textCardRect.width > 30
                                anchors.verticalCenter: parent.verticalCenter
                            }
                            
                            // Duration text
                            Text {
                                text: videoController ? ((card.end_frame - card.start_frame + 1) / videoController.fps).toFixed(1) + "s" : ""
                                color: "#333333"
                                font.pixelSize: 10
                                visible: textCardRect.width > 40
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }
                        
                        // Handle clicks
                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            
                            onClicked: function(mouse) {
                                if (mouse.button === Qt.LeftButton) {
                                    // Jump to text card position
                                    videoController.jump_to_frame(startFrame)
                                } else if (mouse.button === Qt.RightButton) {
                                    textCardContextMenu.x = mouse.x
                                    textCardContextMenu.y = mouse.y
                                    textCardContextMenu.open()
                                    // Store the current text card for context menu actions
                                    textCardContextMenu.textCardStart = startFrame
                                    textCardContextMenu.textCardEnd = endFrame
                                }
                            }
                            
                            onDoubleClicked: function(mouse) {
                                if (mouse.button === Qt.LeftButton) {
                                    // Open text card editor
                                    textCardEditor.isEditMode = true
                                    textCardEditor.startFrame = startFrame
                                    textCardEditor.endFrame = endFrame
                                    textCardEditor.text = card.params.text
                                    textCardEditor.backgroundColor = card.params.background_color
                                    textCardEditor.textColor = card.params.text_color
                                    textCardEditor.verticalAlignment = card.params.vertical_align
                                    textCardEditor.horizontalAlignment = card.params.horizontal_align
                                    textCardEditor.visible = true
                                }
                            }
                            
                            // Show tooltip with text card information
                            hoverEnabled: true
                            ToolTip.visible: containsMouse
                            ToolTip.text: {
                                var duration = ((endFrame - startFrame + 1) / videoController.fps).toFixed(1)
                                var startTime = (startFrame / videoController.fps).toFixed(1)
                                var endTime = (endFrame / videoController.fps).toFixed(1)
                                return "Text: " + card.params.text.substring(0, 20) + (card.params.text.length > 20 ? "..." : "") +
                                       "\nDuration: " + duration + "s (" + startTime + "s - " + endTime + "s)"
                            }
                            ToolTip.delay: 500
                        }
                    }
                }
                
                // Context menu for text cards
                Menu {
                    id: textCardContextMenu
                    
                    property int textCardStart: -1
                    property int textCardEnd: -1
                    
                    MenuItem {
                        text: "Edit Text Card"
                        onTriggered: {
                            var card = null;
                            for (var i = 0; i < videoController.text_cards.length; i++) {
                                var c = videoController.text_cards[i];
                                if (c.start_frame === textCardContextMenu.textCardStart && 
                                    c.end_frame === textCardContextMenu.textCardEnd) {
                                    card = c;
                                    break;
                                }
                            }
                            
                            if (card) {
                                textCardEditor.isEditMode = true
                                textCardEditor.startFrame = card.start_frame
                                textCardEditor.endFrame = card.end_frame
                                textCardEditor.text = card.params.text
                                textCardEditor.backgroundColor = card.params.background_color
                                textCardEditor.textColor = card.params.text_color
                                textCardEditor.verticalAlignment = card.params.vertical_align
                                textCardEditor.horizontalAlignment = card.params.horizontal_align
                                textCardEditor.visible = true
                            }
                        }
                    }
                    
                    MenuItem {
                        text: "Delete Text Card"
                        onTriggered: {
                            videoController.remove_text_card(textCardContextMenu.textCardStart, 
                                                         textCardContextMenu.textCardEnd)
                        }
                    }
                    
                    MenuItem {
                        text: "Jump to Text Card"
                        onTriggered: {
                            videoController.jump_to_frame(textCardContextMenu.textCardStart)
                        }
                    }
                }
            }

            TimeSlider {
                id: timeSlider
                onXChanged: {
                    var timeSliderGlobalX = timeSlider.mapToItem(scrollView, timeSlider.x, 0).x
                    var viewportWidth = scrollView.width
                    var threshold = viewportWidth * 0.85

                    // Kiểm tra xem timeSlider có vượt quá ngưỡng bên phải không
                    if (timeSliderGlobalX > threshold) {
                        // Tính toán vị trí mới cho contentX để giữ timeSlider trong tầm nhìn
                        var newContentX = timeSlider.x - (viewportWidth * 0.5)
                        // Đảm bảo contentX không vượt quá giới hạn
                        newContentX = Math.min(newContentX, scrollView.contentWidth - viewportWidth)
                        newContentX = Math.max(0, newContentX)
                        scrollView.contentX = newContentX
                    }

                    // Kiểm tra xem timeSlider có vượt quá ngưỡng bên trái không
                    var leftThreshold = viewportWidth * 0.15
                    if (timeSliderGlobalX < leftThreshold) {
                        var newContentX = timeSlider.x - (viewportWidth * 0.5)
                        newContentX = Math.max(0, newContentX)
                        scrollView.contentX = newContentX
                    }
                }
            }

            ToolButton {
                id: zoomOutButton
                anchors.right: parent.right
                anchors.rightMargin: 15
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 15
                icon.source: "qrc:/resources/icons/zoom.svg"
                icon.color: "#e8eaed"
                width: 40
                height: 40
                
                background: Rectangle {
                    color: "#282C33"
                    radius: 20
                }
                
                onClicked: {
                    videoController.create_automatic_zooms_from_cursor()
                }
                
                ToolTip.text: "Add automatic zoom points"
                ToolTip.visible: hovered
                ToolTip.delay: 500
            }
        }
    }

    // Text Card Editor
    TextCardEditor {
        id: textCardEditor
        visible: false
        width: 400
        height: 450
        anchors.centerIn: parent
        z: 1000 // Make sure it appears above other elements
        
        onApplyCard: {
            console.log("VideoEdit TextCardEditor - applyCard signal received")
            // Add text card to the video
            var cardData = textCardEditor.getCardData()
            console.log("VideoEdit TextCardEditor - card data:", JSON.stringify(cardData))
            console.log("VideoEdit TextCardEditor - frames:", textCardEditor.startFrame, textCardEditor.endFrame)
            
            if (textCardEditor.isEditMode) {
                videoController.update_text_card(
                    textCardEditor.startFrame, 
                    textCardEditor.endFrame,
                    textCardEditor.startFrame, // Keep same positions
                    textCardEditor.endFrame,
                    cardData
                )
                console.log("VideoEdit TextCardEditor - updated existing card")
            } else {
                videoController.add_text_card(
                    textCardEditor.startFrame,
                    textCardEditor.endFrame,
                    cardData
                )
                console.log("VideoEdit TextCardEditor - added new card")
            }
            textCardEditor.visible = false
        }
        
        onCancelCard: {
            console.log("VideoEdit TextCardEditor - cancelCard signal received")
            textCardEditor.visible = false
        }
    }

    Connections {
        target: videoController
        function onPlayingChanged(playing) {
            if (!playing) {
                animationEnabled = true
            }
        }
        
        function onZoomEffectsChanged() {
            // The Repeater should automatically update when the model changes
            // This is just to make sure it's working
            console.log("Zoom effects changed, count:", videoController.zoom_effects.length)
            for (var i = 0; i < videoController.zoom_effects.length; i++) {
                var effect = videoController.zoom_effects[i]
                console.log("  Zoom effect " + i + ":", effect.start_frame, "-", effect.end_frame,
                           ", scale:", effect.params.scale)
            }
            
            zoomTrack.visible = false
            zoomTrack.visible = true
        }
    }

    // Zoom timeline width calculation based on content
    function calculateTimelineWidth() {
        if (!videoController) return width;
        
        // Calculate maximum width needed based on content
        let maxEndFrame = 0;
        
        // Check zoom effects
        if (videoController.zoom_effects) {
            for (let i = 0; i < videoController.zoom_effects.length; i++) {
                let effect = videoController.zoom_effects[i];
                if (effect.end_frame > maxEndFrame) {
                    maxEndFrame = effect.end_frame;
                }
            }
        }
        
        // Check text cards
        if (videoController.text_cards) {
            for (let i = 0; i < videoController.text_cards.length; i++) {
                let card = videoController.text_cards[i];
                if (card.end_frame > maxEndFrame) {
                    maxEndFrame = card.end_frame;
                }
            }
        }
        
        // If no content extends beyond video, use video end frame
        if (maxEndFrame === 0 && videoController.end_frame) {
            maxEndFrame = videoController.end_frame;
        }
        
        // Calculate width based on max end frame
        let calculatedWidth = (maxEndFrame - videoController.start_frame + 1) * pixelsPerFrame;
        return Math.max(width, calculatedWidth);
    }
    
    // Update timeline width when content changes
    Connections {
        target: videoController
        function onZoomEffectsChanged() {
            scrollView.contentWidth = calculateTimelineWidth();
        }
        function onTextCardsChanged() {
            scrollView.contentWidth = calculateTimelineWidth();
        }
        function onTotalFramesChanged() {
            scrollView.contentWidth = calculateTimelineWidth();
        }
    }
}