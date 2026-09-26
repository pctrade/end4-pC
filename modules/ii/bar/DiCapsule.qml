import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

RowLayout {
    id: capsule
    required property Item di
    required property string providerId
    property bool showLabel: true
    property color textColor: Appearance.colors.colOnLayer1
    spacing: 4

    readonly property var activity: IslandEvents.latestActivity

    readonly property string icon: {
        switch (capsule.providerId) {
            case "recording":     return "fiber_manual_record"
            case "f1":
            case "f1Flag":
            case "f1Start":       return "sports_motorsports"
            case "timer":         return capsule.di.timerIcon()
            case "activity":      return capsule.activity?.icon ?? "bolt"
            case "systemLoad":    return "memory"
            case "songRec":
            case "songRecResult": return "graphic_eq"
            case "notification":  return "notifications"
            case "osd":           return GlobalStates.osdIndicatorType === "brightness" ? "light_mode" : "volume_up"
            case "battery":       return capsule.di.batteryIcon()
            case "bluetooth":     return "bluetooth"
            case "audioOutput":   return IslandEvents.audioOutput.payload?.icon ?? "speaker"
            case "screenshot":    return "screenshot_monitor"
            case "clipboard":     return "content_paste"
            case "weather":       return "rainy"
            case "privacy":       return "privacy_tip"
            case "shelf":         return "inventory_2"
            case "shelfDrop":     return "move_to_inbox"
            case "hardware":      return IslandHardware.payload.icon ?? "memory"
            case "session":       return "power_settings_new"
            case "idle":          return "home"
            case "media":         return "music_note"
            case "download":      return "download"
            case "networkAlert":  return "wifi"
            case "agents":        return ClaudeCode.openAgents[0] ?? "bolt"
            case "zerotier":      return "vpn_lock"
            case "history":       return "history"
            case "watchRating":   return "movie"
            default:              return "stacks"
        }
    }

    readonly property string label: {
        switch (capsule.providerId) {
            case "recording":     return capsule.di.formatRecordingTime(capsule.di.recordingElapsedSeconds)
            case "f1":
                if (!F1.sessionLive) return F1.formatCountdown(F1.secondsToNext)
                return F1.totalLaps > 0 ? `L${F1.lap}` : (F1.focusDriver?.tla ?? "F1")
            case "f1Flag":        return F1.flagLabel(F1.flag)
            case "timer":         return capsule.di.timerValueText()
            case "systemLoad":    return `${Math.round(ResourceUsage.cpuUsage * 100)}%`
            case "activity":      return capsule.activity?.title ?? ""
            case "media":         return capsule.di.activePlayer?.trackTitle ?? ""
            case "notification":  return IslandEvents.notificationParts(capsule.di.latestNotification).app || Translation.tr("Notification")
            case "osd":           return `${Math.round(Audio.value * 100)}%`
            case "battery":       return `${Math.round(Battery.percentage * 100)}%`
            case "bluetooth":     return IslandEvents.bluetooth.payload?.name ?? ""
            case "audioOutput":   return IslandEvents.audioOutput.payload?.name ?? ""
            case "screenshot":    return Translation.tr("Screenshots")
            case "clipboard":     return Translation.tr("Copied")
            case "songRec":       return Translation.tr("Listening…")
            case "songRecResult": return IslandEvents.songRecResult.payload?.title ?? ""
            case "weather":       return IslandEvents.weather.payload?.temp ?? ""
            case "privacy":       return Translation.tr("Privacy")
            case "shelf":         return `${DropShelf.items.length}`
            case "shelfDrop":     return Translation.tr("Drop to keep")
            case "hardware":      return IslandHardware.payload.title ?? ""
            case "download":      return IslandEvents.downloadFileName !== "" ? IslandEvents.downloadFileName
                : IslandEvents.formatBytes(IslandEvents.downloadRate, true)
            case "agents": {
                const limit = ClaudeCode.openAgents[0] ? ClaudeCode.limits[ClaudeCode.openAgents[0]] : null
                return limit ? `${Math.round(limit.five)}%` : Translation.tr("AI agents")
            }
            case "zerotier":      return IslandEvents.ztUp ? Translation.tr("On") : Translation.tr("Off")
            case "history":       return IslandEvents.eventLog[0]?.title ?? ""
            case "idle":          return DateTime.time
            case "watchRating": {
                const r = (WatchRating.now?.season ?? 0) > 0 ? WatchRating.episodeRating : WatchRating.seriesRating
                return r >= 0 ? `★ ${r.toFixed(1)}` : ""
            }
            default:              return ""
        }
    }

    property bool hovered: false
    readonly property bool compactLabel: ["recording", "f1", "timer", "systemLoad", "shelf"].includes(capsule.providerId)
    readonly property bool labelVisible: (capsule.showLabel && capsule.compactLabel) || capsule.hovered

    readonly property string shortLabel: {
        const head = capsule.label.split(" · ")[0].trim()
        return head.length > 16 ? `${head.slice(0, 15)}…` : head
    }

    readonly property color accent: {
        switch (capsule.providerId) {
            case "recording":    return Appearance.colors.colError
            case "f1":
            case "f1Flag":       return F1.sessionLive ? F1.flagColor(F1.flag) : Appearance.colors.colPrimary
            case "activity":     return capsule.activity?.state === "error" ? Appearance.colors.colError : Appearance.colors.colPrimary
            case "notification": return IslandEvents.appColor(IslandEvents.notificationParts(capsule.di.latestNotification).app, Appearance.colors.colPrimary)
            case "battery":      return capsule.di.batteryAlertColor()
            case "privacy":      return IslandEvents.micInUse ? IslandEvents.colorAttention : "#30D158"
            default:             return capsule.textColor
        }
    }

    readonly property real ringValue: {
        switch (capsule.providerId) {
            case "timer":    return capsule.di.timerProgress()
            case "activity": return capsule.activity?.progress ?? -1
            default:         return -1
        }
    }

    Item {
        Layout.leftMargin: 4
        Layout.rightMargin: capsule.labelVisible ? 0 : 4
        implicitWidth: 24
        implicitHeight: 24

        CircularProgress {
            anchors.fill: parent
            visible: capsule.ringValue >= 0
            implicitSize: 24
            lineWidth: 2
            value: Math.max(0, capsule.ringValue)
            colPrimary: capsule.accent
            colSecondary: ColorUtils.transparentize(capsule.accent, 0.75)
        }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            clip: true
            color: Appearance.colors.colLayer2
            visible: capsule.providerId === "media" && (capsule.di.activePlayer?.trackArtUrl ?? "") !== ""

            StyledImage {
                anchors.fill: parent
                fillMode: Image.PreserveAspectCrop
                source: capsule.di.activePlayer?.trackArtUrl ?? ""
                sourceSize.width: 48
                sourceSize.height: 48
            }

        }

        readonly property bool agentIcon: (capsule.providerId === "activity" || capsule.providerId === "agents")
            && ["claude", "codex", "gemini"].includes(capsule.providerId === "agents" ? (ClaudeCode.openAgents[0] ?? "") : (capsule.activity?.icon ?? ""))

        DiClaudeIcon {
            anchors.centerIn: parent
            visible: parent.agentIcon
            agent: capsule.providerId === "agents" ? (ClaudeCode.openAgents[0] ?? "claude") : (capsule.activity?.icon ?? "claude")
            size: capsule.ringValue >= 0 ? 12 : 15
        }

        MaterialSymbol {
            anchors.centerIn: parent
            visible: !(capsule.providerId === "media" && (capsule.di.activePlayer?.trackArtUrl ?? "") !== "")
                && !parent.agentIcon
            text: capsule.icon
            iconSize: capsule.ringValue >= 0 ? 13 : 17
            fill: 1
            color: capsule.accent

        }
    }

    StyledText {
        Layout.rightMargin: 9
        Layout.maximumWidth: capsule.di.hoverRevealed ? 150 : 110
        visible: capsule.labelVisible
        text: capsule.di.hoverRevealed ? capsule.label : capsule.shortLabel
        font.pixelSize: Appearance.font.pixelSize.smaller
        font.weight: Font.DemiBold
        font.features: { "tnum": 1 }
        color: capsule.textColor
        elide: Text.ElideRight
    }
}
