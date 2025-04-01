import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
// Import components directly 
import "." // Import local directory components

ColumnLayout {
    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.minimumHeight: 400
    Layout.minimumWidth: 400

    VideoPreview {
        Layout.fillWidth: true
        Layout.fillHeight: true
    }

    ControlButtons {
        Layout.fillWidth: true
        Layout.preferredHeight: 50
    }
}
