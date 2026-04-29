import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

StyledPopup {
    id: root

    function formatTime(seconds) {
        var h = Math.floor(seconds / 3600)
        var m = Math.floor((seconds % 3600) / 60)
        if (h > 0) return `${h}h, ${m}m`
        return `${m}m`
    }

    readonly property bool showTime: !(Battery.chargeState == 4
        || (Battery.isCharging ? Battery.timeToFull : Battery.timeToEmpty) <= 0
        || Battery.energyRate <= 0.01)

    ColumnLayout {
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 3
            spacing: 7

            MaterialShapeWrappedMaterialSymbol {
                shape: MaterialShape.Shape.ClamShell
                text: "battery_android_full"
                iconSize: Appearance.font.pixelSize.large
                implicitSize: 36
                color: Appearance.colors.colPrimaryContainer
                colSymbol: Appearance.colors.colPrimary
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: -3

                StyledText {
                    text: Translation.tr("Battery")
                    font {
                        weight: Font.Medium
                        pixelSize: Appearance.font.pixelSize.normal
                    }
                    color: Appearance.colors.colOnSurfaceVariant
                }

                StyledText {
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnSurfaceVariant
                    opacity: 0.6
                    text: {
                        if (Battery.chargeState == 4)
                            return Translation.tr("Fully charged")
                        if (Battery.isCharging)
                            return Translation.tr("Charging") + (root.showTime ? " · " + formatTime(Battery.timeToFull) : "")
                        return Translation.tr("Time to empty") + (root.showTime ? " · " + formatTime(Battery.timeToEmpty) : "")
                    }
                }
            }

            Item { Layout.fillWidth: true }

            StyledText {
                Layout.rightMargin: 8
                font.pixelSize: Appearance.font.pixelSize.huge
                font.weight: Font.Bold
                color: Appearance.colors.colPrimary
                text: `${Math.round(Battery.percentage * 100)}`
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            ResourceCard {
                label: Translation.tr("Health")
                iconText: "heart_check"
                iconShape: MaterialShape.Shape.Clover4Leaf
                value: Battery.health / 100
                sublabel: Battery.chargeCycles > 0
                    ? `${Battery.chargeCycles} ${Translation.tr("cycles")}`
                    : Translation.tr("N/A")
                sublabelColor: Appearance.colors.colOnSurfaceVariant
                cardWidth: 160
            }

            ResourceCard {
                label: Battery.isCharging
                    ? Translation.tr("Charging")
                    : Translation.tr("Draw")
                iconText: "bolt"
                iconShape: MaterialShape.Shape.Pentagon
                value: Math.min(Battery.energyRate / 60, 1.0)
                sublabel: Battery.chargeState == 4
                    ? Translation.tr("Full")
                    : `${Battery.energyRate.toFixed(2)}W`
                sublabelColor: Appearance.colors.colOnSurfaceVariant
                cardWidth: 160
            }
        }
    }
}
