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
                        // Open the text card editor directly
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
                    
                    ToolTip.text: "Add Text Card"
                    ToolTip.visible: hovered
                    ToolTip.delay: 500
                }
            }
        }
    }

    // Text card editor panel - using Overlay system for proper stacking
    Component.onCompleted: {
        // Parent the dialogs to the application Overlay
        textCardEditor.parent = Overlay.overlay
        
        console.log("TextCardEditor reparented to application Overlay for proper stacking");
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
}