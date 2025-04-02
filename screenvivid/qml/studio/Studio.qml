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
    property real videoLen: totalFrames / fps  // Calculate from totalFrames
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
            console.log("Undo action triggered")
            videoController.undo()
        }
        
        function handleRedo() {
            console.log("Redo action triggered")
            videoController.redo()
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
    
    Shortcut {
        sequence: shortcutManager.undoModifier + "+Shift+Z"
        onActivated: shortcutManager.handleRedo()
    }
    
    // Alternative redo shortcut (Ctrl+Y on Windows/Linux)
    Shortcut {
        sequence: shortcutManager.isMac ? "" : "Ctrl+Y"
        enabled: !shortcutManager.isMac
        onActivated: shortcutManager.handleRedo()
    }

    // Video controller connections
    Connections {
        target: videoController
        function onPlayingChanged(playing) {
            isPlaying = playing
        }
        function onTotalFramesChanged() {
            if (videoController) {
                totalFrames = videoController.total_frames
                // Update videoLen after totalFrames has been updated
                videoLen = totalFrames / fps
                console.log("Total frames changed: " + totalFrames + ", new videoLen: " + videoLen.toFixed(2) + "s")
            }
        }
        function onEndFrameChanged() {
            if (videoController) {
                // Make sure totalFrames reflects any changes to end_frame
                totalFrames = videoController.total_frames
                videoLen = totalFrames / fps
                console.log("End frame changed: total frames = " + totalFrames + ", videoLen = " + videoLen.toFixed(2) + "s")
            }
        }
        function onFpsChanged() {
            if (videoController) {
                fps = videoController.fps
                // Recalculate videoLen when FPS changes
                videoLen = totalFrames / fps
                console.log("FPS changed: " + fps + ", new videoLen: " + videoLen.toFixed(2) + "s")
            }
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

    // Initialization with safe defaults
    Component.onCompleted: {
        // Set safe defaults first
        fps = 30
        totalFrames = 0
        videoLen = 0
        frameWidth = 1920
        frameHeight = 1080
        
        // Then update from videoController if available
        if (videoController) {
            fps = videoController.fps || 30
            totalFrames = videoController.total_frames || 0
            videoLen = totalFrames / fps
            videoController.get_current_frame()
            videoController.aspect_ratio = "auto"
        } else {
            console.warn("videoController not available during initialization - using default values")
        }
    }

    // Connection to ensure properties are updated once videoController is available
    Connections {
        target: videoController
        enabled: videoController !== null  // Only enable when controller exists
        
        function onVideoLoaded() {
            // Update properties when video is loaded
            fps = videoController.fps
            totalFrames = videoController.total_frames
            videoLen = totalFrames / fps
            console.log("Video loaded, totalFrames: " + totalFrames + ", fps: " + fps)
        }
        
        function onTotalFramesChanged() {
            if (videoController) {
                totalFrames = videoController.total_frames
                console.log("Total frames changed: " + totalFrames + ", new videoLen: " + videoLen)
            }
        }
    }

    // Cleanup
    onClosing: {
        screenRecorder.clean()
        videoController.clean()

        Qt.quit()
    }
}