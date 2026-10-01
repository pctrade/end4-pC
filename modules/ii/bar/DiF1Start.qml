import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: start
    required property Item di
    anchors.fill: parent

    property int lit: 0
    property bool go: false

    SequentialAnimation {
        running: true
        PauseAnimation { duration: 150 }
        ScriptAction { script: start.lit = 1 }
        PauseAnimation { duration: 400 }
        ScriptAction { script: start.lit = 2 }
        PauseAnimation { duration: 400 }
        ScriptAction { script: start.lit = 3 }
        PauseAnimation { duration: 400 }
        ScriptAction { script: start.lit = 4 }
        PauseAnimation { duration: 400 }
        ScriptAction { script: start.lit = 5 }
        PauseAnimation { duration: 1100 }
        ScriptAction {
            script: {
                start.lit = 0
                start.go = true
            }
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 7
        opacity: start.go ? 0 : 1

        Behavior on opacity {
            NumberAnimation { duration: 250 }
        }

        Repeater {
            model: 5
            delegate: Rectangle {
                id: light
                required property int index
                readonly property bool on: start.lit > light.index
                width: 16
                height: 16
                radius: 8
                color: light.on ? "#FF1744" : Appearance.colors.colLayer2
                scale: light.on ? 1.12 : 1

                Behavior on color {
                    ColorAnimation { duration: 90 }
                }
                Behavior on scale {
                    NumberAnimation { duration: 260; easing.type: Easing.OutBack }
                }
            }
        }
    }

    StyledText {
        anchors.centerIn: parent
        text: Translation.tr("LIGHTS OUT")
        font.pixelSize: Appearance.font.pixelSize.small
        font.weight: Font.Black
        color: "#00E676"
        opacity: start.go ? 1 : 0
        scale: start.go ? 1 : 1.8

        Behavior on opacity {
            NumberAnimation { duration: 200 }
        }
        Behavior on scale {
            NumberAnimation { duration: 480; easing.type: Easing.OutBack }
        }
    }
}
