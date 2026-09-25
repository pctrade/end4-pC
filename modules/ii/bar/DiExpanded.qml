import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// Click-to-open state of the island. The overlay starts exactly on the island's visible surface and grows out of
// it; closing shrinks it back into that same shape, so it reads as the island changing size, not a second window.
// While the pointer rests on it the island leans in a touch; when the pointer leaves it eases back and a thin fuse
// shows how long until it closes by itself. Clicking anywhere else closes it right away.
Scope {
    id: scope
    required property Item di
    required property Item pillItem

    property real progress: scope.di.expanded ? 1 : 0
    readonly property bool closing: !scope.di.expanded

    Behavior on progress {
        NumberAnimation {
            duration: scope.di.expanded ? 480 : 380
            easing.type: Easing.BezierSpline
            easing.bezierCurve: scope.di.expanded
                ? Appearance.animationCurves.expressiveDefaultSpatial
                : Appearance.animationCurves.emphasizedDecel
        }
    }

    LazyLoader {
        active: scope.di.visible

        component: PanelWindow {
            id: win

            readonly property bool bottomBar: Config.options.bar.bottom
            readonly property real barMargin: Config.options.bar.cornerStyle === 3 ? 5 : 0
            readonly property real barWindowHeight: Appearance.sizes.barHeight + Appearance.rounding.screenRounding
            readonly property Item surface: scope.di.surfaceItem
            readonly property rect surfaceRect: {
                win.surface.width
                win.surface.height
                scope.pillItem.width
                scope.di.implicitWidth
                const s = scope.di.QsWindow.mapFromItem(win.surface, 0, 0)
                const q = scope.di.QsWindow.mapFromItem(scope.pillItem, 0, 0)
                const left = Math.min(s.x, q.x)
                const top = Math.min(s.y, q.y)
                const right = Math.max(s.x + win.surface.width, q.x + scope.pillItem.width)
                const bottom = Math.max(s.y + win.surface.height, q.y + scope.pillItem.height)
                return Qt.rect(left, top, right - left, bottom - top)
            }

            screen: scope.di.QsWindow.window?.screen ?? null
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            exclusiveZone: 0
            WlrLayershell.namespace: "quickshell:dynamicIsland"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.keyboardFocus: scope.di.wantsKeyboard ? WlrKeyboardFocus.Exclusive
                : (scope.di.expanded && scope.di.replyReady ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None)

            anchors {
                top: !win.bottomBar
                bottom: win.bottomBar
                left: true
                right: true
            }
            margins {
                top: win.bottomBar ? 0 : win.barMargin
                bottom: win.bottomBar ? win.barMargin : 0
            }
            implicitHeight: 700
            mask: Region { item: scope.progress > 0.002 ? island : noInput }

            Item {
                id: noInput
                width: 0
                height: 0
            }

            HyprlandFocusGrab {
                windows: [win]
                active: scope.di.expanded
                onCleared: if (scope.di.expanded) scope.di.collapse()
            }

            StyledRectangularShadow {
                target: island
                opacity: Math.max(0, Math.min(1, scope.progress)) * (1 + 0.25 * island.leanValue)
                visible: scope.progress > 0.05
            }

            Rectangle {
                id: island

                readonly property real p: Math.max(0, scope.progress)
                readonly property real pc: Math.min(1, island.p)
                readonly property bool settled: scope.di.expanded && island.p > 0.95

                readonly property real startW: win.surfaceRect.width + 3
                readonly property real startH: win.surfaceRect.height + 2
                readonly property real maxH: Math.min(win.height - 24, (win.screen?.height ?? 1080) * 0.55)
                readonly property real maxW: win.width - 24
                readonly property bool splitActive: scope.di.splitId !== "" && scope.di.splitId !== scope.di.expandedId
                    && scope.di.hasDetails(scope.di.splitId)

                readonly property real bottomReserve: 18 + (scope.di.splitArmed ? splitPicker.implicitHeight + 10 : 0)

                readonly property real wantedW: Math.min(island.maxW, Math.max(island.startW,
                    detail.implicitWidth + (island.splitActive ? 12 + splitDetail.implicitWidth : 0)))
                readonly property real wantedH: Math.max(island.startH,
                    Math.max(detail.implicitHeight, island.splitActive ? splitDetail.implicitHeight : 0)
                        + island.bottomReserve)

                property real heldW: 0
                property real heldH: 0
                onPointerInChanged: {
                    island.heldW = island.wantedW
                    island.heldH = island.wantedH
                }

                property real targetW: island.pointerIn ? Math.max(island.wantedW, island.heldW) : island.wantedW
                property real targetH: island.pointerIn ? Math.max(island.wantedH, island.heldH) : island.wantedH

                Behavior on targetW {
                    NumberAnimation { duration: 440; easing.type: Easing.BezierSpline; easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial }
                }
                Behavior on targetH {
                    NumberAnimation { duration: 440; easing.type: Easing.BezierSpline; easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial }
                }

                readonly property bool shown: scope.progress > 0.02
                readonly property bool coversPill: scope.progress > 0.2
                onCoversPillChanged: scope.di.overlayShown = island.coversPill
                Component.onDestruction: {
                    scope.di.overlayShown = false
                    scope.di.cardHovered = false
                }

                readonly property bool pointerIn: scope.di.cardHovered
                readonly property real lean: island.settled ? (island.pointerIn ? 1 : -1) : 0
                property real leanValue: island.lean

                Behavior on leanValue {
                    SpringAnimation { spring: 3.4; damping: 0.3; epsilon: 0.002 }
                }

                transform: Scale {
                    origin.x: island.width / 2
                    origin.y: win.bottomBar ? island.height : 0
                    xScale: 1 + 0.012 * Math.max(-0.6, island.leanValue)
                    yScale: 1 + 0.018 * Math.max(-0.6, island.leanValue)
                }

                readonly property real pw: Math.min(1, island.p * 2.2)
                width: island.startW + (island.targetW - island.startW) * island.pw
                height: island.startH + (island.targetH - island.startH) * island.p
                x: Math.max(8, Math.min(win.width - island.width - 8, win.surfaceRect.x - 1.5 + island.startW / 2 - island.width / 2))
                y: win.bottomBar
                    ? win.height - (win.barWindowHeight - win.surfaceRect.y - island.startH) - island.height + 1
                    : win.surfaceRect.y - 1
                radius: Math.min(island.height / 2, island.startH / 2 + 12 * island.pc)
                color: scope.di.surfaceColor
                border.width: 1
                border.color: ColorUtils.transparentize(Appearance.colors.colLayer0Border, 1 - island.pc * (island.pointerIn ? 1 : 0.6))
                clip: true
                visible: scope.progress > 0.002

                Behavior on border.color {
                    ColorAnimation { duration: 220 }
                }

                HoverHandler {
                    onHoveredChanged: scope.di.cardHovered = hovered
                }

                TapHandler {
                    acceptedButtons: Qt.MiddleButton
                    onTapped: scope.di.collapse()
                }

                WheelHandler {
                    id: wheel
                    target: null
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    property bool coolingDown: false
                    onWheel: event => {
                        if (wheel.coolingDown) return
                        wheel.coolingDown = true
                        wheelCooldown.restart()
                        scope.di.cycleIsland(event.angleDelta.y < 0 ? 1 : -1)
                    }
                }

                Timer {
                    id: wheelCooldown
                    interval: 280
                    onTriggered: wheel.coolingDown = false
                }

                Item {
                    id: compactGhost
                    x: (island.width - island.startW) / 2 + 1.5
                    y: win.bottomBar ? island.height - island.startH : 1
                    width: island.startW - 3
                    height: island.startH - 2
                    opacity: scope.closing
                        ? Math.max(0, Math.min(1, (0.5 - island.p) / 0.4))
                        : Math.max(0, 1 - island.pc * 3)
                    visible: scope.progress > 0.002

                    Item {
                        x: win.surfaceRect.width > 0 ? (scope.di.QsWindow.mapFromItem(scope.pillItem, 0, 0).x - win.surfaceRect.x) : 0
                        anchors.verticalCenter: parent.verticalCenter
                        width: scope.pillItem.width
                        height: scope.di.pillHeight

                        Loader {
                            id: compactLoader
                            anchors.fill: parent
                            sourceComponent: scope.di.componentFor(scope.di.primaryId)
                        }
                    }
                }

                readonly property real pairW: island.splitActive ? detail.width + 12 + splitDetail.width : detail.width

                DiExpandedContent {
                    id: detail
                    di: scope.di
                    contentId: scope.di.expandedId
                    maxHeight: island.maxH - island.bottomReserve
                    x: (island.width - island.pairW) / 2
                    y: win.bottomBar ? island.height - height : 0
                    width: island.splitActive ? Math.min(island.maxW, implicitWidth)
                        : Math.min(island.maxW, Math.max(island.width, implicitWidth))
                    height: implicitHeight
                    opacity: (scope.closing
                        ? Math.max(0, Math.min(1, (island.p - 0.5) / 0.5))
                        : Math.max(0, Math.min(1, (island.p - 0.35) / 0.5)))
                        * (1 - 0.04 * Math.max(0, Math.min(1, -island.leanValue)))
                    visible: island.shown
                }

                Rectangle {
                    id: splitDivider
                    visible: island.splitActive && island.shown
                    x: detail.x + detail.width + 5
                    y: Math.max(detail.y, splitDetail.y) + 4
                    width: 1
                    height: Math.min(detail.height, splitDetail.height) - 8
                    color: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.85)
                    opacity: detail.opacity
                }

                DiExpandedContent {
                    id: splitDetail
                    di: scope.di
                    contentId: island.splitActive ? scope.di.splitId : ""
                    maxHeight: island.maxH - island.bottomReserve
                    x: detail.x + detail.width + 12
                    y: win.bottomBar ? island.height - height : 0
                    width: Math.min(island.maxW, implicitWidth)
                    height: implicitHeight
                    opacity: island.splitActive ? detail.opacity : 0
                    visible: island.splitActive && island.shown
                }

                readonly property var compactHero: compactLoader.item?.hero ?? null
                readonly property var fullHero: detail.viewItem?.hero ?? null
                readonly property bool heroActive: island.compactHero !== null && island.fullHero !== null
                    && island.compactHero.key === island.fullHero.key && !!island.compactHero.item && !!island.fullHero.item
                    && island.p > 0.001 && island.p < 0.999
                property rect heroFrom: Qt.rect(0, 0, 0, 0)
                property rect heroTo: Qt.rect(0, 0, 0, 0)

                function measureHeroes() {
                    if (!island.heroActive) return
                    const c = island.compactHero.item
                    const f = island.fullHero.item
                    const a = island.mapFromItem(c, 0, 0)
                    const b = island.mapFromItem(f, 0, 0)
                    island.heroFrom = Qt.rect(a.x, a.y, c.width, c.height)
                    island.heroTo = Qt.rect(b.x, b.y, f.width, f.height)
                }
                onPChanged: island.measureHeroes()
                onHeroActiveChanged: island.measureHeroes()

                Item {
                    id: heroFlight
                    readonly property real t: island.pc
                    visible: island.heroActive
                    z: 10
                    x: island.heroFrom.x + (island.heroTo.x - island.heroFrom.x) * heroFlight.t
                    y: island.heroFrom.y + (island.heroTo.y - island.heroFrom.y) * heroFlight.t
                    width: island.heroFrom.width + (island.heroTo.width - island.heroFrom.width) * heroFlight.t
                    height: island.heroFrom.height + (island.heroTo.height - island.heroFrom.height) * heroFlight.t

                    ShaderEffectSource {
                        anchors.fill: parent
                        sourceItem: island.heroActive ? island.compactHero.item : null
                        hideSource: heroFlight.visible
                        live: true
                        smooth: true
                        opacity: 1 - Math.min(1, heroFlight.t * 1.6)
                    }
                    ShaderEffectSource {
                        anchors.fill: parent
                        sourceItem: island.heroActive ? island.fullHero.item : null
                        hideSource: heroFlight.visible
                        live: true
                        smooth: true
                        opacity: Math.min(1, heroFlight.t * 1.6)
                    }
                }

                Row {
                    id: pager
                    visible: scope.di.switcherIds.length > 1
                    height: 14
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: win.bottomBar ? 2 : island.height - height - 3
                    spacing: 5
                    opacity: Math.max(0, Math.min(1, (island.p - 0.6) / 0.4))

                    Repeater {
                        model: scope.di.switcherIds
                        delegate: Rectangle {
                            required property string modelData
                            readonly property bool current: modelData === scope.di.expandedId
                            readonly property bool splitPartner: modelData === scope.di.splitId
                            anchors.verticalCenter: parent.verticalCenter
                            width: (current || splitPartner) ? 16 : 6
                            height: 6
                            radius: 3
                            color: current ? Appearance.colors.colPrimary
                                : splitPartner ? Appearance.colors.colSecondary
                                : ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.7)

                            Behavior on width {
                                NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
                            }

                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -4
                                cursorShape: Qt.PointingHandCursor
                                onClicked: scope.di.selectForSplit(parent.modelData)
                            }
                        }
                    }
                }

                Rectangle {
                    id: splitButton
                    readonly property bool lit: scope.di.splitArmed || scope.di.splitId !== ""
                    x: island.width - width - Math.max(12, island.radius * 0.75)
                    y: win.bottomBar ? 5 : island.height - height - 5
                    width: 22
                    height: 14
                    radius: 7
                    color: splitButton.lit ? Appearance.colors.colPrimary
                        : (splitButtonMouse.containsMouse ? Appearance.colors.colLayer2 : "transparent")
                    opacity: Math.max(0, Math.min(1, (island.p - 0.6) / 0.4))

                    Behavior on color {
                        ColorAnimation { duration: 160 }
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: scope.di.splitId !== "" ? "close" : "splitscreen_right"
                        iconSize: 11
                        fill: 1
                        color: splitButton.lit ? Appearance.colors.colOnPrimary
                            : ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.35)
                    }

                    MouseArea {
                        id: splitButtonMouse
                        anchors.fill: parent
                        anchors.margins: -5
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: scope.di.toggleSplitArm()
                    }
                }

                Flow {
                    id: splitPicker
                    visible: scope.di.splitArmed
                    x: 14
                    width: island.width - 28
                    y: win.bottomBar ? 22 : island.height - 18 - height - 6
                    spacing: 6
                    opacity: scope.di.splitArmed ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                    }

                    Repeater {
                        model: scope.di.splitArmed ? scope.di.splitCandidates : []
                        delegate: Rectangle {
                            id: pickChip
                            required property string modelData
                            required property int index
                            implicitWidth: pickRow.implicitWidth + 18
                            implicitHeight: 28
                            radius: 14
                            color: pickMouse.containsMouse ? Appearance.colors.colPrimaryContainer : Appearance.colors.colLayer1
                            scale: 0.4
                            opacity: 0
                            transformOrigin: Item.Right

                            Behavior on color {
                                ColorAnimation { duration: 140 }
                            }

                            SequentialAnimation {
                                running: true
                                PauseAnimation { duration: pickChip.index * 32 }
                                ParallelAnimation {
                                    NumberAnimation { target: pickChip; property: "scale"; to: 1; duration: 340; easing.type: Easing.OutBack; easing.overshoot: 1.5 }
                                    NumberAnimation { target: pickChip; property: "opacity"; to: 1; duration: 200; easing.type: Easing.OutCubic }
                                }
                            }

                            RowLayout {
                                id: pickRow
                                anchors.centerIn: parent
                                spacing: 6

                                DiClaudeIcon {
                                    visible: ["claude", "codex", "gemini"].includes(scope.di.iconForId(pickChip.modelData))
                                    agent: scope.di.iconForId(pickChip.modelData)
                                    size: 14
                                }
                                MaterialSymbol {
                                    visible: !["claude", "codex", "gemini"].includes(scope.di.iconForId(pickChip.modelData))
                                    text: scope.di.iconForId(pickChip.modelData)
                                    iconSize: 15
                                    fill: 1
                                    color: pickMouse.containsMouse ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer1
                                }
                                StyledText {
                                    text: scope.di.nameForId(pickChip.modelData)
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: pickMouse.containsMouse ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnLayer1
                                }
                            }

                            MouseArea {
                                id: pickMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: scope.di.chooseSplit(pickChip.modelData)
                            }
                        }
                    }
                }

                Item {
                    id: fuseTrack
                    property real remaining: 1
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: win.bottomBar ? 1 : island.height - 3
                    width: Math.min(120, island.width * 0.4)
                    height: 2
                    opacity: fuse.running ? 1 : 0

                    Behavior on opacity {
                        NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 1
                        color: ColorUtils.transparentize(Appearance.colors.colOnLayer0, 0.88)
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width * fuseTrack.remaining
                        height: parent.height
                        radius: 1
                        color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.25)
                    }

                    NumberAnimation {
                        id: fuse
                        target: fuseTrack
                        property: "remaining"
                        from: 1
                        to: 0
                        duration: scope.di.collapseDelay
                        running: island.settled && !island.pointerIn
                        onFinished: {
                            if (!scope.di.cardHovered && !(scope.di.wantsKeyboard && scope.di.replyHasText) && !scope.di.dragging)
                                scope.di.collapse()
                        }
                    }
                }
            }
        }
    }
}
