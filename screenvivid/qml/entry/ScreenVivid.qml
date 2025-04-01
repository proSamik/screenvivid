import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls.Material
import QtQuick.Dialogs
import "../components"

Window {
    id: startupWindow
    visible: true
    width: Screen.width
    height: Screen.height
    visibility: Qt.platform.os === "osx" ? Window.Windowed : Window.FullScreen
    flags: Qt.FramelessWindowHint
    color: "transparent"
    title: qsTr("ScreenVivid")

    property string selectedMode: "screen"
    property bool showCountdownFlag: false
    property bool showStudioFlag: false
    readonly property string selectionColor: "#e85c0d"

    Item {
        id: homeItem
        anchors.fill: parent
        focus: true

        Rectangle {
            id: background
            anchors.fill: parent
            color: "transparent"
        }

        // Visualize selected region in screen mode mode
        Rectangle {
            id: screenModeSelector
            anchors.fill: parent
            color: Qt.rgba(0.91, 0.36, 0.05, 0.3)
            border.width: 2
            border.color: startupWindow.selectionColor
            visible: startupWindow.selectedMode == "screen"
        }

        // Visualize selected region in window mode
        Item {
            id: safeAreaModeSelector
            anchors.fill: parent
            visible: startupWindow.selectedMode == "safeArea"
            Rectangle {
                x: windowController.left
                y: windowController.top
                width: Screen.desktopAvailableWidth
                height: Screen.desktopAvailableHeight
                color: Qt.rgba(0.91, 0.36, 0.05, 0.3)
                border.width: 2
                border.color: startupWindow.selectionColor
            }
        }

        CustomSelector {
            id: customSelector
            visible: startupWindow.selectedMode == "custom"
        }

        // Control panel
        ControlPanel {
            id: controlPanel
            Component.onCompleted: {
                // Set the position of the control panel to the bottom of the screen
                controlPanel.x = (Screen.width - controlPanel.width) / 2
                controlPanel.y = Screen.height - controlPanel.height - controlPanel.bottomMargin
            }
        }

        FileDialog {
            id: videoFileDialog
            nameFilters: ["Video files (*.mp4 *.avi *.webm)"]
            onAccepted: {
                startupWindow.visible = true
                if (selectedFile) {
                    const metadata = {
                        'mouse_events': {'click': [], 'move': {}},
                        'region': [],
                        'recording': false
                    }
                    var success = videoController.load_video(selectedFile,
                                            metadata)

                    if (success) {
                        if (videoController.fps <= 0 || videoController.fps > 200 || videoController.total_frames <= 0) {
                            errorDialog.open()
                        } else {
                            clipTrackModel.set_fps(videoController.fps)
                            clipTrackModel.set_video_len(0, videoController.video_len)

                            // Add error handling around studio loader
                            try {
                                studioLoader.source = ""
                                studioLoader.source = "qrc:/qml/studio/Studio.qml"
                                
                                // Only call showMaximized if the component loaded successfully
                                if (studioLoader.status === Loader.Ready && studioLoader.item) {
                                    studioLoader.item.showMaximized()
                                } else {
                                    console.error("Failed to load studio component:", studioLoader.status)
                                }
                            } catch (e) {
                                console.error("Error loading studio:", e)
                            }
                            startupWindow.hide()
                        }
                    } else {
                        errorDialog.open()
                    }
                }
            }

            onRejected: {
                startupWindow.showFullScreen()
            }
        }

        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Escape) {
                                Qt.quit()
                            }
                        }
    }

    Loader {
        id: countdownLoader
    }

    Loader {
        id: studioLoader
    }

    Component.onCompleted: {
        // Set device pixel ratio
        screenRecorder.device_pixel_ratio = Screen.devicePixelRatio
        videoController.device_pixel_ratio = Screen.devicePixelRatio
    }
}
