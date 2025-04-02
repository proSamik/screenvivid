import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "../components"
import "."

Item {
    // ... existing code ...

    // Keyboard shortcuts
    Shortcut {
        sequence: StandardKey.Undo
        onActivated: {
            console.log("Undo shortcut triggered")
            videoController.undo()
        }
    }
    
    Shortcut {
        sequence: StandardKey.Redo
        onActivated: {
            console.log("Redo shortcut triggered")
            videoController.redo()
        }
    }
    
    // ... existing code ...
} 