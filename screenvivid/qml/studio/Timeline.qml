import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: timelineRoot
    color: "#1A1D21"
    
    property real pixelsPerFrame: studioWindow.pixelsPerFrame
    property int frameCount: videoController ? videoController.total_frames : 0  // Null check
    
    // Default fps when videoController is not available
    property int defaultFps: 30
    
    // Width of timeline is based on frame count and pixels per frame
    property int contentWidth: Math.max(timelineRoot.width, frameCount * pixelsPerFrame)
    
    // Add property to explicitly track updates to total frames
    property bool updatingTotalFrames: false
    
    onFrameCountChanged: {
        console.log("Timeline frameCount changed: " + frameCount + " frames")
        // Update the width when frame count changes (new text cards added)
        contentWidth = Math.max(timelineRoot.width, frameCount * pixelsPerFrame)
    }
    
    // Video length in seconds for display - use defaultFps as fallback
    property real videoLength: videoController ? frameCount / videoController.fps : (frameCount / defaultFps)  // Null check with fallback

    // Calculate time at a given position with fallback
    function positionToTime(position) {
        var frame = position / pixelsPerFrame
        return videoController ? (frame / videoController.fps) : (frame / defaultFps)  // Use defaultFps if null
    }

    // Timeline - now inside the Rectangle
    Repeater {
        model: Math.max(1, Math.ceil(videoLength) + 1)  // Ensure at least 1 marker is shown

        Item {
            width: (videoController ? videoController.fps : defaultFps) * pixelsPerFrame
            height: 60
            x: (videoController ? videoController.fps : defaultFps) * pixelsPerFrame * index
            // y: 10

            readonly property int timeLabelWidth: 20

            Item {
                width: parent.timeLabelWidth
                height: parent.height

                ColumnLayout {
                    anchors.fill: parent
                    spacing: 10

                    Item {
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                    }

                    Label {
                        Layout.alignment: Qt.AlignCenter
                        text: qsTr("" + index)
                    }

                    Item {
                        Layout.alignment: Qt.AlignCenter

                        Rectangle {
                            width: 4
                            height: 4
                            radius: 2
                            color: "white"
                            anchors.centerIn: parent
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                        Layout.fillWidth: true
                    }
                }
            }
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (!videoController) return;  // Null check
                    var xPos = Math.max(
                                0,
                                (videoController ? videoController.fps : defaultFps) * pixelsPerFrame * index + mouseX
                                - parent.timeLabelWidth / 2)
                    var currentFrame = Math.round(
                                xPos / pixelsPerFrame)
                    videoController.jump_to_frame(
                                currentFrame)
                }
            }
        }
    }

    // Connect to the videoController signals
    Connections {
        target: videoController
        
        function onTotalFramesChanged() {
            if (videoController) {
                updatingTotalFrames = true
                frameCount = videoController.total_frames
                console.log("Timeline: total frames updated to " + frameCount + 
                            ", duration: " + (frameCount/defaultFps).toFixed(2) + "s")
                updatingTotalFrames = false
            }
        }
        
        function onEndFrameChanged() {
            if (videoController && !updatingTotalFrames) {
                frameCount = videoController.total_frames
                console.log("Timeline: frames updated from end_frame change: " + frameCount + 
                            ", duration: " + (frameCount/defaultFps).toFixed(2) + "s")
            }
        }
    }
}