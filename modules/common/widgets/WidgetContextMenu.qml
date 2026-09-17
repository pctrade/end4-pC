import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/*
 * Context menu shown when a background widget is right-clicked.
 *
 * Reuses the standard menu card styling (StyledRectangularShadow +
 * RippleButton + MaterialSymbol rows) used by PresetPopup / DesktopMenu.
 * The host decides where it is placed and which actions to wire up.
 */
Item {
    id: root

    signal toFront()
    signal toBack()

    property string targetWidgetKey: ""
    property bool frontEnabled: false
    property bool backEnabled: false
    property bool locked: Config.options.background.widgetsLocked

    width: 212
    implicitHeight: card.implicitHeight

    Rectangle {
        id: card
        anchors.fill: parent
        implicitHeight: menuCol.implicitHeight + 16
        radius: Appearance.rounding.verylarge
        color: "transparent"

        StyledRectangularShadow { target: cardBg }

        Rectangle {
            id: cardBg
            anchors.fill: parent
            radius: card.radius
            color: Appearance.colors.colLayer0
            border.width: 1
            border.color: Appearance.colors.colLayer0Border
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        ColumnLayout {
            id: menuCol
            anchors { fill: parent; margins: 8 }
            spacing: 2

            RippleButton {
                Layout.fillWidth: true
                implicitHeight: 40
                buttonRadius: Appearance.rounding.small
                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colLayer2Hover
                colRipple: Appearance.colors.colLayer2Active
                onClicked: {
                    Config.options.background.widgetsLocked = !Config.options.background.widgetsLocked
                }
                contentItem: RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    spacing: 12
                    MaterialSymbol {
                        text: root.locked ? "lock_open" : "lock"
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colOnLayer0
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr(root.locked ? "Unlock" : "Lock")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer0
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 1
                Layout.leftMargin: 12
                Layout.rightMargin: 12
                color: Appearance.colors.colLayer0Border
            }

            RippleButton {
                Layout.fillWidth: true
                implicitHeight: 40
                enabled: root.frontEnabled
                buttonRadius: Appearance.rounding.small
                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colLayer2Hover
                colRipple: Appearance.colors.colLayer2Active
                onClicked: root.toFront()
                contentItem: RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    spacing: 12
                    MaterialSymbol {
                        text: "arrow_upward"
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colOnLayer0
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("To Front")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer0
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }

            RippleButton {
                Layout.fillWidth: true
                implicitHeight: 40
                enabled: root.backEnabled
                buttonRadius: Appearance.rounding.small
                colBackground: "transparent"
                colBackgroundHover: Appearance.colors.colLayer2Hover
                colRipple: Appearance.colors.colLayer2Active
                onClicked: root.toBack()
                contentItem: RowLayout {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    spacing: 12
                    MaterialSymbol {
                        text: "arrow_downward"
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colOnLayer0
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("To Back")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnLayer0
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
    }
}