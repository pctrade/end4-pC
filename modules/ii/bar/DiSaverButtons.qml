import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// Battery savers as toggles (PowerSaver): power profile, dim screen, light effects, Bluetooth off.
// `compact` is the pill's row of round buttons; otherwise labelled chips for the expanded view.
Flow {
    id: saver
    property bool compact: false
    spacing: saver.compact ? 4 : 6

    readonly property var items: [
        { key: "profile", icon: "eco", label: Translation.tr("Power saver"), on: PowerSaver.profileOn, run: () => PowerSaver.toggleProfile() },
        { key: "dim", icon: "brightness_low", label: Translation.tr("Dim screen"), on: PowerSaver.dimOn, run: () => PowerSaver.toggleDim() },
        { key: "effects", icon: "animation", label: Translation.tr("Light effects"), on: PowerSaver.effectsOn, run: () => PowerSaver.toggleEffects() },
        { key: "bluetooth", icon: "bluetooth_disabled", label: Translation.tr("Bluetooth off"), on: PowerSaver.bluetoothOn, run: () => PowerSaver.toggleBluetooth(),
          hidden: !PowerSaver.bluetoothOffered }
    ].filter(item => !item.hidden && (!saver.compact || item.key !== "bluetooth"))

    Repeater {
        model: saver.items

        delegate: Rectangle {
            id: toggle
            required property var modelData
            required property int index
            implicitWidth: saver.compact ? 26 : toggleRow.implicitWidth + 20
            implicitHeight: saver.compact ? 26 : 30
            radius: height / 2
            color: toggle.modelData.on ? IslandEvents.colorSuccess
                : toggleMouse.containsMouse ? Appearance.colors.colLayer2Hover : Appearance.colors.colLayer2

            Behavior on color {
                ColorAnimation { duration: IslandMotion.micro }
            }

            property real shift: saver.visible ? 0 : 6 + toggle.index * 5
            transform: Translate { x: toggle.shift }
            Behavior on shift {
                NumberAnimation { duration: 220 + toggle.index * 70; easing.type: Easing.OutCubic }
            }

            RowLayout {
                id: toggleRow
                anchors.centerIn: parent
                spacing: 5

                MaterialSymbol {
                    text: toggle.modelData.icon
                    iconSize: 15
                    fill: toggle.modelData.on ? 1 : 0
                    color: toggle.modelData.on ? "#0b1f10" : Appearance.colors.colOnLayer2
                }
                StyledText {
                    visible: !saver.compact
                    text: toggle.modelData.label
                    font.pixelSize: Appearance.font.pixelSize.smallest
                    font.weight: Font.DemiBold
                    color: toggle.modelData.on ? "#0b1f10" : Appearance.colors.colOnLayer2
                }
            }

            MouseArea {
                id: toggleMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: toggle.modelData.run()
            }

            StyledToolTip {
                extraVisibleCondition: saver.compact && toggleMouse.containsMouse
                text: toggle.modelData.label
            }
        }
    }
}
