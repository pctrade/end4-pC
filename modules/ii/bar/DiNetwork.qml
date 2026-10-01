import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// Connection alerts (lost / joined a network, ZeroTier during a call) and, otherwise, a running download
RowLayout {
    id: net
    required property Item di
    anchors {
        fill: parent
        leftMargin: 6
        rightMargin: 12
    }
    spacing: 8

    readonly property bool alert: net.di.primaryId === "networkAlert"
    readonly property var payload: IslandEvents.networkAlert.payload ?? ({})
    readonly property string kind: net.payload.kind ?? ""
    readonly property bool lost: net.alert && (net.kind === "lost" || net.kind === "ztFailed")
    readonly property bool zerotier: net.alert && ["zerotier", "ztOff", "ztRestore", "ztFailed"].includes(net.kind)
    readonly property bool actionable: net.alert && (net.kind === "zerotier" || net.kind === "ztRestore" || net.kind === "portal")
    readonly property color accent: net.lost ? Appearance.colors.colError
        : (net.kind === "zerotier" || net.kind === "weak" || net.kind === "portal") ? IslandEvents.colorAttention : Appearance.colors.colPrimary

    readonly property string alertTitle: {
        switch (net.kind) {
            case "zerotier":  return Translation.tr("ZeroTier is on during a call")
            case "ztOff":     return Translation.tr("ZeroTier turned off")
            case "ztRestore": return Translation.tr("Call ended")
            case "ztFailed":  return Translation.tr("Couldn't change ZeroTier")
            case "portal":    return Translation.tr("This network wants a login")
            case "lost":      return Translation.tr("Connection lost")
            case "weak":      return Translation.tr("Weak Wi-Fi signal · %1%").arg(net.payload.strength ?? "?")
            default:          return Translation.tr("Connected")
        }
    }
    readonly property string alertSubtitle: {
        switch (net.kind) {
            case "zerotier":  return Translation.tr("It can break the voice · tap to turn off")
            case "ztOff":     return Translation.tr("Voice should connect normally")
            case "ztRestore": return Translation.tr("Tap to turn ZeroTier back on")
            case "ztFailed":  return Translation.tr("Needs passwordless sudo")
            case "portal":    return Translation.tr("%1 · tap to open the page").arg(net.payload.name ?? "")
            case "weak":      return [net.payload.name, net.payload.rate, IslandEvents.downloadActive ? `↓ ${IslandEvents.formatBytes(IslandEvents.downloadRate, true)}` : ""].filter(Boolean).join(" · ")
            default:          return net.payload.name ?? ""
        }
    }

    TapHandler {
        enabled: net.actionable
        onTapped: {
            if (net.kind === "portal") {
                IslandEvents.openCaptivePortal(net.payload.url ?? "")
                return
            }
            IslandEvents.setZeroTier(net.kind === "ztRestore")
            IslandEvents.networkAlert.dismiss()
        }
    }
    HoverHandler {
        enabled: net.actionable
        cursorShape: Qt.PointingHandCursor
    }

    Item {
        implicitWidth: 24
        implicitHeight: 24
        clip: true

        MaterialShapeWrappedMaterialSymbol {
            anchors.centerIn: parent
            visible: net.alert
            wrappedShape: net.lost || net.kind === "zerotier" ? MaterialShape.Shape.Cookie4Sided : MaterialShape.Shape.Cookie9Sided
            color: ColorUtils.transparentize(net.accent, 0.75)
            colSymbol: net.accent
            text: net.kind === "portal" ? "captive_portal"
                : net.kind === "weak" ? "network_wifi_1_bar"
                : net.zerotier ? (net.kind === "ztOff" ? "vpn_key_off" : "vpn_lock")
                : net.lost ? "wifi_off" : (net.payload.name === "Ethernet" ? "lan" : "wifi")
            iconSize: 14
            fill: 1
            padding: 4
        }

        CircularProgress {
            anchors.fill: parent
            visible: !net.alert && IslandEvents.downloadFileProgress >= 0
            implicitSize: 24
            lineWidth: 2
            value: Math.max(0, IslandEvents.downloadFileProgress)
            colPrimary: Appearance.colors.colPrimary
            colSecondary: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.8)
        }

        MaterialSymbol {
            anchors.centerIn: parent
            visible: !net.alert && IslandEvents.downloadFileProgress >= 0
            text: "download"
            iconSize: 12
            fill: 1
            color: Appearance.colors.colPrimary
        }

        Repeater {
            model: net.alert || IslandEvents.downloadFileProgress >= 0 ? 0 : 2
            delegate: MaterialSymbol {
                id: arrow
                required property int index
                anchors.horizontalCenter: parent.horizontalCenter
                y: -18
                text: "arrow_downward"
                iconSize: 16
                color: Appearance.colors.colPrimary
                opacity: arrow.y > 14 ? 0.15 : 1

                Timer {
                    interval: 70
                    repeat: true
                    running: arrow.visible
                    triggeredOnStart: true
                    onTriggered: {
                        const step = 3.5
                        arrow.y = arrow.y > 24 ? -18 - arrow.index * 12 : arrow.y + step
                    }
                }
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: -3

        StyledText {
            Layout.fillWidth: true
            text: net.alert ? net.alertTitle
                : (IslandEvents.downloadFileName !== "" ? IslandEvents.downloadFileName
                    : `${Translation.tr("Downloading")} · ${IslandEvents.formatBytes(IslandEvents.downloadRate, true)}`)
            font.pixelSize: Appearance.font.pixelSize.smaller
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
            color: net.lost ? Appearance.colors.colError : Appearance.colors.colOnLayer0
            elide: Text.ElideRight
        }
        StyledText {
            Layout.fillWidth: true
            text: {
                if (net.alert) return net.alertSubtitle
                const file = IslandEvents.downloadFile
                if (!file) return `${IslandEvents.formatBytes(IslandEvents.burstBytes, false)} · ${IslandEvents.downloadTop ? IslandEvents.sourceLabel(IslandEvents.downloadTop) : Translation.tr("Identifying…")}`
                const parts = [IslandEvents.formatBytes(file.rate, true)]
                parts.push(file.total > 0
                    ? `${IslandEvents.formatBytes(file.bytes, false)} / ${IslandEvents.formatBytes(file.total, false)}`
                    : IslandEvents.formatBytes(file.bytes, false))
                if (file.total > 0 && file.rate > 1024) parts.push(IslandEvents.remainingTime((file.total - file.bytes) / file.rate))
                if (IslandEvents.partialFiles.length > 1) parts.push(Translation.tr("+%1").arg(IslandEvents.partialFiles.length - 1))
                return parts.join(" · ")
            }
            font.pixelSize: Appearance.font.pixelSize.smallest
            font.features: { "tnum": 1 }
            color: Appearance.colors.colOnLayer0
            opacity: 0.7
            elide: Text.ElideRight
        }
    }
}
