import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: osd
    required property Item di
    anchors.fill: parent

    readonly property var focusedScreen: WM.compositor === "hyprland"
        ? Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name)
        : Quickshell.screens.find(s => s.name === WM.focusedMonitor?.name)
    readonly property var brightnessMonitor: Brightness.getMonitorForScreen(focusedScreen)

    readonly property string kind: GlobalStates.osdIndicatorType
    readonly property bool muted: osd.kind === "volume" && (Audio.sink?.audio?.muted ?? false)
    readonly property real value: {
        switch (osd.kind) {
            case "brightness": return IslandEvents.realBrightness >= 0 ? IslandEvents.realBrightness : (osd.brightnessMonitor?.brightness ?? 0)
            case "gamma":      return (Hyprsunset.gamma ?? 50) / 100
            default:           return Audio.sink?.audio?.volume ?? 0
        }
    }
    readonly property real maxValue: osd.kind === "volume" ? (osd.di.cfg.volumeMax ?? 1.5) : 1
    readonly property real clamped: Math.max(0, Math.min(osd.maxValue, osd.value))
    readonly property bool boosted: osd.kind === "volume" && !osd.muted && osd.shown > 1.005
    readonly property color boostColor: IslandEvents.colorAttention

    property bool dragging: false
    property real dragValue: 0
    readonly property real sliderMax: osd.kind === "volume" ? 1 : osd.maxValue
    DiSpring {
        id: shownSpring
        target: osd.dragging ? osd.dragValue : osd.clamped
        stiffness: osd.dragging ? 900 : 420
        dampingRatio: 0.9
        epsilon: 0.001
    }
    readonly property real shown: shownSpring.value
    DiSpring {
        id: pressSpring
        target: osd.dragging ? 1 : 0
        stiffness: 500
        dampingRatio: 0.7
        epsilon: 0.002
    }

    function setLevel(v) {
        if (osd.kind === "brightness") {
            osd.pendingBrightness = v
            if (!applyBrightness.running) applyBrightness.start()
        } else if (osd.kind === "volume" && Audio.sink?.audio) {
            Audio.sink.audio.muted = false
            Audio.sink.audio.volume = Math.round(v * 100) / 100
        }
    }
    // Brightness goes through ddcutil/brightnessctl: apply at most every 60 ms while dragging
    property real pendingBrightness: -1
    Timer {
        id: applyBrightness
        interval: 60
        onTriggered: {
            if (osd.pendingBrightness >= 0) osd.brightnessMonitor?.setBrightness(osd.pendingBrightness)
            osd.pendingBrightness = -1
        }
    }

    Rectangle {
        id: fill
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
        }
        width: Math.max(height, parent.width * Math.max(0, Math.min(1, osd.shown)))
        radius: height / 2
        color: ColorUtils.transparentize(Appearance.colors.colPrimary, osd.muted ? 0.92 : (0.7 - 0.15 * pressSpring.value))

        Behavior on color {
            ColorAnimation { duration: IslandMotion.short }
        }

        Rectangle {
            anchors {
                right: parent.right
                rightMargin: 6
                verticalCenter: parent.verticalCenter
            }
            width: 3 + 2 * pressSpring.value
            height: parent.height * (0.5 + 0.25 * pressSpring.value)
            radius: width / 2
            color: Appearance.colors.colPrimary
            opacity: osd.muted || osd.boosted ? 0 : 0.8 + 0.2 * pressSpring.value
        }
    }

    Rectangle {
        id: boostFill
        anchors {
            left: parent.left
            top: parent.top
            bottom: parent.bottom
        }
        visible: osd.boosted
        width: Math.max(height, parent.width * Math.max(0, Math.min(1, (osd.shown - 1) / (osd.maxValue - 1))))
        radius: height / 2
        color: ColorUtils.transparentize(osd.boostColor, 0.45)

        Rectangle {
            anchors {
                right: parent.right
                rightMargin: 6
                verticalCenter: parent.verticalCenter
            }
            width: 3
            height: parent.height * 0.5
            radius: 1.5
            color: osd.boostColor
        }
    }

    function nudge(step) {
        if (osd.kind === "brightness") {
            osd.brightnessMonitor?.setBrightness(Math.max(0, Math.min(1, osd.clamped + step)))
        } else if (Audio.sink?.audio) {
            Audio.sink.audio.muted = false
            Audio.sink.audio.volume = Math.max(0, Math.min(osd.maxValue, Math.round((osd.clamped + step) * 100) / 100))
        }
    }

    MouseArea {
        id: zones
        anchors.fill: parent
        hoverEnabled: true
        preventStealing: true
        cursorShape: osd.dragging ? Qt.SizeHorCursor : Qt.PointingHandCursor
        enabled: osd.kind !== "gamma"
        property real pressX: 0

        function levelAt(x) {
            return Math.max(0, Math.min(osd.sliderMax, x / width * osd.sliderMax))
        }
        onPressed: mouse => {
            zones.pressX = mouse.x
            osd.di.childTapAt = Date.now()
        }
        onPositionChanged: mouse => {
            if (!pressed) return
            if (!osd.dragging && Math.abs(mouse.x - zones.pressX) < 5) return
            osd.dragging = true
            osd.dragValue = zones.levelAt(mouse.x)
            osd.setLevel(osd.dragValue)
        }
        onReleased: mouse => {
            osd.di.childTapAt = Date.now()
            if (osd.dragging) {
                osd.dragValue = zones.levelAt(mouse.x)
                osd.setLevel(osd.dragValue)
                osd.dragging = false
                return
            }
            if (mouse.x < width * 0.38) osd.nudge(-0.05)
            else if (mouse.x > width * 0.62) osd.nudge(0.05)
            else osd.di.toggleExpanded()
        }
        onCanceled: osd.dragging = false
    }

    MaterialSymbol {
        anchors {
            left: parent.left
            leftMargin: 34
            verticalCenter: parent.verticalCenter
        }
        text: "remove"
        iconSize: 14
        color: Appearance.colors.colOnLayer0
        opacity: osd.dragging ? 0 : (zones.containsMouse && zones.mouseX < zones.width * 0.38 ? 0.9 : (zones.containsMouse ? 0.3 : 0))

        Behavior on opacity {
            NumberAnimation { duration: IslandMotion.micro }
        }
    }

    MaterialSymbol {
        anchors {
            right: parent.right
            rightMargin: 44
            verticalCenter: parent.verticalCenter
        }
        text: "add"
        iconSize: 14
        color: Appearance.colors.colOnLayer0
        opacity: osd.dragging ? 0 : (zones.containsMouse && zones.mouseX > zones.width * 0.62 ? 0.9 : (zones.containsMouse ? 0.3 : 0))

        Behavior on opacity {
            NumberAnimation { duration: IslandMotion.micro }
        }
    }

    RowLayout {
        anchors {
            fill: parent
            leftMargin: osd.di.isMaterial ? 0 : 4
            rightMargin: 12
        }
        spacing: 6

        MaterialShapeWrappedMaterialSymbol {
            id: osdIcon

            MouseArea {
                anchors.fill: parent
                anchors.margins: -3
                enabled: osd.kind !== "brightness" && osd.kind !== "gamma"
                cursorShape: Qt.PointingHandCursor
                onClicked: Audio.toggleMute()
            }
            wrappedShape: osd.muted ? MaterialShape.Shape.Cookie4Sided : MaterialShape.Shape.Cookie12Sided
            color: osd.muted ? Appearance.colors.colLayer2 : (osd.boosted ? osd.boostColor : Appearance.colors.colPrimary)
            colSymbol: osd.muted ? Appearance.colors.colOnLayer1 : Appearance.colors.colOnPrimary
            iconSize: osd.di.isMaterial ? 20 : 16
            fill: 1
            padding: 4
            text: {
                switch (osd.kind) {
                    case "brightness": return Hyprsunset.temperatureActive ? "routine" : "light_mode"
                    case "gamma":      return "wb_twilight"
                    default:
                        if (osd.muted || osd.clamped <= 0) return "volume_off"
                        if (osd.clamped < 0.34) return "volume_mute"
                        if (osd.clamped < 0.67) return "volume_down"
                        return "volume_up"
                }
            }

            Behavior on color {
                ColorAnimation { duration: IslandMotion.short }
            }
        }

        Item { Layout.fillWidth: true }

        StyledText {
            text: osd.muted ? Translation.tr("Muted") : `${Math.round(Math.max(0, osd.shown) * 100)}%`
            font.pixelSize: osd.di.isMaterial ? Appearance.font.pixelSize.normal : Appearance.font.pixelSize.small
            font.weight: Font.DemiBold
            font.features: { "tnum": 1 }
            color: osd.boosted ? osd.boostColor : Appearance.colors.colOnLayer0
        }
    }
}
