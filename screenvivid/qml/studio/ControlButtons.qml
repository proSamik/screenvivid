import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "."

Item {
    Layout.fillWidth: true
    Layout.preferredHeight: 50

    RowLayout {
        anchors.fill: parent

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            RowLayout {
                anchors.fill: parent

                ComboBox {
                    id: aspectRatios
                    Layout.fillHeight: true
                    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                    Layout.margins: 4
                    Layout.preferredWidth: 150
                    property var aspectRatioMap: {
                                        "Auto": "auto",
                                        "Wide 16:9": "16:9",
                                        "Vertical 9:16": "9:16",
                                        "Classic 4:3": "4:3",
                                        "Tall 3:4": "3:4",
                                        "Square 1:1": "1:1",
                                    }

                                    currentIndex: 0
                                    model: Object.keys(aspectRatioMap)
                                    onCurrentIndexChanged: {
                                        videoController.aspect_ratio = aspectRatioMap[model[currentIndex]].toLowerCase()
                                        videoController.get_current_frame()
                                    }
                    background: Rectangle {
                        implicitWidth: 150
                        implicitHeight: 40
                        color: aspectRatios.pressed ? "#2c313c" : "#1e2228"
                        border.color: aspectRatios.pressed ? "#3d4450" : "#2c313c"
                        border.width: 1
                        radius: 4
                    }
                    contentItem: Text {
                        leftPadding: 10
                        rightPadding: aspectRatios.indicator.width + aspectRatios.spacing
                        text: aspectRatios.displayText
                        font: aspectRatios.font
                        color: "#e8eaed"
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        width: aspectRatios.width - leftPadding - rightPadding
                    }
                    delegate: ItemDelegate {
                        width: aspectRatios.popup.width
                        height: 40
                        contentItem: Text {
                            text: modelData
                            color: "#e8eaed"
                            font: aspectRatios.font
                            elide: Text.ElideRight
                            verticalAlignment: Text.AlignVCenter
                            leftPadding: 10
                        }
                        highlighted: aspectRatios.highlightedIndex === index
                        background: Rectangle {
                            color: highlighted ? "#3d4450" : "transparent"
                        }
                    }
                    popup: Popup {
                        y: aspectRatios.height + 4
                        x: -(width - aspectRatios.width) / 2
                        width: Math.max(aspectRatios.width, 180)  // Increased minimum width
                        implicitHeight: contentItem.implicitHeight
                        padding: 1
                        contentItem: ListView {
                            clip: true
                            implicitHeight: contentHeight
                            model: aspectRatios.popup.visible ? aspectRatios.delegateModel : null
                            currentIndex: aspectRatios.highlightedIndex
                            ScrollIndicator.vertical: ScrollIndicator {}
                        }
                        background: Rectangle {
                            border.color: "#3d4450"
                            color: "#1e2228"
                            radius: 4
                        }
                        enter: Transition {
                            NumberAnimation { property: "opacity"; from: 0.0; to: 1.0; duration: 100 }
                        }
                        exit: Transition {
                            NumberAnimation { property: "opacity"; from: 1.0; to: 0.0; duration: 100 }
                        }
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            RowLayout {
                anchors.centerIn: parent
                spacing: 10

                ToolButton {
                    icon.source: "qrc:/resources/icons/prev.svg"
                    icon.color: "#e8eaed"
                    onClicked: videoController.prev_frame()
                }
                ToolButton {
                    icon.source: isPlaying ? "qrc:/resources/icons/pause.svg" : "qrc:/resources/icons/play.svg"
                    icon.color: "#e8eaed"
                    onClicked: videoController.toggle_play_pause()
                }
                ToolButton {
                    icon.source: "qrc:/resources/icons/next.svg"
                    icon.color: "#e8eaed"
                    onClicked: videoController.next_frame()
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            RowLayout {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 10
                spacing: 10
                
                ToolButton {
                    id: cutButton
                    icon.source: "qrc:/resources/icons/cut.svg"
                    icon.color: "#e8eaed"
                    icon.width: 22
                    icon.height: 22
                    onClicked: clipTrackModel.cut_clip()
                    
                    ToolTip.text: "Cut Clip"
                    ToolTip.visible: hovered
                    ToolTip.delay: 500
                }
                
                ToolButton {
                    id: textCardButton
                    icon.source: "qrc:/resources/icons/text_card.svg"
                    icon.color: "#e8eaed"
                    icon.width: 22
                    icon.height: 22
                    onClicked: {
                        textCardMenu.open()
                    }
                    
                    ToolTip.text: "Add Text Card"
                    ToolTip.visible: hovered
                    ToolTip.delay: 500
                    
                    Menu {
                        id: textCardMenu
                        y: textCardButton.height
                        
                        MenuItem {
                            text: "Add Text Card at Current Position"
                            onTriggered: {
                                // Open the text card editor first to let user set duration
                                console.log("Preparing to add text card at: " + videoController.absolute_current_frame);
                                textCardEditor.isEditMode = false;
                                
                                // Set initial values but don't create gap yet
                                textCardEditor.startFrame = videoController.absolute_current_frame;
                                textCardEditor.endFrame = -1; // Will be calculated when user applies
                                textCardEditor.text = "Lorem ipsum dolor sit amet";
                                textCardEditor.cardDuration = 3.0; // Default but can be changed by user
                                
                                // Apply handler will create the gap with the correct duration
                                textCardEditor.createGapOnApply = true;
                                textCardEditor.visible = true;
                                
                                console.log("Text card editor opened for duration selection");
                            }
                        }
                        
                        MenuItem {
                            text: "Auto-detect Cuts and Add Cards"
                            onTriggered: {
                                // Detect cuts and show dialog to add cards at cuts
                                var cuts = videoController.detect_cuts(5)
                                console.log("Detected cuts:", JSON.stringify(cuts))
                                
                                if (cuts.cuts && cuts.cuts.length > 0) {
                                    // Process cuts and prepare data for display
                                    var processedCuts = []
                                    
                                    // First, collect all the cuts information
                                    for (var i = 0; i < cuts.cuts.length; i++) {
                                        var cut = cuts.cuts[i];
                                        
                                        // Default duration for text card in seconds
                                        var cardDurationSec = 3;
                                        var frameCount = Math.round(cardDurationSec * videoController.fps);
                                        
                                        // Calculate intended start/end frames for the text card
                                        var textCardCut = {
                                            start_frame: cut.end_frame + 1,
                                            end_frame: cut.end_frame + frameCount,
                                            duration_frames: frameCount,
                                            duration_seconds: cardDurationSec,
                                            cut_index: i,
                                            original_cut: cut
                                        };
                                        
                                        processedCuts.push(textCardCut);
                                        console.log("Adding cut for text card:", JSON.stringify(textCardCut));
                                    }
                                    
                                    // Update the dialog with the processed cuts
                                    if (processedCuts.length > 0) {
                                        detectCutsDialog.cuts = processedCuts;
                                        detectCutsDialog.visible = true;
                                    } else {
                                        noDetectedCutsDialog.open();
                                    }
                                } else {
                                    noDetectedCutsDialog.open();
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Text card editor panel - using Overlay system for proper stacking
    Component.onCompleted: {
        // Parent the dialogs to the application Overlay
        textCardEditor.parent = Overlay.overlay
        detectCutsDialog.parent = Overlay.overlay
        noDetectedCutsDialog.parent = Overlay.overlay
        
        console.log("Dialogs reparented to application Overlay for proper stacking");
    }
    
    TextCardEditor {
        id: textCardEditor
        visible: false
        width: 400
        height: 450
        anchors.centerIn: Overlay.overlay
        objectName: "textCardEditor"
        // z-index is handled by Overlay
        
        onApplyCard: {
            console.log("TextCardEditor - applyCard signal received")
            
            // Add text card to the video
            var cardData = textCardEditor.getCardData()
            console.log("TextCardEditor - card data:", JSON.stringify(cardData))
            
            if (textCardEditor.createGapOnApply) {
                // Calculate the actual duration in frames based on user selection
                var frameCount = Math.round(cardData.duration_seconds * videoController.fps);
                var currentFrame = textCardEditor.startFrame;
                
                console.log("Creating gap of " + cardData.duration_seconds + " seconds (" + 
                           frameCount + " frames) at frame " + currentFrame);
                
                // Create gap by shifting clips after the current position
                clipTrackModel.create_gap_at_frame(currentFrame, frameCount);
                
                // Update end frame based on actual gap size
                textCardEditor.endFrame = currentFrame + frameCount - 1;
            }
            
            console.log("TextCardEditor - frames:", textCardEditor.startFrame, textCardEditor.endFrame)
            
            if (textCardEditor.isEditMode) {
                videoController.update_text_card(
                    textCardEditor.startFrame, 
                    textCardEditor.endFrame,
                    textCardEditor.startFrame, // Keep same positions
                    textCardEditor.endFrame,
                    cardData
                )
                console.log("TextCardEditor - updated existing card")
            } else {
                videoController.add_text_card(
                    textCardEditor.startFrame,
                    textCardEditor.endFrame,
                    cardData
                )
                console.log("TextCardEditor - added new card")
            }
            textCardEditor.visible = false
            textCardEditor.createGapOnApply = false // Reset flag
        }
        
        onCancelCard: {
            console.log("TextCardEditor - cancelCard signal received")
            textCardEditor.visible = false
        }
    }
    
    // Dialog for auto-detected cuts
    Dialog {
        id: detectCutsDialog
        title: "Add Text Cards at Cuts"
        width: 500
        height: 400
        anchors.centerIn: Overlay.overlay
        modal: true
        
        property var cuts: []
        property string defaultText: "Lorem ipsum dolor sit amet"
        property string backgroundColor: "black"
        property string textColor: "white"
        
        header: Rectangle {
            width: parent.width
            height: 50
            color: "#333333"
            
            Text {
                anchors.centerIn: parent
                text: "Detected Cut Points"
                color: "white"
                font.pixelSize: 16
                font.bold: true
            }
        }
        
        contentItem: ColumnLayout {
            spacing: 10
            
            Text {
                text: "The following cut points were detected. Select which ones to add text cards to:"
                color: "white"
                wrapMode: Text.Wrap
                Layout.fillWidth: true
            }
            
            ListView {
                id: cutsListView
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                model: detectCutsDialog.cuts
                
                delegate: Rectangle {
                    width: cutsListView.width
                    height: 60
                    color: index % 2 === 0 ? "#2A2A2A" : "#333333"
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 10
                        spacing: 10
                        
                        CheckBox {
                            id: cutCheckbox
                            checked: true
                        }
                        
                        Column {
                            Layout.fillWidth: true
                            
                            Text {
                                text: "Cut #" + (index + 1)
                                color: "white"
                                font.bold: true
                            }
                            
                            Text {
                                // Calculate time in seconds from frames
                                property real startTime: modelData.start_frame / videoController.fps
                                property real endTime: modelData.end_frame / videoController.fps
                                property real duration: modelData.duration_seconds || 
                                                       (modelData.duration_frames / videoController.fps)
                                
                                text: "Gap: " + formatTime(startTime) + " - " + formatTime(endTime) + 
                                      " (Duration: " + duration.toFixed(1) + "s)"
                                color: "#CCCCCC"
                                font.pixelSize: 12
                                
                                function formatTime(seconds) {
                                    var mins = Math.floor(seconds / 60)
                                    var secs = Math.floor(seconds % 60)
                                    return mins + ":" + (secs < 10 ? "0" : "") + secs
                                }
                            }
                        }
                        
                        Button {
                            text: "Preview"
                            onClicked: {
                                videoController.jump_to_frame(modelData.start_frame)
                            }
                        }
                    }
                }
            }
            
            // Common text settings
            GroupBox {
                title: "Text Card Settings"
                Layout.fillWidth: true
                
                background: Rectangle {
                    color: "#2A2A2A"
                    border.color: "#555555"
                    border.width: 1
                    radius: 5
                }
                
                ColumnLayout {
                    anchors.fill: parent
                    
                    RowLayout {
                        Layout.fillWidth: true
                        
                        Text {
                            text: "Default Text:"
                            color: "white"
                        }
                        
                        TextField {
                            id: defaultTextField
                            Layout.fillWidth: true
                            text: detectCutsDialog.defaultText
                            onTextChanged: {
                                detectCutsDialog.defaultText = text
                            }
                        }
                    }
                    
                    RowLayout {
                        Layout.fillWidth: true
                        
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
                                border.width: detectCutsDialog.backgroundColor === "black" ? 2 : 0
                                border.color: "#7BD57F"
                                
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        detectCutsDialog.backgroundColor = "black"
                                    }
                                }
                            }
                            
                            Rectangle {
                                width: 20
                                height: 20
                                color: "white"
                                border.width: detectCutsDialog.backgroundColor === "white" ? 2 : 0
                                border.color: "#7BD57F"
                                
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        detectCutsDialog.backgroundColor = "white"
                                    }
                                }
                            }
                        }
                        
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
                                border.width: detectCutsDialog.textColor === "white" ? 2 : 0
                                border.color: "#7BD57F"
                                
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        detectCutsDialog.textColor = "white"
                                    }
                                }
                            }
                            
                            Rectangle {
                                width: 20
                                height: 20
                                color: "black"
                                border.width: detectCutsDialog.textColor === "black" ? 2 : 0
                                border.color: "#7BD57F"
                                
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: {
                                        detectCutsDialog.textColor = "black"
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        footer: DialogButtonBox {
            Button {
                text: "Cancel"
                DialogButtonBox.buttonRole: DialogButtonBox.RejectRole
            }
            
            Button {
                text: "Apply to Selected"
                DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole
                highlighted: true
            }
            
            onRejected: {
                detectCutsDialog.close()
            }
            
            onAccepted: {
                // Apply text cards to all selected cuts - do this in reverse order to maintain frame positions
                var selectedCuts = [];
                
                // First collect all selected cuts
                for (var i = 0; i < cutsListView.count; i++) {
                    var item = cutsListView.itemAtIndex(i);
                    if (item && item.children[0].children[0].checked) {
                        selectedCuts.push(detectCutsDialog.cuts[i]);
                    }
                }
                
                console.log("Selected cuts:", selectedCuts.length);
                
                // Process cuts in reverse order to maintain frame positions
                for (var j = selectedCuts.length - 1; j >= 0; j--) {
                    var cutData = selectedCuts[j];
                    
                    // Create a gap at the position
                    console.log("Creating gap at frame " + cutData.start_frame + " with duration " + 
                                cutData.duration_frames + " frames");
                    
                    clipTrackModel.create_gap_at_frame(cutData.start_frame - 1, cutData.duration_frames);
                    
                    // Add the text card in the gap
                    videoController.add_text_card(
                        cutData.start_frame,
                        cutData.start_frame + cutData.duration_frames - 1,
                        {
                            "background_color": detectCutsDialog.backgroundColor,
                            "text": detectCutsDialog.defaultText,
                            "text_color": detectCutsDialog.textColor,
                            "duration_seconds": cutData.duration_seconds,
                            "horizontal_align": "center",
                            "vertical_align": "middle"
                        }
                    );
                    
                    console.log("Added text card at frames " + cutData.start_frame + 
                               " to " + (cutData.start_frame + cutData.duration_frames - 1));
                }
                
                detectCutsDialog.close();
            }
        }
    }
    
    // Dialog for when no cuts are detected
    Dialog {
        id: noDetectedCutsDialog
        title: "No Cuts Detected"
        width: 400
        height: 200
        anchors.centerIn: Overlay.overlay
        modal: true
        
        contentItem: ColumnLayout {
            spacing: 20
            
            Text {
                text: "No cut points were detected in the video.\n\nTo add text cards, please first cut your video using the scissor tool, or manually add a text card at the current position."
                color: "white"
                wrapMode: Text.Wrap
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
            }
        }
        
        footer: DialogButtonBox {
            Button {
                text: "OK"
                DialogButtonBox.buttonRole: DialogButtonBox.AcceptRole
                highlighted: true
            }
            
            onAccepted: {
                noDetectedCutsDialog.close()
            }
        }
    }
}