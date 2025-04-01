import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    color: "#2A2A2A"
    radius: 10
    opacity: 0.95
    
    property string selectedBgColor: "black"
    property string selectedTextColor: "white"
    property string horizontalAlign: "center"
    property string verticalAlign: "middle"
    property alias text: textArea.text
    property real cardDuration: 3.0  // seconds
    property bool isEditMode: false
    property int startFrame: -1
    property int endFrame: -1
    
    // Signals
    signal applyCard()
    signal cancelCard()
    
    // Return text card data as a dictionary
    function getCardData() {
        return {
            "background_color": selectedBgColor,
            "text": textArea.text,
            "text_color": selectedTextColor,
            "duration_seconds": cardDuration,
            "horizontal_align": horizontalAlign,
            "vertical_align": verticalAlign
        }
    }
    
    function setCardData(data) {
        selectedBgColor = data.background_color || "black"
        textArea.text = data.text || "Lorem ipsum dolor sit amet"
        selectedTextColor = data.text_color || "white"
        cardDuration = data.duration_seconds || 3.0
        horizontalAlign = data.horizontal_align || "center"
        verticalAlign = data.vertical_align || "middle"
    }
    
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 15
        
        // Header
        Text {
            text: isEditMode ? "Edit Text Card" : "Add Text Card"
            font.bold: true
            font.pixelSize: 16
            color: "white"
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
        }
        
        // Text editor
        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredHeight: 120
            color: selectedBgColor === "black" ? "#000000" : "#FFFFFF"
            border.color: "#555555"
            border.width: 1
            
            ScrollView {
                id: textScroll
                anchors.fill: parent
                anchors.margins: 10
                clip: true
                
                TextArea {
                    id: textArea
                    color: selectedTextColor === "black" ? "#000000" : "#FFFFFF"
                    wrapMode: TextEdit.Wrap
                    placeholderText: "Enter text for typewriter effect..."
                    placeholderTextColor: selectedTextColor === "black" ? "#555555" : "#AAAAAA"
                    background: null
                    selectByMouse: true
                    text: "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Edit this text."
                    
                    horizontalAlignment: {
                        if (horizontalAlign === "left") return Text.AlignLeft
                        else if (horizontalAlign === "right") return Text.AlignRight
                        else return Text.AlignHCenter
                    }
                    
                    verticalAlignment: {
                        if (verticalAlign === "top") return Text.AlignTop
                        else if (verticalAlign === "bottom") return Text.AlignBottom
                        else return Text.AlignVCenter
                    }
                }
            }
        }
        
        // Controls for appearance
        GridLayout {
            columns: 2
            Layout.fillWidth: true
            rowSpacing: 8
            columnSpacing: 10
            
            // Background color
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
                    border.width: selectedBgColor === "black" ? 2 : 0
                    border.color: "#7BD57F"
                    
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            selectedBgColor = "black"
                        }
                    }
                }
                
                Rectangle {
                    width: 20
                    height: 20
                    color: "white"
                    border.width: selectedBgColor === "white" ? 2 : 0
                    border.color: "#7BD57F"
                    
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            selectedBgColor = "white"
                        }
                    }
                }
            }
            
            // Text color
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
                    border.width: selectedTextColor === "white" ? 2 : 0
                    border.color: "#7BD57F"
                    
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            selectedTextColor = "white"
                        }
                    }
                }
                
                Rectangle {
                    width: 20
                    height: 20
                    color: "black"
                    border.width: selectedTextColor === "black" ? 2 : 0
                    border.color: "#7BD57F"
                    
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            selectedTextColor = "black"
                        }
                    }
                }
            }
            
            // Horizontal alignment
            Text {
                text: "Horizontal Align:"
                color: "white"
            }
            
            RowLayout {
                spacing: 5
                
                Button {
                    icon.source: "qrc:/resources/icons/align_left.svg"
                    icon.color: horizontalAlign === "left" ? "#7BD57F" : "#CCCCCC"
                    background: Rectangle {
                        color: "transparent"
                    }
                    onClicked: {
                        horizontalAlign = "left"
                    }
                }
                
                Button {
                    icon.source: "qrc:/resources/icons/align_center.svg"
                    icon.color: horizontalAlign === "center" ? "#7BD57F" : "#CCCCCC"
                    background: Rectangle {
                        color: "transparent"
                    }
                    onClicked: {
                        horizontalAlign = "center"
                    }
                }
                
                Button {
                    icon.source: "qrc:/resources/icons/align_right.svg"
                    icon.color: horizontalAlign === "right" ? "#7BD57F" : "#CCCCCC"
                    background: Rectangle {
                        color: "transparent"
                    }
                    onClicked: {
                        horizontalAlign = "right"
                    }
                }
            }
            
            // Vertical alignment
            Text {
                text: "Vertical Align:"
                color: "white"
            }
            
            RowLayout {
                spacing: 5
                
                Button {
                    icon.source: "qrc:/resources/icons/align_top.svg"
                    icon.color: verticalAlign === "top" ? "#7BD57F" : "#CCCCCC"
                    background: Rectangle {
                        color: "transparent"
                    }
                    onClicked: {
                        verticalAlign = "top"
                    }
                }
                
                Button {
                    icon.source: "qrc:/resources/icons/align_middle.svg"
                    icon.color: verticalAlign === "middle" ? "#7BD57F" : "#CCCCCC"
                    background: Rectangle {
                        color: "transparent"
                    }
                    onClicked: {
                        verticalAlign = "middle"
                    }
                }
                
                Button {
                    icon.source: "qrc:/resources/icons/align_bottom.svg"
                    icon.color: verticalAlign === "bottom" ? "#7BD57F" : "#CCCCCC"
                    background: Rectangle {
                        color: "transparent"
                    }
                    onClicked: {
                        verticalAlign = "bottom"
                    }
                }
            }
            
            // Duration control
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                
                Text {
                    text: "Duration:"
                    color: "white"
                }
                
                SpinBox {
                    id: durationSpinBox
                    from: 1
                    to: 20
                    value: cardDuration
                    onValueChanged: cardDuration = value
                    editable: true
                    
                    Layout.preferredWidth: 120
                    Layout.alignment: Qt.AlignVCenter
                }
                
                Text {
                    text: "seconds"
                    color: "white"
                }
            }
        }
        
        // Save/Cancel buttons
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 15
            spacing: 10
            
            Item { Layout.fillWidth: true }
            
            Button {
                text: "Cancel"
                Layout.preferredWidth: 100
                onClicked: cancelCard()
                
                background: Rectangle {
                    color: "#444444"
                    radius: 4
                }
                
                contentItem: Text {
                    text: parent.text
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
            
            Button {
                text: "Save"
                Layout.preferredWidth: 100
                onClicked: applyCard()
                
                background: Rectangle {
                    color: "#545EEE"
                    radius: 4
                }
                
                contentItem: Text {
                    text: parent.text
                    color: "white"
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
    }
} 