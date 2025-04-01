import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Controls.Material
import "./sidebar"
// Remove the complicated imports
// import "." as Studio

// Import components directly
// import "qrc:/qml/studio" as Studio

Window {
    id: studioWindow

    // Window properties
    readonly property int defaultWidth: Screen.width
    readonly property int defaultHeight: Screen.height
    readonly property int minWidth: Screen.width / 2
    readonly property int minHeight: Screen.height / 2

    // Theme colors
    readonly property string accentColor: "#545EEE"
    readonly property string backgroundColor: "#0B0D0F"

    // Video state properties
    property bool isPlaying: false
    property int fps: 30
    property int totalFrames: 0
    property int pixelsPerFrame: 6
    property real videoLen: 0
    property int frameWidth: 0
    property int frameHeight: 0

    // Window setup
    width: defaultWidth
    height: defaultHeight
    minimumWidth: minWidth
    minimumHeight: minHeight
    title: qsTr("ScreenVivid")
    visible: true
    visibility: Window.Maximized

    // Material theme
    Material.theme: Material.Dark
    Material.primary: accentColor
    Material.accent: accentColor

    // Shortcut management
    QtObject {
        id: shortcutManager
        readonly property bool isMac: Qt.platform.os === "osx"
        readonly property string undoModifier: isMac ? "Meta" : "Ctrl"

        function handleUndo() {
            clipTrackModel.undo()
            videoController.undo()
        }

        function handlePlayPause() {
            videoController.toggle_play_pause()
        }

        function handlePrevFrame() {
            videoController.prev_frame()
        }

        function handleNextFrame() {
            videoController.next_frame()
        }
    }


    Shortcut {
        sequence: "Space"
        onActivated: shortcutManager.handlePlayPause()
    }

    Shortcut {
        sequence: "Left"
        onActivated: shortcutManager.handlePrevFrame()
    }

    Shortcut {
        sequence: "Right"
        onActivated: shortcutManager.handleNextFrame()
    }

    Shortcut {
        sequence: shortcutManager.undoModifier + "+Z"
        onActivated: shortcutManager.handleUndo()
    }

    // Video controller connections
    Connections {
        target: videoController
        function onPlayingChanged(playing) {
            isPlaying = playing
        }
    }

    // Main UI
    ExportDialog {
        id: exportDialog
        parent: Overlay.overlay
        exportFps: videoController.fps
    }

    Rectangle {
        anchors.fill: parent
        color: backgroundColor

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 15
            spacing: 0

            TopBar {
                id: topbar
                Layout.fillWidth: true
                Layout.preferredHeight: 50
            }

            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                RowLayout {
                    anchors.fill: parent
                    spacing: 30

                    MainContent {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }

                    ColumnLayout {
                        Layout.fillHeight: true
                        Layout.preferredWidth: 400

                        SideBar {
                            id: sidebar
                            Layout.preferredWidth: 450
                            Layout.fillHeight: true
                        }

                        Item {
                            Layout.preferredHeight: 50
                            Layout.preferredWidth: 400
                        }
                    }
                }
            }

            VideoEdit {
                id: videoEdit
                Layout.fillWidth: true
                Layout.preferredHeight: 180
                objectName: "videoEdit"
            }
        }
    }

    // Initialization
    Component.onCompleted: {
        fps = videoController.fps
        totalFrames = videoController.total_frames
        videoLen = videoController.video_len
        videoController.get_current_frame()
        videoController.aspect_ratio = "auto"
    }

    // Cleanup
    onClosing: {
        screenRecorder.clean()
        videoController.clean()

        Qt.quit()
    }
}