import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

DialogListItem {
    id: root
    required property var profile
    property bool confirmingDelete: false

    readonly property bool isActive: Vpn.activeUuids.includes(profile.uuid)

    active: isActive
    enabled: !Vpn.busy
    onClicked: if (!confirmingDelete) Vpn.connectTo(profile.uuid)

    contentItem: RowLayout {
        anchors {
            fill: parent
            topMargin: root.verticalPadding
            bottomMargin: root.verticalPadding
            leftMargin: root.horizontalPadding
            rightMargin: root.horizontalPadding
        }
        spacing: 10

        MaterialSymbol {
            text: root.isActive ? "vpn_lock" : "vpn_key"
            iconSize: Appearance.font.pixelSize.larger
            color: root.isActive ? Appearance.colors.colPrimary : Appearance.colors.colOnSurfaceVariant
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                text: root.profile.name
                elide: Text.ElideRight
                textFormat: Text.PlainText
                color: Appearance.colors.colOnSurfaceVariant
            }
            StyledText {
                text: (root.profile.type === "wireguard" ? "WireGuard" : "OpenVPN") + (root.isActive ? " • " + Translation.tr("Connected") : "")
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }
        }

        MaterialSymbol {
            visible: root.isActive && !root.confirmingDelete
            text: "check"
            iconSize: Appearance.font.pixelSize.larger
            color: Appearance.colors.colOnSurfaceVariant
        }

        DialogButton {
            visible: root.confirmingDelete
            buttonText: Translation.tr("Delete?")
            colText: Appearance.m3colors.m3error
            onClicked: {
                root.confirmingDelete = false;
                const uuid = root.profile.uuid;
                Qt.callLater(() => Vpn.remove(uuid));
            }
        }
        DialogButton {
            visible: root.confirmingDelete
            buttonText: Translation.tr("Cancel")
            onClicked: root.confirmingDelete = false
        }
        RippleButton {
            visible: !root.confirmingDelete
            implicitWidth: 32
            implicitHeight: 32
            buttonRadius: 16
            colBackground: "transparent"
            onClicked: root.confirmingDelete = true
            contentItem: Item {
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "delete"
                    iconSize: 18
                    color: Appearance.colors.colSubtext
                }
            }
        }
    }
}
