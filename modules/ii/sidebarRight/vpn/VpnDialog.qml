import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell

WindowDialog {
    id: root
    backgroundHeight: Vpn.profiles.length === 0 ? 330 : 480

    WindowDialogTitle {
        text: Translation.tr("VPN")
    }
    WindowDialogSeparator {
        visible: !Vpn.busy
    }
    StyledIndeterminateProgressBar {
        visible: Vpn.busy
        Layout.fillWidth: true
        Layout.topMargin: -8
        Layout.bottomMargin: -8
        Layout.leftMargin: -Appearance.rounding.large
        Layout.rightMargin: -Appearance.rounding.large
    }

    ColumnLayout {
        visible: Vpn.profiles.length === 0
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 8

        Item { Layout.fillHeight: true }

        MaterialSymbol {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: "vpn_key_off"
            iconSize: 48
            color: Appearance.colors.colSubtext
        }
        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: Translation.tr("No VPN profiles yet")
            color: Appearance.colors.colOnSurfaceVariant
        }
        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: Translation.tr("Import a WireGuard or OpenVPN file")
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
        }

        Item { Layout.fillHeight: true }
    }

    ListView {
        visible: Vpn.profiles.length > 0
        Layout.fillHeight: true
        Layout.fillWidth: true
        Layout.topMargin: -15
        Layout.bottomMargin: -16
        Layout.leftMargin: -Appearance.rounding.large
        Layout.rightMargin: -Appearance.rounding.large

        clip: true
        spacing: 0

        model: ScriptModel {
            values: Vpn.profiles
        }
        delegate: VpnProfileItem {
            required property var modelData
            profile: modelData
            width: ListView.view.width
        }
    }

    WindowDialogSeparator {}
    WindowDialogButtonRow {
        DialogButton {
            buttonText: Translation.tr("Import")
            onClicked: Vpn.pickAndImport()
        }

        Item {
            Layout.fillWidth: true
        }

        DialogButton {
            buttonText: Translation.tr("Done")
            onClicked: root.dismiss()
        }
    }
}
