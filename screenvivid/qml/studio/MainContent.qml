import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
// Import components directly 
import "." // Import local directory components

Item {
    id: mainContentRoot
    
    // Main content layout
    ColumnLayout {
        anchors.fill: parent
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.minimumHeight: 400
        Layout.minimumWidth: 400
        z: 1  // Base layer

        VideoPreview {
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        ControlButtons {
            Layout.fillWidth: true
            Layout.preferredHeight: 50
        }
    }
}
