import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets
import qs.services

StyledPopup {
    id: root

    property real downloadSpeed: 0
    property real uploadSpeed: 0
    property real downloadedBytes: 0
    property real uploadedBytes: 0

    readonly property bool wifiConnected: Network.wifiStatus === "connected"
    readonly property string connectionName: {
        if (Network.ethernet)
            return Network.networkName || Translation.tr("Ethernet")
        if (wifiConnected)
            return Network.active?.ssid || Network.networkName || Translation.tr("Wi-Fi")
        return Translation.tr("Not connected")
    }
    readonly property string connectionDetails: {
        if (Network.ethernet)
            return Translation.tr("Ethernet · Connected")
        if (wifiConnected) {
            const strength = Network.networkStrength > 0
                ? ` · ${Network.networkStrength}%`
                : ""
            return `${Translation.tr("Wi-Fi")}${strength}`
        }
        switch (Network.wifiStatus) {
        case "connecting": return Translation.tr("Connecting")
        case "limited": return Translation.tr("Limited connection")
        case "disabled": return Translation.tr("Wi-Fi disabled")
        default: return Translation.tr("Disconnected")
        }
    }

    function formatRate(rate) {
        return formatBytes(rate, "/s")
    }

    function formatTotal(bytes) {
        return formatBytes(bytes, "")
    }

    function formatBytes(bytes, suffix) {
        const units = ["B", "KB", "MB", "GB", "TB"]
        let value = Math.max(0, Number(bytes) || 0)
        let unitIndex = 0

        while (value >= 1024 && unitIndex < units.length - 1) {
            value /= 1024
            unitIndex++
        }

        const precision = unitIndex > 0 && value < 100 ? 1 : 0
        return `${value.toFixed(precision)} ${units[unitIndex]}${suffix}`
    }

    component SpeedCard: Rectangle {
        id: card

        required property string label
        required property string iconName
        required property real speed
        required property real total
        required property color accentColor

        Layout.fillWidth: true
        implicitWidth: 145
        implicitHeight: cardContent.implicitHeight + 20
        radius: Appearance.rounding.small
        color: Appearance.colors.colSurfaceContainerLow

        ColumnLayout {
            id: cardContent
            anchors {
                fill: parent
                margins: 10
            }
            spacing: 1

            RowLayout {
                Layout.fillWidth: true
                spacing: 4

                MaterialSymbol {
                    text: card.iconName
                    iconSize: Appearance.font.pixelSize.normal
                    color: card.accentColor
                }

                StyledText {
                    text: card.label
                    color: Appearance.colors.colOnSurfaceVariant
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.Medium
                }

                Item { Layout.fillWidth: true }
            }

            StyledText {
                text: root.formatRate(card.speed)
                color: Appearance.colors.colOnSurfaceVariant
                font.pixelSize: Appearance.font.pixelSize.large
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
            }

            StyledText {
                text: `${root.formatTotal(card.total)} ${Translation.tr("this session")}`
                color: Appearance.colors.colOnSurfaceVariant
                opacity: 0.6
                font.pixelSize: Appearance.font.pixelSize.smallest
            }
        }
    }

    ColumnLayout {
        implicitWidth: 300
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 3
            Layout.rightMargin: 5
            spacing: 7

            MaterialShapeWrappedMaterialSymbol {
                shape: MaterialShape.Shape.Circle
                text: Network.materialSymbol
                iconSize: Appearance.font.pixelSize.large
                implicitSize: 36
                color: Appearance.colors.colPrimaryContainer
                colSymbol: Appearance.colors.colPrimary
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: -3

                StyledText {
                    text: root.connectionName
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.Medium
                    color: Appearance.colors.colOnSurfaceVariant
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                }

                StyledText {
                    text: root.connectionDetails
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnSurfaceVariant
                    opacity: 0.6
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            SpeedCard {
                label: Translation.tr("Upload")
                iconName: "arrow_upward"
                speed: root.uploadSpeed
                total: root.uploadedBytes
                accentColor: Appearance.colors.colTertiary
            }

            SpeedCard {
                label: Translation.tr("Download")
                iconName: "arrow_downward"
                speed: root.downloadSpeed
                total: root.downloadedBytes
                accentColor: Appearance.colors.colPrimary
            }
        }

        GroupedList {
            visible: Network.networkInterface !== ""
                || Network.ipAddress !== ""
                || Network.publicIpAddress !== ""
                || Network.gateway !== ""
                || Network.macAddress !== ""

            Layout.fillWidth: true
            bgcolor: Appearance.colors.colSurfaceContainerLow

            StyledPopupValueRow {
                Layout.fillWidth: true
                visible: Network.networkInterface !== ""
                icon: "settings_ethernet"
                label: Translation.tr("Interface")
                value: Network.networkInterface
            }

            StyledPopupValueRow {
                Layout.fillWidth: true
                visible: Network.ipAddress !== ""
                icon: "lan"
                label: Translation.tr("Local IP")
                value: Network.ipAddress
            }

            StyledPopupValueRow {
                Layout.fillWidth: true
                visible: Network.publicIpAddress !== ""
                icon: "public"
                label: Translation.tr("Public IP")
                value: Network.publicIpAddress
            }

            StyledPopupValueRow {
                Layout.fillWidth: true
                visible: Network.gateway !== ""
                icon: "router"
                label: Translation.tr("Gateway")
                value: Network.gateway
            }

            StyledPopupValueRow {
                Layout.fillWidth: true
                visible: Network.macAddress !== ""
                icon: "fingerprint"
                label: Translation.tr("MAC address")
                value: Network.macAddress
            }
        }
    }
}
