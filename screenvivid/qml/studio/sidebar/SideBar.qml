import QtQuick 6.7
import QtQuick.Layouts 6.7
import QtQuick.Controls 6.7
import "./background_settings"
import "./shape_settings"
import "./cursor_settings"

Rectangle {
    id: sidebarRoot
    Layout.fillHeight: true
    implicitWidth: 400
    color: "#131519"
    radius: 4

    Flickable {
        id: flickable
        anchors.fill: parent
        contentWidth: parent.width
        contentHeight: contentColumn.height
        clip: true

        ColumnLayout {
            id: contentColumn
            width: parent.width
            spacing: 30

            anchors {
                left: parent.left
                right: parent.right
                top: parent.top
                margins: 20
            }

            BackgroundSettings {
                Layout.fillWidth: true
                Layout.preferredHeight: 300
            }

            ShapeSettings {
                Layout.fillWidth: true
                Layout.preferredHeight: 200
            }

            CursorSettings {
                Layout.fillWidth: true
                Layout.preferredHeight: 120
            }

            // Add some extra space at the bottom to ensure all content is accessible
            Item {
                Layout.fillWidth: true
                Layout.preferredHeight: 20
            }
        }
    }

}