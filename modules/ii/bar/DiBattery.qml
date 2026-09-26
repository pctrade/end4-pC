import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: batt
    required property Item di
    anchors.fill: parent

    readonly property bool hibernate: batt.di.primaryId === "hibernate"
    readonly property string kind: batt.di.batteryAlertKind
    readonly property bool critical: batt.hibernate || batt.kind === "critical"
    readonly property color accent: batt.critical ? Appearance.colors.colError : batt.di.batteryAlertColor()
    readonly property bool showSavers: batt.di.hoverRevealed && !batt.hibernate && ["low", "critical"].includes(batt.kind) && !Battery.isPluggedIn

    Rectangle {
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
        }
        width: Math.max(height, parent.width * (batt.hibernate ? Math.max(0, batt.di.hibernateSeconds) / 60 : Battery.percentage))
        radius: height / 2
        color: batt.accent
        opacity: batt.critical ? 0.28 : 0.18

        Behavior on width {
            NumberAnimation { duration: IslandMotion.long; easing.type: Easing.OutCubic }
        }

        SequentialAnimation on opacity {
            running: batt.kind === "critical" && !batt.hibernate
            loops: Animation.Infinite
            NumberAnimation { to: 0.42; duration: 900; easing.type: Easing.InOutSine }
            NumberAnimation { to: 0.2; duration: 900; easing.type: Easing.InOutSine }
        }
    }

    RowLayout {
        anchors {
            fill: parent
            leftMargin: 10
            rightMargin: 10
        }
        spacing: 7

        MaterialSymbol {
            text: batt.hibernate ? "bedtime" : batt.di.batteryIcon()
            iconSize: 18
            fill: 1
            color: batt.accent
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: -3

            StyledText {
                Layout.fillWidth: true
                text: batt.hibernate
                    ? `${Translation.tr("Hibernating in")} ${Math.max(0, batt.di.hibernateSeconds)}s`
                    : batt.di.batteryStatusText()
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.DemiBold
                font.features: { "tnum": 1 }
                color: batt.accent
                elide: Text.ElideRight
            }
            StyledText {
                Layout.fillWidth: true
                visible: text !== ""
                text: batt.hibernate ? Translation.tr("Plug in the charger or cancel")
                    : batt.kind === "critical" ? Translation.tr("Charge now")
                    : batt.kind === "charging" && Battery.energyRate > 0.5 ? Translation.tr("Charging at %1 W").arg(Math.round(Battery.energyRate)) : ""
                font.features: { "tnum": 1 }
                font.pixelSize: Appearance.font.pixelSize.smallest
                color: Appearance.colors.colOnLayer0
                opacity: 0.7
                elide: Text.ElideRight
            }
        }

        StyledText {
            visible: !batt.hibernate
            text: `${Math.round(Battery.percentage * 100)}%`
            font.pixelSize: Appearance.font.pixelSize.small
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
            color: batt.accent
        }

        DiSaverButtons {
            visible: batt.showSavers
            compact: true
        }

        Rectangle {
            visible: batt.hibernate
            implicitWidth: cancelText.implicitWidth + 16
            implicitHeight: 22
            radius: 11
            color: cancelMouse.containsMouse ? batt.accent : ColorUtils.transparentize(batt.accent, 0.75)

            StyledText {
                id: cancelText
                anchors.centerIn: parent
                text: Translation.tr("Cancel")
                font.pixelSize: Appearance.font.pixelSize.smallest
                font.weight: Font.DemiBold
                color: cancelMouse.containsMouse ? Appearance.colors.colOnError : Appearance.colors.colOnLayer0
            }

            MouseArea {
                id: cancelMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: batt.di.cancelHibernate()
            }
        }
    }
}
