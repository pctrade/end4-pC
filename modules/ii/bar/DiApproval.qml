import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// An agent stopped on a permission dialog (ClaudeCode.approval) — CRITICAL: ahead of every other island. Over a
// fullscreen window it waits behind a pulsing hairline instead, and shows up there on hover. Answered right here: Approve types "1"/"y" into the session's terminal, Deny sends
// Escape. The mark breathes slowly so it reads as "waiting on you" without flashing.
Item {
    id: approval
    required property Item di
    anchors.fill: parent

    readonly property var session: ClaudeCode.approval
    readonly property string agent: approval.session?.agent ?? "claude"
    readonly property color accent: ClaudeCode.agentColor(approval.agent)

    property real breath: 0
    SequentialAnimation on breath {
        running: approval.session !== null
        loops: Animation.Infinite
        NumberAnimation { to: 1; duration: 1100; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0; duration: 1100; easing.type: Easing.InOutSine }
    }

    RowLayout {
        anchors {
            fill: parent
            leftMargin: 6
            rightMargin: 5
        }
        spacing: 8

        Item {
            implicitWidth: 28
            implicitHeight: 28

            Rectangle {
                anchors.centerIn: parent
                width: 28 + 4 * approval.breath
                height: width
                radius: width / 2
                color: ColorUtils.transparentize(approval.accent, 0.78 + 0.1 * approval.breath)
            }
            DiClaudeIcon {
                anchors.centerIn: parent
                agent: approval.agent
                size: 16
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: -3

            StyledText {
                Layout.fillWidth: true
                text: Translation.tr("%1 wants to run").arg(ClaudeCode.agentNames[approval.agent] ?? "Agent")
                    + ` · ${approval.session?.project ?? ""}`
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnLayer0
                elide: Text.ElideRight
            }
            StyledText {
                Layout.fillWidth: true
                text: approval.session?.permission ?? ""
                font.pixelSize: Appearance.font.pixelSize.smallest
                font.family: Appearance.font.family.monospace
                color: Appearance.colors.colOnLayer0
                opacity: 0.75
                elide: Text.ElideRight
            }
        }

        AnswerButton {
            icon: "close"
            label: Translation.tr("Deny")
            danger: true
            onTap: ClaudeCode.deny(approval.session.key)
        }
        AnswerButton {
            icon: "check"
            label: Translation.tr("Approve")
            primary: true
            onTap: ClaudeCode.approve(approval.session.key)
        }
    }

    component AnswerButton: Rectangle {
        id: button
        property string icon: ""
        property string label: ""
        property bool primary: false
        property bool danger: false
        signal tap()
        implicitWidth: buttonRow.implicitWidth + 16
        implicitHeight: 26
        radius: 13
        color: button.primary ? (buttonMouse.containsMouse ? Qt.lighter(IslandEvents.colorSuccess, 1.12) : IslandEvents.colorSuccess)
            : buttonMouse.containsMouse ? ColorUtils.transparentize(Appearance.colors.colError, 0.7) : Appearance.colors.colLayer2
        scale: buttonMouse.pressed ? 0.94 : 1

        Behavior on scale {
            NumberAnimation { duration: IslandMotion.micro; easing.type: Easing.OutCubic }
        }
        Behavior on color {
            ColorAnimation { duration: IslandMotion.micro }
        }

        RowLayout {
            id: buttonRow
            anchors.centerIn: parent
            spacing: 3
            MaterialSymbol {
                text: button.icon
                iconSize: 14
                fill: 1
                color: button.primary ? "#0b1f10" : (buttonMouse.containsMouse ? Appearance.colors.colError : Appearance.colors.colOnLayer2)
            }
            StyledText {
                text: button.label
                font.pixelSize: Appearance.font.pixelSize.smallest
                font.weight: Font.DemiBold
                color: button.primary ? "#0b1f10" : Appearance.colors.colOnLayer2
            }
        }

        MouseArea {
            id: buttonMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.tap()
        }
    }
}
