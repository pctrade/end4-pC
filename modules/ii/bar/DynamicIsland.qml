import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Qt5Compat.GraphicalEffects
import QtQuick.Controls
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: root
    property bool mirrored: false
    property real sessionOpacity: GlobalStates.diSessionOpen ? 1 : 0
    readonly property bool sessionVisible: GlobalStates.diSessionOpen || sessionOpacity > 0

    Behavior on sessionOpacity {
        NumberAnimation { duration: 350; easing.type: Easing.InOutCubic }
    }

    readonly property string sessionMenuMode:
        Config.options.bar.dynamicIsland.sessionMenuMode ?? "exclusive"
    readonly property bool sessionReplacesCenter: root.sessionVisible
        && Config.options.bar.dynamicIsland.centerEnabled
        && Config.options.bar.dynamicIsland.centerWidget.length > 0
        && Config.options.bar.dynamicIsland.centerWidget !== "dynamicIsland"
        && !root.vertical && root.sessionMenuMode === "replaceWorkspaces"
    readonly property bool sessionExclusive: root.sessionVisible
        && !root.sessionReplacesCenter
    readonly property string centerWidget: Config.options.bar.dynamicIsland.centerWidget
    readonly property bool centerEnabled: Config.options.bar.dynamicIsland.centerEnabled
        && root.centerWidget.length > 0 && root.centerWidget !== "dynamicIsland"
        && !root.vertical
    readonly property real widgetSpacing: 8
    // BarContent supplies the free space between the screen centre and the
    // outer bar sections. The island stays symmetric while both limits allow
    // it, then removes only unused wing space on the constrained side.
    property real maxLeftExtent: Number.POSITIVE_INFINITY
    property real maxRightExtent: Number.POSITIVE_INFINITY
    readonly property real pillHeight: 32
    readonly property real emptyCollapsedWidth: 40
    readonly property real emptyExpandedWidth: 56
    readonly property real sessionWidth: 164
    property real mediaCollapsedWidth: 72
    readonly property real mediaExpandedWidthCap: 220
    property real mediaTextContentWidth: 0
    readonly property string mediaDisplayMode: Config.options.bar.dynamicIsland.widgetModes.media ?? "dynamic"
    property bool mediaHovered: false
    readonly property bool mediaTrackInfoVisible: root.hasMedia
        && (root.mediaDisplayMode === "expanded"
            || (root.mediaDisplayMode === "dynamic" && root.expanded)
            || (root.mediaDisplayMode === "dynamicHover" && root.mediaHovered))
    readonly property real mediaExpandedWidth: Math.max(root.mediaCollapsedWidth, Math.min(root.mediaExpandedWidthCap, root.mediaTextContentWidth))
    readonly property real mediaWidth: root.mediaTrackInfoVisible ? root.mediaExpandedWidth : root.mediaCollapsedWidth
    readonly property real recordingWidth: 96
    readonly property real timerWidth: 130
    readonly property real osdWidth: 132
    readonly property real notificationTextWidth: Math.min(166, Math.max(notificationSummaryMetrics.width, notificationBodyMetrics.width))
    readonly property real notificationWidth: (root.isMaterial ? 48 : 44) + root.notificationTextWidth
    readonly property real batteryWidth: 170
    readonly property real badgeSize: 32
    readonly property real badgeSpacing: 6
    readonly property bool isMaterial: Config.options.bar.cornerStyle === 3 || Config.options.bar.cornerStyle === 4
    property bool vertical: Config.options.bar.vertical

    readonly property real activitySpacing: 6

    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property bool hasMedia: root.activePlayer !== null
        && ((root.activePlayer.trackTitle ?? "") !== "" || root.activePlayer.isPlaying)
    readonly property var latestNotification: Notifications.popupList.length > 0
        ? Notifications.popupList[Notifications.popupList.length - 1]
        : null

    TextMetrics {
        id: notificationSummaryMetrics
        text: (root.latestNotification?.summary ?? "").replace(/\n/g, " ")
        font.pixelSize: Appearance.font.pixelSize.smaller
        font.weight: Font.DemiBold
    }

    TextMetrics {
        id: notificationBodyMetrics
        text: (root.latestNotification?.body ?? "").replace(/\n/g, " ")
        font.pixelSize: Appearance.font.pixelSize.smallest
    }
    readonly property bool isRecording: Persistent.states.record.enable
    property int recordingElapsedSeconds: 0

    onIsRecordingChanged: {
        if (!isRecording) recordingElapsedSeconds = 0
    }

    function formatRecordingTime(s) {
        return Math.floor(s / 60).toString().padStart(2, '0') + ":" + (s % 60).toString().padStart(2, '0')
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.isRecording
        onTriggered: root.recordingElapsedSeconds++
    }

    property string engagedTimerKind: ""
    readonly property bool hasActiveTimer: root.engagedTimerKind !== ""

    Connections {
        target: TimerService
        function onPomodoroRunningChanged() { if (TimerService.pomodoroRunning) root.engagedTimerKind = "pomodoro" }
        function onCountdownRunningChanged() { if (TimerService.countdownRunning) root.engagedTimerKind = "countdown" }
        function onStopwatchRunningChanged() { if (TimerService.stopwatchRunning) root.engagedTimerKind = "stopwatch" }
    }

    function timerIcon() {
        switch (root.engagedTimerKind) {
            case "pomodoro":  return TimerService.pomodoroBreak ? "coffee" : "visibility"
            case "countdown": return "hourglass_top"
            case "stopwatch": return "timer"
            default:          return "timer"
        }
    }

    function timerValueText() {
        switch (root.engagedTimerKind) {
            case "pomodoro":  return TimerService.formatSeconds(TimerService.pomodoroSecondsLeft)
            case "countdown": return TimerService.formatSeconds(TimerService.countdownSecondsLeft)
            case "stopwatch": return TimerService.formatSeconds(TimerService.stopwatchTime / 100)
            default:          return ""
        }
    }

    function timerRunning() {
        switch (root.engagedTimerKind) {
            case "pomodoro":  return TimerService.pomodoroRunning
            case "countdown": return TimerService.countdownRunning
            case "stopwatch": return TimerService.stopwatchRunning
            default:          return false
        }
    }

    function toggleActiveTimer() {
        switch (root.engagedTimerKind) {
            case "pomodoro":  TimerService.togglePomodoro(); break
            case "countdown": TimerService.toggleCountdown(); break
            case "stopwatch": TimerService.toggleStopwatch(); break
        }
    }

    function resetActiveTimer() {
        switch (root.engagedTimerKind) {
            case "pomodoro":  TimerService.resetPomodoro(); break
            case "countdown": TimerService.resetCountdown(); break
            case "stopwatch": TimerService.stopwatchReset(); break
        }
        root.engagedTimerKind = ""
    }

    property bool batteryAlertActive: false
    property string batteryAlertKind: "" 
    readonly property int batteryAlertDuration: 4000

    Timer {
        id: batteryAlertTimer
        interval: root.batteryAlertDuration
        repeat: false
        onTriggered: root.batteryAlertActive = false
    }

    function triggerBatteryAlert(kind) {
        root.batteryAlertKind = kind
        root.batteryAlertActive = true
        batteryAlertTimer.restart()
    }

    Connections {
        target: Battery
        function onIsCriticalAndNotChargingChanged() {
            if (Battery.isCriticalAndNotCharging) root.triggerBatteryAlert("critical")
        }
        function onIsLowAndNotChargingChanged() {
            if (Battery.isLowAndNotCharging && !Battery.isCriticalAndNotCharging) root.triggerBatteryAlert("low")
        }
        function onIsPluggedInChanged() {
            if (Battery.isPluggedIn) root.triggerBatteryAlert("charging")
        }
    }

    function batteryStatusText() {
        switch (root.batteryAlertKind) {
            case "critical": return Translation.tr("Critical Battery")
            case "charging": return Translation.tr("Charging")
            default:         return Translation.tr("Low Battery")
        }
    }

    function batteryIcon() {
        if (root.batteryAlertKind === "charging" || Battery.isCharging) return "battery_android_frame_bolt"
        const pct = Battery.percentage
        if (pct <= 0.1) return "battery_android_frame_alert"
        if (pct <= 0.2) return "battery_android_frame_1"
        if (pct <= 0.4) return "battery_android_frame_2"
        if (pct <= 0.6) return "battery_android_frame_3"
        if (pct <= 0.8) return "battery_android_frame_4"
        if (pct < 1)    return "battery_android_frame_5"
        return "battery_android_full"
    }

    function batteryAlertColor() {
        return root.batteryAlertKind === "charging" ? Appearance.m3colors.m3success : Appearance.colors.colError
    }

    readonly property var sessionProvider: ({
        id: "session",
        active: root.sessionExclusive,
        component: sessionComponent,
        width: root.sessionWidth
    })

    readonly property bool hasActiveActivity: root.isRecording || root.hasActiveTimer || root.latestNotification != null || root.batteryAlertActive || GlobalStates.osdVolumeOpen

    readonly property var activeProvider:
        root.sessionExclusive ? root.sessionProvider : null
    readonly property var displayedProvider: root.activeProvider
    readonly property var pillProvider: root.displayedProvider

    function iconForProviderId(id) {
        switch (id) {
            case "media":     return "music_note"
            case "recording": return "screen_record"
            case "timer":     return root.timerIcon()
            case "battery":   return root.batteryIcon()
            case "osd":
                switch (GlobalStates.osdIndicatorType) {
                    case "brightness": return Hyprsunset.temperatureActive ? "routine" : "light_mode"
                    case "gamma":      return "wb_twilight"
                    default:           return Audio.sink?.audio?.muted ? "volume_off" : "volume_up"
                }
            default: return "circle"
        }
    }

    readonly property string activeContentId: root.displayedProvider?.id ?? "empty"

    // BarContent also feeds hover from the complete central bar area. The
    // local handler remains useful when this component is used elsewhere.
    property bool barHovered: false
    property bool mediaPopupKeepsBarExpanded: false
    readonly property bool expanded: root.barHovered || islandHover.hovered || root.mediaPopupKeepsBarExpanded
    property bool componentInteractionReady: false

    onExpandedChanged: {
        if (expanded) {
            componentInteractionTimer.restart();
        } else {
            componentInteractionTimer.stop();
            componentInteractionReady = false;
        }
    }

    Timer {
        id: componentInteractionTimer
        interval: 350
        repeat: false
        onTriggered: root.componentInteractionReady = true
    }
    readonly property real contentPadding: 8
    readonly property bool hasPersistentContent: root.centerEnabled
        || leftWidgets.implicitWidth > 0 || rightWidgets.implicitWidth > 0
    readonly property real emptyWidth: root.hasPersistentContent ? 0
        : (root.expanded ? root.emptyExpandedWidth : root.emptyCollapsedWidth)
    property real primaryWidth: root.sessionExclusive ? root.emptyWidth
        : (root.pillProvider?.width ?? root.emptyWidth)
    Behavior on primaryWidth {
        NumberAnimation { duration: 350; easing.type: Easing.OutCubic }
    }
    readonly property real leftContentWidth: leftWidgets.implicitWidth
        + (leftWidgets.implicitWidth > 0 && root.primaryWidth > 0 ? root.widgetSpacing : 0)
        + root.primaryWidth
    readonly property real rightContentWidth: rightWidgets.implicitWidth
    readonly property real wingWidth: Math.max(root.leftContentWidth, root.rightContentWidth)
    readonly property real centerHalfWidth: (root.sessionReplacesCenter
        ? centerLoader.implicitWidth + (root.sessionWidth - centerLoader.implicitWidth) * root.sessionOpacity
        : centerLoader.implicitWidth) / 2
    readonly property real fixedCenterExtent: root.contentPadding + root.centerHalfWidth
        + root.widgetSpacing
    readonly property real leftWingLimit: Math.max(0, root.maxLeftExtent - root.fixedCenterExtent)
    readonly property real rightWingLimit: Math.max(0, root.maxRightExtent - root.fixedCenterExtent)
    readonly property real leftWingWidth: root.centerEnabled
        ? Math.max(root.leftContentWidth, Math.min(root.wingWidth, root.leftWingLimit))
        : root.leftContentWidth
    readonly property real rightWingWidth: root.centerEnabled
        ? Math.max(root.rightContentWidth, Math.min(root.wingWidth, root.rightWingLimit))
        : root.rightContentWidth
    readonly property real leftExtent: root.centerEnabled
        ? root.fixedCenterExtent + root.leftWingWidth : 0
    readonly property real rightExtent: root.centerEnabled
        ? root.fixedCenterExtent + root.rightWingWidth : 0
    readonly property real centerX: root.centerEnabled ? root.leftExtent : root.width / 2
    readonly property real barCenterOffset: (root.centerEnabled
        ? (root.rightExtent - root.leftExtent) / 2 : 0)
        * (root.sessionExclusive ? 1 - root.sessionOpacity : 1)
    readonly property real leftStart: root.contentPadding
    readonly property real rightStart: root.width - root.contentPadding - root.rightContentWidth

    implicitHeight: root.pillHeight
    readonly property real normalWidth: root.centerEnabled
        ? root.leftExtent + root.rightExtent
        : 2 * root.contentPadding + root.leftContentWidth + root.rightContentWidth
            + (root.leftContentWidth > 0 && root.rightContentWidth > 0 ? root.widgetSpacing : 0)

    implicitWidth: root.sessionExclusive
        ? root.normalWidth + (root.sessionWidth + 2 * root.contentPadding - root.normalWidth) * root.sessionOpacity
        : root.normalWidth
    clip: root.sessionVisible

    HoverHandler { id: islandHover }

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: root.isMaterial ? "transparent" : Config.options.bar.followFrameColor
            ? Appearance.getColorFromName(Config.options.bar.frameColor) : Appearance.colors.colLayer0
    }

    Component {
        id: mediaSideComponent
        Item {
            id: mediaSideRoot
            readonly property bool containsMouse: mediaSideHover.hovered
            implicitWidth: root.hasMedia ? root.mediaWidth : 0
            implicitHeight: root.pillHeight
            visible: root.hasMedia

            Behavior on implicitWidth {
                NumberAnimation {
                    duration: 350
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial
                }
            }

            HoverHandler {
                id: mediaSideHover
                enabled: root.hasMedia
                onHoveredChanged: root.mediaHovered = hovered
            }

            Component.onDestruction: root.mediaHovered = false

            MediaPopup {
                hoverTarget: mediaSideRoot
                barHovered: root.barHovered || islandHover.hovered
                onKeepsBarExpandedChanged: root.mediaPopupKeepsBarExpanded = keepsBarExpanded
                Component.onDestruction: root.mediaPopupKeepsBarExpanded = false
            }

            DiMedia { di: root }
        }
    }

    Component {
        id: activitySideComponent
        Item {
            implicitWidth: activityRow.implicitWidth
            implicitHeight: root.pillHeight

            Row {
                id: activityRow
                anchors.verticalCenter: parent.verticalCenter
                spacing: root.activitySpacing

                ActivitySlot {
                    shown: root.isRecording
                    targetWidth: root.recordingWidth
                    contentComponent: recordingComponent
                }
                ActivitySlot {
                    shown: root.hasActiveTimer
                    targetWidth: root.timerWidth
                    contentComponent: timerComponent
                }
                ActivitySlot {
                    shown: root.latestNotification !== null
                    targetWidth: root.notificationWidth
                    contentComponent: notificationComponent
                }
                ActivitySlot {
                    shown: root.batteryAlertActive
                    targetWidth: root.batteryWidth
                    contentComponent: batteryComponent
                }
                ActivitySlot {
                    shown: GlobalStates.osdVolumeOpen
                    targetWidth: root.osdWidth
                    contentComponent: osdComponent
                }
            }
        }
    }

    Component {
        id: osdComponent
        DiOsd { di: root }
    }

    component ActivitySlot: Item {
        id: activitySlot
        required property bool shown
        required property real targetWidth
        required property Component contentComponent

        width: shown ? targetWidth : 0
        height: root.pillHeight
        visible: shown || width > 0.5
        opacity: shown ? 1 : 0
        clip: true

        Loader {
            anchors.fill: parent
            active: activitySlot.visible
            sourceComponent: activitySlot.contentComponent
        }

        Behavior on width {
            NumberAnimation {
                duration: 350
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }
    }

    component SideWidgetDelegate: Item {
        id: sideDelegate
        required property string modelData
        required property bool anchorRight
        readonly property bool supportsExpansion: ["clockWidget", "resources", "visualizer"].includes(modelData)
        readonly property string displayMode: Config.options.bar.dynamicIsland.widgetModes[modelData] ?? "dynamic"
        readonly property bool contentAvailable: (modelData !== "media" || root.hasMedia)
            && (modelData !== "activity" || root.hasActiveActivity)
            && (modelData !== "visualizer" || (root.activePlayer?.isPlaying ?? false))
        readonly property real contentImplicitWidth: mediaLoader.active ? mediaLoader.implicitWidth
            : (activityLoader.active ? activityLoader.implicitWidth : regularLoader.implicitWidth)
        readonly property real contentImplicitHeight: mediaLoader.active ? mediaLoader.implicitHeight
            : (activityLoader.active ? activityLoader.implicitHeight : regularLoader.implicitHeight)

        visible: contentAvailable || implicitWidth > 0.5
        enabled: contentAvailable && (modelData === "media" || root.componentInteractionReady)
        opacity: contentAvailable ? 1 : 0
        implicitWidth: contentAvailable || modelData === "activity" ? contentImplicitWidth : 0
        implicitHeight: contentAvailable ? contentImplicitHeight : root.pillHeight
        Layout.alignment: Qt.AlignVCenter
        clip: ["visualizer", "activity"].includes(modelData)

        Behavior on implicitWidth {
            enabled: sideDelegate.modelData !== "activity"
                && (sideDelegate.modelData === "visualizer"
                    || Config.options.bar.dynamicIsland.animationStyle === "staged")
            NumberAnimation {
                readonly property bool isActivity: sideDelegate.modelData === "activity"
                readonly property bool simultaneous: Config.options.bar.dynamicIsland.animationStyle === "simultaneous"
                duration: isActivity ? 350 : (simultaneous ? 200 : 350)
                easing.type: isActivity || !simultaneous ? Easing.BezierSpline : Easing.OutCubic
                easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial
            }
        }

        Behavior on opacity {
            enabled: Config.options.bar.dynamicIsland.animationStyle === "staged"
                || ["activity", "visualizer"].includes(sideDelegate.modelData)
            NumberAnimation {
                duration: sideDelegate.modelData === "activity" ? 350 : 200
                easing.type: sideDelegate.modelData === "activity" ? Easing.InOutCubic : Easing.OutCubic
            }
        }

        HoverHandler {
            id: sideWidgetHover
            enabled: sideDelegate.contentAvailable
                && sideDelegate.displayMode === "dynamicHover"
                && root.componentInteractionReady
        }

        Loader {
            id: mediaLoader
            active: sideDelegate.modelData === "media"
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: sideDelegate.anchorRight ? undefined : parent.left
            anchors.right: sideDelegate.anchorRight ? parent.right : undefined
            sourceComponent: mediaSideComponent
        }

        Loader {
            id: activityLoader
            active: sideDelegate.modelData === "activity"
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: sideDelegate.anchorRight ? undefined : parent.left
            anchors.right: sideDelegate.anchorRight ? parent.right : undefined
            sourceComponent: activitySideComponent
        }

        Loader {
            id: regularLoader
            active: sideDelegate.modelData !== "media" && sideDelegate.modelData !== "activity"
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: sideDelegate.anchorRight ? undefined : parent.left
            anchors.right: sideDelegate.anchorRight ? parent.right : undefined
            source: active ? Qt.resolvedUrl("./" + sideDelegate.modelData.charAt(0).toUpperCase()
                + sideDelegate.modelData.slice(1) + ".qml") : ""
        }

        Binding {
            target: sideDelegate.supportsExpansion ? regularLoader.item : null
            property: "islandMode"
            value: true
            when: sideDelegate.supportsExpansion && regularLoader.status === Loader.Ready
        }
        Binding {
            target: sideDelegate.supportsExpansion ? regularLoader.item : null
            property: "islandExpanded"
            value: sideDelegate.displayMode === "expanded"
                || (sideDelegate.displayMode === "dynamic" && root.expanded)
                || (sideDelegate.displayMode === "dynamicHover" && sideWidgetHover.hovered)
            when: sideDelegate.supportsExpansion && regularLoader.status === Loader.Ready
        }
        Binding {
            target: sideDelegate.modelData === "visualizer" ? regularLoader.item : null
            property: "islandAnchorRight"
            value: sideDelegate.anchorRight
            when: sideDelegate.modelData === "visualizer"
                && regularLoader.status === Loader.Ready
        }
    }

    component SideWidgets: Item {
        id: sideWidgetsRoot
        property var widgets: []
        property var rightAnchoredWidgets: []
        readonly property var filteredWidgets: widgets.filter(name => name !== "dynamicIsland"
            && !(name === root.centerWidget && root.centerEnabled))
        readonly property real leftGroupWidth: leftGroup.implicitWidth
        readonly property real rightGroupWidth: rightGroup.implicitWidth
        readonly property bool hasLeftGroup: leftGroupWidth > 0.5
        readonly property bool hasRightGroup: rightGroupWidth > 0.5

        implicitWidth: leftGroupWidth + rightGroupWidth
            + (hasLeftGroup && hasRightGroup ? root.widgetSpacing : 0)
        implicitHeight: Math.max(leftGroup.implicitHeight, rightGroup.implicitHeight, root.pillHeight)

        RowLayout {
            id: leftGroup
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.widgetSpacing

            Repeater {
                model: sideWidgetsRoot.filteredWidgets.filter(
                    name => !sideWidgetsRoot.rightAnchoredWidgets.includes(name))
                delegate: SideWidgetDelegate { anchorRight: false }
            }
        }

        RowLayout {
            id: rightGroup
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: root.widgetSpacing

            Repeater {
                model: sideWidgetsRoot.filteredWidgets.filter(
                    name => sideWidgetsRoot.rightAnchoredWidgets.includes(name))
                delegate: SideWidgetDelegate { anchorRight: true }
            }
        }
    }

    SideWidgets {
        id: leftWidgets
        widgets: Config.options.bar.dynamicIsland.leftWidgets
        opacity: root.sessionExclusive ? 1 - root.sessionOpacity : 1
        rightAnchoredWidgets: Config.options.bar.dynamicIsland.leftRightAnchoredWidgets
        x: root.leftStart
        width: root.centerEnabled
            ? Math.max(implicitWidth, root.leftWingWidth - root.primaryWidth
                - (implicitWidth > 0 && root.primaryWidth > 0 ? root.widgetSpacing : 0))
            : implicitWidth
        anchors.verticalCenter: parent.verticalCenter
    }
    SideWidgets {
        id: rightWidgets
        widgets: Config.options.bar.dynamicIsland.rightWidgets
        opacity: root.sessionExclusive ? 1 - root.sessionOpacity : 1
        rightAnchoredWidgets: Config.options.bar.dynamicIsland.rightRightAnchoredWidgets
        x: root.centerEnabled
            ? root.centerX + root.centerHalfWidth + root.widgetSpacing
            : root.rightStart
        width: root.centerEnabled
            ? Math.max(implicitWidth, root.rightWingWidth)
            : implicitWidth
        anchors.verticalCenter: parent.verticalCenter
    }

    // Keep the center slot fixed to the screen center. The session menu can
    // replace only this slot, leaving both widget wings intact.
    Loader {
        id: centerLoader
        active: root.centerEnabled
        x: (root.sessionExclusive ? root.width / 2 - root.barCenterOffset : root.centerX)
            - implicitWidth / 2
        anchors.verticalCenter: parent.verticalCenter
        sourceComponent: centeredWidgetComponent
        opacity: root.sessionVisible ? 1 - root.sessionOpacity : 1
    }

    // Keep the original widgets loaded so size, position and fades share one timeline.
    MouseArea {
        anchors.fill: parent
        z: 10
        visible: root.sessionVisible
        enabled: root.sessionVisible
        acceptedButtons: Qt.AllButtons
    }

    Loader {
        id: sessionLoader
        active: root.sessionVisible && !root.vertical
        x: root.width / 2 - root.barCenterOffset - root.sessionWidth / 2
        anchors.verticalCenter: parent.verticalCenter
        z: 11
        sourceComponent: sessionComponent
        onLoaded: item?.forceActiveFocus()
    }

    Component {
        id: centeredWidgetComponent
        SideWidgetDelegate {
            modelData: root.centerWidget
            anchorRight: false
            // The fixed center stays interactive even while the island is collapsed.
            enabled: contentAvailable
        }
    }

    // Animate content widths at their source. The island and its positions follow
    // those widths directly, keeping both outer margins equal on every frame.
    Rectangle {
        id: pill
        x: root.centerEnabled
            ? root.centerX - root.centerHalfWidth
                - root.widgetSpacing - root.primaryWidth
            : root.leftStart + leftWidgets.implicitWidth
                + (leftWidgets.implicitWidth > 0 && root.primaryWidth > 0 ? root.widgetSpacing : 0)
        width: root.primaryWidth
        height: root.pillHeight
        color: "transparent"
        radius: height / 2
        clip: true
        visible: !root.vertical

        WheelHandler {
            id: idleToggleWheelHandler
            target: pill
            enabled: !root.sessionVisible
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            property bool coolingDown: false
            onWheel: (event) => {
                if (coolingDown) return
                coolingDown = true
                idleToggleDebounceTimer.restart()
                root.forceIdle = !root.forceIdle
            }
        }

        Timer {
            id: idleToggleDebounceTimer
            interval: 200
            onTriggered: idleToggleWheelHandler.coolingDown = false
        }

        Loader {
            id: contentLoader
            anchors.fill: parent
            sourceComponent: root.sessionExclusive ? emptyComponent
                : (root.pillProvider?.component ?? emptyComponent)
            active: !root.vertical

            onLoaded: {
                if (root.pillProvider?.id === "session" && item) {
                    item.forceActiveFocus()
                }
            }
        }

        Component {
            id: emptyComponent
            Item {}
        }

        Component {
            id: notificationComponent
            DiNotifs { di: root }
        }

        Component {
            id: timerComponent
            DiTimers { di: root }
        }

        Component {
            id: sessionComponent
            Item {
                implicitWidth: root.sessionWidth
                implicitHeight: root.pillHeight
                opacity: root.sessionOpacity
                scale: 0.94 + 0.06 * root.sessionOpacity
                enabled: GlobalStates.diSessionOpen
                DiSession { di: root }
            }
        }

        Component {
            id: recordingComponent
            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: root.isMaterial ? 4 : 8
                    rightMargin: 10
                }
                spacing: 6

                Item {
                    id: stopButton
                    Layout.alignment: Qt.AlignVCenter
                    implicitWidth: 16
                    implicitHeight: 16

                    MaterialSymbol {
                        anchors.fill: parent
                        text: "stop_circle"
                        fill: 1
                        iconSize: root.isMaterial ? 26 : 16
                        color: Appearance.colors.colError
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Quickshell.execDetached([Directories.recordScriptPath])
                    }
                }

                Item { Layout.fillWidth: true }

                StyledText {
                    Layout.alignment: Qt.AlignVCenter
                    text: root.formatRecordingTime(root.recordingElapsedSeconds)
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.features: { "tnum": 1 }
                    color: Appearance.colors.colOnLayer0
                }
            }
        }

        Component {
            id: batteryComponent
            RowLayout {
                anchors {
                    fill: parent
                    leftMargin: 10
                    rightMargin: 10
                }
                spacing: 6

                StyledText {
                    Layout.alignment: Qt.AlignVCenter
                    text: root.batteryStatusText()
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                    color: root.batteryAlertColor()
                }

                Item { Layout.fillWidth: true }

                MaterialSymbol {
                    Layout.alignment: Qt.AlignVCenter
                    text: root.batteryIcon()
                    fill: 1
                    iconSize: 16
                    color: root.batteryAlertColor()
                }

                StyledText {
                    Layout.alignment: Qt.AlignVCenter
                    text: `${Math.round(Battery.percentage * 100)}`
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.features: { "tnum": 1 }
                    color: root.batteryAlertColor()
                }
            }
        }
    }

}
