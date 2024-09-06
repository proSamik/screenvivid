import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: root
    Layout.fillWidth: true
    Layout.preferredHeight: 400

    ColumnLayout {
        anchors.fill: parent
        spacing: 20

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Image {
                source: "qrc:/resources/icons/background.svg"
                sourceSize: Qt.size(24, 24)
                Layout.alignment: Qt.AlignVCenter
            }

            Label {
                text: qsTr("Background")
                font.pixelSize: 18
                font.weight: Font.Medium
                color: "#FFFFFF"
            }
        }

        TabBar {
            id: backgroundSettingsBar
            Layout.fillWidth: true
            Layout.preferredHeight: 40
            background: Rectangle {
                color: "#2A2E32"
                radius: 8
            }

            Repeater {
                model: ["Wallpaper", "Gradient", "Color", "Image"]
                TabButton {
                    text: modelData
                    // width: Math.max(100, backgroundSettingsBar.width / 4)
                    Layout.fillWidth: true
                    height: 40

                    contentItem: Text {
                        text: parent.text
                        font: parent.font
                        color: parent.checked ? "#FFFFFF" : "#AAAAAA"
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }

                    background: Rectangle {
                        color: parent.checked ? "#3A7BED" : "transparent"
                        radius: 8
                    }
                }
            }
        }

        StackLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: backgroundSettingsBar.currentIndex

            WallpaperPage {}
            GradientPage {}
            ColorPage {}
            ImagePage {}
        }
    }
}