import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell.Io
import Quickshell
import qs
import qs.services
import qs.modules.common
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

    readonly property real snapHeight1: 120
    readonly property real snapHeight2: 120
    readonly property real snapHeight3: 252

    property string sizeMode: root.configEntry.sizeMode ?? "2x2"

    property real widgetWidth: {
        switch (root.sizeMode) {
            case "1x1": return snapWidth1
            case "1x2": return snapWidth2
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

    function modeForDrag(dx, dy, startWidth) {
        var mid = (root.snapWidth1 + root.snapWidth2) / 2
        var newWidth = startWidth + dx

        if (newWidth < mid) return "1x1"

        if (root.sizeMode === "1x1") {
            return dy > root.heightToggleDelta ? "2x2" : "1x2"
        }
        if (dy > root.heightToggleDelta) return "2x2"
        if (dy < -root.heightToggleDelta) return "1x2"
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

                    property string effectiveSource: "file://" + (GlobalStates.screenLocked && Config.options.background.lockWall !== ""
                        ? Config.options.background.lockWall
                        : Config.options.background.wallpaperPath)

                    Image {
                        id: bgImageA
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
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

                    StyledText {
                        text: root.userDisplay
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnLayer1
                    }
                    StyledText {
                        text: "Up • " + DateTime.uptime
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: Appearance.colors.colOnLayer1
                        opacity: 0.6
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