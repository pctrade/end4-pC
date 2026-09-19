import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell.Io
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "userCard"
    hoverEnabled: true

    readonly property real snapWidth1: 132
    readonly property real snapWidth2: 276
    readonly property real snapWidth3: 276
    readonly property real snapWidth4: 420

    readonly property real snapHeight1: 120
    readonly property real snapHeight2: 120
    readonly property real snapHeight3: 252

    property string sizeMode: root.configEntry.sizeMode ?? "2x2"

    property real widgetWidth: {
        switch (root.sizeMode) {
            case "1x1": return snapWidth1
            case "1x2": return snapWidth2
            case "2x3": return snapWidth4
            default:    return snapWidth3
        }
    }
    property real widgetHeight: {
        switch (root.sizeMode) {
            case "1x1": return snapHeight1
            case "1x2": return snapHeight2
            default:    return snapHeight3
        }
    }

    readonly property real heightToggleFraction: 0.3
    readonly property real heightToggleDelta: (root.snapHeight3 - root.snapHeight2) * root.heightToggleFraction
    readonly property real wideThreshold: (root.snapWidth3 + root.snapWidth4) / 2

    function modeForDrag(dx, dy, startWidth) {
        var mid = (root.snapWidth1 + root.snapWidth2) / 2
        var newWidth = startWidth + dx

        if (newWidth < mid) return "1x1"

        if (root.sizeMode === "1x1") {
            return dy > root.heightToggleDelta ? "2x2" : "1x2"
        }

        if (dy > root.heightToggleDelta) {
            return newWidth > root.wideThreshold ? "2x3" : "2x2"
        }
        if (dy < -root.heightToggleDelta) return "1x2"

        if (root.sizeMode === "2x2" || root.sizeMode === "2x3") {
            return newWidth > root.wideThreshold ? "2x3" : "2x2"
        }
        return root.sizeMode
    }

    property int avatarSize: 64
    property int blurMargin: 18
    property string hostname: SystemInfo.hostname
    property string username: Config.options.profile.displayName === "" ? SystemInfo.username : Config.options.profile.displayName
    property string userDisplay: username.length > 10 ? username : (username + "@" + hostname)
    property var currentQuip: weatherQuip()

    function weatherQuip() {
        const desc = (Weather.data?.description ?? "").toLowerCase();
        const temp = Weather.data?.temp ?? "--";
        if (desc.includes("rain"))
            return { text: `• raining, grab a coffee`, icon: "coffee" };
        if (desc.includes("clear"))
            return { text: `• good day to touch grass`, icon: "eco" };
        if (desc.includes("cloud"))
            return { text: `• a bit cloudy today`, icon: "cloud" };
        if (desc.includes("snow"))
            return { text: `• snowing`, icon: "ac_unit" };
        return { text: `• ${Weather.data?.description ?? ""}`, icon: "thermostat" };
    }

    function greetingFor(hour) {
        if (hour < 12) return "Good Morning"
        if (hour < 18) return "Good Afternoon"
        return "Good Evening"
    }

    readonly property string greetingText: greetingFor(DateTime.hour24)
    readonly property string todayString: "Today • " + DateTime.clock.date.toLocaleDateString(Qt.locale(), "dddd d MMM")

    // Uptime split into days / hours / minutes for the 2x3 stats row
    property int uptimeSeconds: 0
    readonly property int uptimeDays: Math.floor(root.uptimeSeconds / 86400)
    readonly property int uptimeHours: Math.floor((root.uptimeSeconds % 86400) / 3600)
    readonly property int uptimeMinutes: Math.floor((root.uptimeSeconds % 3600) / 60)

    Process {
        id: uptimeProc
        command: ["cat", "/proc/uptime"]
        stdout: StdioCollector {
            onStreamFinished: {
                const secs = parseFloat(text.trim().split(" ")[0])
                if (!isNaN(secs)) root.uptimeSeconds = Math.floor(secs)
            }
        }
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: uptimeProc.running = true
    }

    implicitWidth:  card.implicitWidth
    implicitHeight: card.implicitHeight

    Behavior on widgetWidth {
        animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
    }
    Behavior on widgetHeight {
        animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
    }

    component AvatarImage: Image {
        source: Config.options.profile.avatarPath !== ""
            ? "file://" + Config.options.profile.avatarPicture
            : "file:///home/" + (Quickshell.env("USER") ?? "user") + "/.face"
        sourceSize.width: width * 2
        sourceSize.height: height * 2
        fillMode: Image.PreserveAspectCrop
        onStatusChanged: if (status === Image.Error) visible = false
    }

    Rectangle {
        id: card
        implicitWidth: root.widgetWidth
        implicitHeight: root.widgetHeight
        radius: Appearance.rounding?.verylarge ?? 30
        color: "transparent"

        StyledRectangularShadow {
            target: card
            z: -2
        }

        Loader {
            anchors.fill: parent
            sourceComponent: {
                if (root.sizeMode === "1x1") return oneByOneContent
                if (root.sizeMode === "1x2") return oneByTwoContent
                if (root.sizeMode === "2x3") return twoByThreeContent
                return twoByTwoContent
            }
        }

        // 1x1
        Component {
            id: oneByOneContent
            Item {
                id: avatarSingleWrap
                anchors.fill: parent
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: avatarSingleWrap.width
                        height: avatarSingleWrap.height
                        radius: Appearance.rounding?.verylarge ?? 30
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    color: Appearance.colors.colLayer0
                }

                AvatarImage {
                    id: avatarSingle
                    anchors.fill: parent
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "account_circle"
                    iconSize: 32
                    color: Appearance.colors.colOnPrimaryContainer
                    visible: avatarSingle.status === Image.Error
                }
            }
        }

        // 1x2
        Component {
            id: oneByTwoContent
            Rectangle {
                anchors.fill: parent
                radius: Appearance.rounding?.verylarge ?? 30
                color: Appearance.colors.colPrimaryContainer

                FastBlurred {
                    anchors.fill: parent
                    blurSource: root.wallpaperItem
                    cardRadius: card.radius
                    tint: Appearance.colors.colLayer1
                    tintOpacity: 0.55
                    trackX: root.x  
                    trackY: root.y
                    visible: Config.options.background.widgets.blurWidgets 
                }

                RowLayout {
                    anchors { fill: parent; margins: 10 }
                    spacing: 12

                    Item {
                        id: avatarWideWrap
                        Layout.preferredWidth: parent.height
                        Layout.preferredHeight: parent.height 
                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: Rectangle {
                                width: avatarWideWrap.width
                                height: avatarWideWrap.height
                                radius: (Appearance.rounding?.verylarge ?? 30) - 6
                            }
                        }

                        Rectangle {
                            anchors.fill: parent
                            color: Appearance.colors.colLayer0
                        }

                        AvatarImage {
                            id: avatarWide
                            anchors.fill: parent
                        }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "account_circle"
                            iconSize: 32
                            color: Appearance.colors.colOnPrimaryContainer
                            visible: avatarWide.status === Image.Error
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        spacing: 2

                        Item { Layout.fillHeight: true }

                        StyledText {
                            Layout.fillWidth: true
                            text: "Hi, " + root.username + "!"
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.Bold
                            color: Appearance.colors.colOnPrimaryContainer
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: root.greetingText
                            font.pixelSize: Appearance.font.pixelSize.small
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.8
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: root.todayString
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.6
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        // 2x2 (original design)
        Component {
            id: twoByTwoContent
            Item {
                id: outerRect
                implicitWidth: root.snapWidth3
                implicitHeight: root.snapHeight3

                Item {
                    id: bgImage
                    anchors.fill: parent
                    visible: false

                    // Only feeds the FastBlur used when widget blur is off
                    property string effectiveSource: Config.options.background.widgets.blurWidgets ? "" : "file://" + (GlobalStates.screenLocked && Config.options.background.lockWall !== ""
                        ? Config.options.background.lockWall
                        : Config.options.background.wallpaperPath)

                    Image {
                        id: bgImageA
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(root.snapWidth3, root.snapHeight3)
                        asynchronous: true
                        cache: false
                        opacity: 1
                        Behavior on opacity {
                            NumberAnimation { duration: 400; easing.type: Easing.InOutCubic }
                        }
                    }
                    Image {
                        id: bgImageB
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(root.snapWidth3, root.snapHeight3)
                        asynchronous: true
                        cache: false
                        opacity: 0
                        Behavior on opacity {
                            NumberAnimation { duration: 400; easing.type: Easing.InOutCubic }
                        }
                    }

                    property bool usingA: true

                    onEffectiveSourceChanged: {
                        if (usingA) {
                            bgImageB.source = effectiveSource
                            bgImageB.opacity = 1
                            bgImageA.opacity = 0
                        } else {
                            bgImageA.source = effectiveSource
                            bgImageA.opacity = 1
                            bgImageB.opacity = 0
                        }
                        usingA = !usingA
                    }

                    Component.onCompleted: {
                        bgImageA.source = effectiveSource
                    }
                }

                FastBlur {
                    id: blurredBg
                    anchors.fill: bgImage
                    visible: !Config.options.background.widgets.blurWidgets 
                    source: bgImage
                    radius: 48
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: outerRect.width
                            height: outerRect.height
                            radius: Appearance.rounding?.verylarge ?? 30
                        }
                    }
                }

                FastBlurred {
                    anchors.fill: parent
                    blurSource: root.wallpaperItem
                    cardRadius: Appearance.rounding?.verylarge ?? 30
                    tint: Appearance.colors.colLayer1
                    tintOpacity: 0.55
                    trackX: root.x  
                    trackY: root.y
                    visible: Config.options.background.widgets.blurWidgets 
                }

                Rectangle {
                    anchors.fill: blurredBg
                    radius: Appearance.rounding?.verylarge ?? 30
                    color: Appearance.colors.colScrim
                    opacity: 0.1
                }

                Rectangle {
                    id: contentBox
                    x: root.blurMargin
                    y: root.avatarSize / 2 + root.blurMargin + 30
                    width: 240
                    color: Appearance.colors.colPrimaryContainer
                    radius: Appearance.rounding.large
                    implicitHeight: contentColumn.implicitHeight + 30

                    ColumnLayout {
                        id: contentColumn
                        anchors {
                            top: parent.top
                            left: parent.left
                            right: parent.right
                            margins: 16
                        }
                        Layout.topMargin: root.avatarSize / 2 + 4
                        spacing: 10

                        Item {
                            Layout.fillWidth: true
                            Layout.preferredHeight: root.avatarSize / 2
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 6

                            MaterialSymbol {
                                Layout.alignment: Qt.AlignTop
                                Layout.topMargin: 2
                                iconSize: Appearance.font.pixelSize.normal
                                text: root.currentQuip.icon
                                color: Appearance.colors.colOnPrimaryContainer
                                opacity: 0.85
                            }

                            StyledText {
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOnPrimaryContainer
                                opacity: 0.85
                                text: root.currentQuip.text
                            }
                        } 

                        RowLayout {
                            Layout.fillWidth: true
                            Layout.topMargin: 4
                            spacing: 8

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 40
                                radius: Appearance.rounding.full
                                color: Appearance.colors.colOnPrimaryContainer

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    MaterialSymbol {
                                        iconSize: Appearance.font.pixelSize.normal
                                        text: "lock"
                                        color: Appearance.colors.colPrimaryContainer
                                    }
                                    StyledText {
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        font.weight: Font.DemiBold
                                        color: Appearance.colors.colPrimaryContainer
                                        text: GlobalStates.screenLocked ? "Locked" : "Lock"
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: GlobalStates.screenLocked = true
                                }
                            }

                            Rectangle {
                                implicitWidth: 40
                                implicitHeight: 40
                                radius: 20
                                color: "transparent"
                                border.width: 1
                                border.color: Appearance.colors.colOnPrimaryContainer
                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    iconSize: Appearance.font.pixelSize.normal
                                    text: "settings"
                                    color: Appearance.colors.colOnPrimaryContainer
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: GlobalStates.settingsOpen = true
                                }
                            }

                            Rectangle {
                                implicitWidth: 40
                                implicitHeight: 40
                                radius: 20
                                color: "transparent"
                                border.width: 1
                                border.color: Appearance.colors.colOnPrimaryContainer
                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    iconSize: Appearance.font.pixelSize.normal
                                    text: "power_settings_new"
                                    color: Appearance.colors.colOnPrimaryContainer
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: GlobalStates.sessionOpen = true
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    id: avatarRect
                    x: root.blurMargin + 16
                    y: contentBox.y - root.avatarSize / 2
                    width: root.avatarSize + 10
                    height: root.avatarSize + 10
                    radius: width / 2
                    color: Appearance.colors.colPrimaryContainer
                    border.width: 3
                    border.color: Appearance.colors.colLayer1
                    z: 2

                    Image {
                        id: avatarImage
                        anchors.fill: parent
                        anchors.margins: 3
                        source: Config.options.profile.avatarPath !== ""
                            ? "file://" + Config.options.profile.avatarPicture
                            : "file:///home/" + (Quickshell.env("USER") ?? "user") + "/.face"
                        sourceSize.width: avatarImage.width * 2
                        sourceSize.height: avatarImage.height * 2
                        fillMode: Image.PreserveAspectCrop
                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: Rectangle {
                                width: avatarRect.width - 6
                                height: avatarRect.height - 6
                                radius: (avatarRect.width - 6) / 2
                            }
                        }
                        onStatusChanged: {
                            if (status === Image.Error)
                                visible = false
                        }
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "account_circle"
                        iconSize: 32
                        color: Appearance.colors.colOnPrimaryContainer
                        visible: avatarImage.status === Image.Error
                    }
                }

                ColumnLayout {
                    x: avatarRect.x + avatarRect.width + 13
                    y: avatarRect.y + (avatarRect.height - implicitHeight) / 2 + 20
                    spacing: 0
                    z: 2
                    width: outerRect.width - x - root.blurMargin

                    StyledText {
                        Layout.fillWidth: true
                        text: root.userDisplay
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer1
                        elide: Text.ElideRight
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: "Up • " + DateTime.uptime
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnLayer1
                        opacity: 0.6
                        elide: Text.ElideRight
                    }
                }
            }
        }

        // 2x3
        Component {
            id: twoByThreeContent
            Item {
                id: outerRect3
                implicitWidth: root.snapWidth4
                implicitHeight: root.snapHeight3

                Rectangle {
                    id: cardBg
                    anchors.fill: parent
                    radius: Appearance.rounding?.verylarge ?? 30
                    color: Appearance.colors.colPrimaryContainer
                    clip: true

                    FastBlurred {
                        anchors.fill: parent
                        blurSource: root.wallpaperItem
                        cardRadius: cardBg.radius
                        tint: Appearance.colors.colLayer1
                        tintOpacity: 0.55
                        trackX: root.x
                        trackY: root.y
                        visible: Config.options.background.widgets.blurWidgets
                    }

                    Item {
                        id: heroWrap
                        anchors {
                            top: parent.top
                            left: parent.left
                            right: parent.right
                        }
                        height: cardBg.height * 0.62
                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: Rectangle {
                                width: heroWrap.width
                                height: heroWrap.height
                                topLeftRadius: cardBg.radius
                                topRightRadius: cardBg.radius
                                gradient: Gradient {
                                    GradientStop { position: 0.0; color: "#ffffff" }
                                    GradientStop { position: 0.55; color: "#ffffff" }
                                    GradientStop { position: 1.0; color: "transparent" }
                                }
                            }
                        }

                        Image {
                            anchors.fill: parent
                            source: Config.options.sidebar.bannerImage || Config.options.background.wallpaperPath
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: false
                            sourceSize: Qt.size(root.snapWidth4, heroWrap.height)
                        }
                    }

                    // Tr settings button
                    Rectangle {
                        anchors {
                            top: parent.top
                            right: parent.right
                            margins: 12
                        }
                        width: 34
                        height: 34
                        radius: width / 2
                        color: ColorUtils.transparentize(Appearance.colors.colLayer0, 0.15)
                        z: 3

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "settings"
                            iconSize: 18
                            color: Appearance.colors.colOnLayer0
                        }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: GlobalStates.settingsOpen = true
                        }
                    }

                    // Avatar overlapping
                    Rectangle {
                        id: avatarRect3
                        x: 16
                        y: heroWrap.height - 70
                        width: root.avatarSize + 10
                        height: root.avatarSize + 10
                        radius: width / 2
                        color: Appearance.colors.colPrimaryContainer
                        border.width: 3
                        border.color: Appearance.colors.colLayer1
                        z: 2

                        Image {
                            id: avatarImage3
                            anchors.fill: parent
                            anchors.margins: 3
                            source: Config.options.profile.avatarPath !== ""
                                ? "file://" + Config.options.profile.avatarPicture
                                : "file:///home/" + (Quickshell.env("USER") ?? "user") + "/.face"
                            sourceSize.width: avatarImage3.width * 2
                            sourceSize.height: avatarImage3.height * 2
                            fillMode: Image.PreserveAspectCrop
                            layer.enabled: true
                            layer.effect: OpacityMask {
                                maskSource: Rectangle {
                                    width: avatarRect3.width - 6
                                    height: avatarRect3.height - 6
                                    radius: (avatarRect3.width - 6) / 2
                                }
                            }
                            onStatusChanged: if (status === Image.Error) visible = false
                        }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "account_circle"
                            iconSize: 32
                            color: Appearance.colors.colOnPrimaryContainer
                            visible: avatarImage3.status === Image.Error
                        }
                    }

                    // Labels + stats + lock/power
                    ColumnLayout {
                        anchors {
                            left: parent.left
                            right: parent.right
                            top: avatarRect3.bottom
                            bottom: parent.bottom
                            leftMargin: 16
                            rightMargin: 16
                            topMargin: 6
                            bottomMargin: 12
                        }
                        spacing: 3

                        StyledText {
                            Layout.fillWidth: true
                            Layout.topMargin: -6
                            Layout.leftMargin: 4
                            text: root.userDisplay
                            font.pixelSize: Appearance.font.pixelSize.normal
                            font.weight: Font.Bold
                            color: Appearance.colors.colOnPrimaryContainer
                            elide: Text.ElideRight
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10

                            ColumnLayout {
                                spacing: 0
                                StyledText {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: root.uptimeDays
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                    font.weight: Font.Bold
                                    color: Appearance.colors.colOnPrimaryContainer
                                }
                                StyledText {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "days"
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colOnPrimaryContainer
                                    opacity: 0.6
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 1
                                Layout.preferredHeight: 28
                                color: Appearance.colors.colOnPrimaryContainer
                                opacity: 0.15
                            }

                            ColumnLayout {
                                spacing: 0
                                StyledText {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: root.uptimeHours
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                    font.weight: Font.Bold
                                    color: Appearance.colors.colOnPrimaryContainer
                                }
                                StyledText {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "hours"
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colOnPrimaryContainer
                                    opacity: 0.6
                                }
                            }

                            Rectangle {
                                Layout.preferredWidth: 1
                                Layout.preferredHeight: 28
                                color: Appearance.colors.colOnPrimaryContainer
                                opacity: 0.15
                            }

                            ColumnLayout {
                                spacing: 0
                                StyledText {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: root.uptimeMinutes
                                    font.pixelSize: Appearance.font.pixelSize.normal
                                    font.weight: Font.Bold
                                    color: Appearance.colors.colOnPrimaryContainer
                                }
                                StyledText {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "min"
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colOnPrimaryContainer
                                    opacity: 0.6
                                }
                            }

                            Item { Layout.fillWidth: true }

                            Rectangle {
                                Layout.fillWidth: true
                                implicitHeight: 36
                                radius: Appearance.rounding.full
                                color: Appearance.colors.colOnPrimaryContainer

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 4
                                    MaterialSymbol {
                                        iconSize: Appearance.font.pixelSize.normal
                                        text: "lock"
                                        color: Appearance.colors.colPrimaryContainer
                                    }
                                    StyledText {
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        font.weight: Font.DemiBold
                                        color: Appearance.colors.colPrimaryContainer
                                        text: GlobalStates.screenLocked ? "Locked" : "Lock"
                                    }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: GlobalStates.screenLocked = true
                                }
                            }

                            Rectangle {
                                implicitWidth: 36
                                implicitHeight: 36
                                radius: 18
                                color: "transparent"
                                border.width: 1
                                border.color: Appearance.colors.colOnPrimaryContainer

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    iconSize: Appearance.font.pixelSize.normal
                                    text: "power_settings_new"
                                    color: Appearance.colors.colOnPrimaryContainer
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: GlobalStates.sessionOpen = true
                                }
                            }
                        }
                    }
                }
            }
        }

        ResizeHandler {
            anchorItem: card
            hoverActive: root.containsMouse
            locked: Config.options.background.widgetsLocked
            currentWidth: root.widgetWidth
            resizeMode: "diagonal"
            onResizedXY: (dx, dy, startWidth) => { root.sizeMode = root.modeForDrag(dx, dy, startWidth) }
            onResizeFinished: {
                root.configEntry.sizeMode = root.sizeMode
            }
        }
    }
}