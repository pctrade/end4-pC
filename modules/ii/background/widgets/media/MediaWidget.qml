import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import qs
import qs.services
import Qt5Compat.GraphicalEffects
import qs.modules.common
import qs.modules.common.models
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root

    signal requestReset()

    configEntryName: "media"
    hoverEnabled: true

    readonly property var playerList: MprisController.players
    property MprisPlayer currentPlayer: {
        const preferred = Config.options.bar.media.preferredPlayer.trim().toLowerCase()
        if (preferred.length === 0) return MprisController.activePlayer
        const _ = MprisController.players.count
        for (const p of MprisController.players) {
            if ((p.identity ?? "").toLowerCase().includes(preferred) ||
                (p.desktopEntry ?? "").toLowerCase().includes(preferred))
                return p
        }
        return MprisController.activePlayer
    }
    property var artUrl: currentPlayer?.trackArtUrl
    property string artDownloadLocation: Directories.coverArt
    property string artFileName: Qt.md5(artUrl)
    property string artFilePath: `${artDownloadLocation}/${artFileName}`

    property real buttonSize: 34
    property real buttonIconSize: 18

    readonly property real mediaProgress: {
        const pos = root.currentPlayer?.position ?? 0
        const len = root.currentPlayer?.length ?? 0
        return len > 0 ? Math.max(0, Math.min(1, pos / len)) : 0
    }

    readonly property real cardSpacing: 12
    readonly property real singleWidth: 132
    readonly property real cardHeight: 120
    readonly property real doubleCardHeight: root.cardHeight * 2 + root.cardSpacing

    readonly property real snapWidth1: root.singleWidth
    readonly property real snapWidth2: root.singleWidth * 2 + root.cardSpacing
    readonly property real snapWidth3: root.singleWidth * 3 + root.cardSpacing * 2

    property string sizeMode: root.configEntry.sizeMode ?? "1x3"

    property real widgetWidth: {
        switch (root.sizeMode) {
            case "1x1": return root.snapWidth1
            case "1x2": return root.snapWidth2
            case "2x2": return root.snapWidth2
            case "2x3": return root.snapWidth3
            default:    return root.snapWidth3
        }
    }

    function modeForWidth(value) {
        var mid1 = (root.snapWidth1 + root.snapWidth2) / 2
        var mid2 = (root.snapWidth2 + root.snapWidth3) / 2
        if (value < mid1) return "1x1"
        if (value < mid2) return "1x2"
        return "1x3"
    }

    readonly property real heightEnterFraction: 0.2
    readonly property real heightEnterDelta: (root.doubleCardHeight - root.cardHeight) * root.heightEnterFraction

    function modeForDrag(dx, dy, startWidth) {
        if (dy > root.heightEnterDelta) {
            if (root.sizeMode === "1x3" || root.sizeMode === "2x3") return "2x3"
            if (root.sizeMode === "1x2" || root.sizeMode === "2x2") return "2x2"
        }
        return root.modeForWidth(startWidth + dx)
    }

    Behavior on widgetWidth {
        animation: Appearance.animation.elementResize.numberAnimation.createObject(this)
    }

    property bool downloaded: false
    property bool showLyrics: false

    property string displayedArtFilePath: {
        if (!root.downloaded) return ""
        if (root.artUrl && root.artUrl.startsWith("file://")) return root.artUrl
        return root.downloaded ? Qt.resolvedUrl(artFilePath) : ""
    }

    implicitHeight: card.implicitHeight
    implicitWidth: card.implicitWidth

    onArtFilePathChanged: updateArt()

    function updateArt() {
        if (!root.artUrl || root.artUrl.length === 0) {
            root.downloaded = false
            return
        }
        if (root.artUrl.startsWith("file://")) {
            root.downloaded = true
            return
        }
        coverArtDownloader.targetFile = root.artUrl
        coverArtDownloader.artFilePath = root.artFilePath
        root.downloaded = false
        coverArtDownloader.running = true
    }

    Process {
        id: coverArtDownloader
        property string targetFile: root.artUrl
        property string artFilePath: root.artFilePath
        command: ["bash", "-c", `[ -f ${artFilePath} ] || curl -sSL '${targetFile}' -o '${artFilePath}'`]
        onExited: { root.downloaded = true }
    }

    StyledRectangularShadow {
        target: card
        z: -2
    }

    Rectangle {
        id: card
        implicitWidth: root.widgetWidth
        implicitHeight: (root.sizeMode === "2x3" || root.sizeMode === "2x2")
            ? root.doubleCardHeight
            : (root.cardHeight + (root.sizeMode === "1x3" && root.showLyrics ? 264 : 0))
        radius: Appearance.rounding?.verylarge ?? 30
        color: Appearance.colors.colPrimaryContainer
        clip: true

        Behavior on implicitHeight {
            NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
        }

        Loader {
            anchors.fill: parent
            sourceComponent: {
                if (root.sizeMode === "1x1") return oneByOneContent
                if (root.sizeMode === "1x2") return oneByTwoContent
                if (root.sizeMode === "2x2") return twoByTwoContent
                if (root.sizeMode === "2x3") return twoByThreeContent
                return oneByThreeContent
            }
        }

        // 1x1
        Component {
            id: oneByOneContent
            Item {
                id: squareArt
                anchors.fill: parent
                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: squareArt.width
                        height: squareArt.height
                        radius: card.radius
                    }
                }

                StyledImage {
                    anchors.fill: parent
                    source: root.displayedArtFilePath
                    fillMode: Image.PreserveAspectCrop
                    cache: false
                    antialiasing: true
                    sourceSize.width: root.singleWidth * 2
                    sourceSize.height: root.cardHeight * 2
                    visible: root.displayedArtFilePath !== ""
                }

                MaterialSymbol {
                    anchors.centerIn: parent
                    fill: 1
                    text: "music_note"
                    iconSize: root.cardHeight / 3
                    color: Appearance.colors.colOnSecondaryContainer
                    visible: root.displayedArtFilePath === ""
                }

                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "transparent" }
                        GradientStop { position: 0.5; color: ColorUtils.transparentize("#000000", 0.85) }
                        GradientStop { position: 1.0; color: ColorUtils.transparentize("#000000", 0.1) }
                    }
                }

                RowLayout {
                    anchors {
                        bottom: parent.bottom
                        horizontalCenter: parent.horizontalCenter
                        bottomMargin: 10
                    }
                    spacing: 4
                    visible: MprisController.activePlayer !== null

                    RippleButton {
                        implicitWidth: 26
                        implicitHeight: 26
                        buttonRadius: Appearance.rounding?.full ?? 999
                        colBackground: "transparent"
                        colBackgroundHover: ColorUtils.transparentize("#ffffff", 0.8)
                        colRipple: ColorUtils.transparentize("#ffffff", 0.7)
                        downAction: () => root.currentPlayer?.previous()

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "skip_previous"
                            iconSize: 16
                            fill: 1
                            color: Appearance.colors.colPrimary
                        }
                    }

                    MaterialShapeWrappedMaterialSymbol {
                        shape: MaterialShape.Shape.Cookie12Sided
                        color: Appearance.colors.colPrimary
                        colSymbol: Appearance.colors.colOnPrimary
                        text: root.currentPlayer?.isPlaying ? "pause" : "play_arrow"
                        iconSize: 18
                        fill: 1
                        padding: 6

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.currentPlayer?.togglePlaying()
                        }
                    }

                    RippleButton {
                        implicitWidth: 26
                        implicitHeight: 26
                        buttonRadius: Appearance.rounding?.full ?? 999
                        colBackground: "transparent"
                        colBackgroundHover: ColorUtils.transparentize("#ffffff", 0.8)
                        colRipple: ColorUtils.transparentize("#ffffff", 0.7)
                        downAction: () => root.currentPlayer?.next()

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "skip_next"
                            iconSize: 16
                            fill: 1
                            color: Appearance.colors.colPrimary
                        }
                    }
                }
            }
        }

        // 1x2
        Component {
            id: oneByTwoContent
            RowLayout {
                anchors.fill: parent
                spacing: 0

                Rectangle {
                    id: artBlock
                    Layout.fillHeight: true
                    Layout.preferredWidth: root.cardHeight
                    color: Appearance.colors.colSurfaceContainerLow
                    topLeftRadius: card.radius
                    bottomLeftRadius: card.radius
                    topRightRadius: 0
                    bottomRightRadius: 0
                    clip: true
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: artBlock.width
                            height: artBlock.height
                            topLeftRadius: card.radius
                            bottomLeftRadius: card.radius
                            topRightRadius: 0
                            bottomRightRadius: 0
                        }
                    }

                    StyledImage {
                        anchors.fill: parent
                        source: root.displayedArtFilePath
                        fillMode: Image.PreserveAspectCrop
                        cache: false
                        antialiasing: true
                        sourceSize.width: artBlock.width * 2
                        sourceSize.height: artBlock.height * 2
                        visible: root.displayedArtFilePath !== ""
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        fill: 1
                        text: "music_note"
                        iconSize: root.cardHeight / 3
                        color: Appearance.colors.colOnSecondaryContainer
                        visible: root.displayedArtFilePath === ""
                    }
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.leftMargin: 14
                    Layout.rightMargin: 12
                    Layout.topMargin: 12
                    Layout.bottomMargin: 10
                    spacing: 4

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        StyledText {
                            Layout.fillWidth: true
                            text: root.currentPlayer?.trackArtist ?? "Play"
                            font.pixelSize: Appearance.font.pixelSize.small
                            font.weight: Font.DemiBold
                            color: Appearance.colors.colOnPrimaryContainer
                            elide: Text.ElideRight
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: root.currentPlayer?.trackTitle ?? Translation.tr("Something")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnPrimaryContainer
                            opacity: 0.6
                            elide: Text.ElideRight
                        }
                    }

                    Item { Layout.fillHeight: true }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignHCenter
                        spacing: 4

                        RippleButton {
                            implicitWidth: 28
                            implicitHeight: 28
                            buttonRadius: Appearance.rounding?.full ?? 999
                            colBackground: "transparent"
                            colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                            colRipple: Appearance.colors.colPrimaryContainerActive
                            downAction: () => root.currentPlayer?.previous()

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "skip_previous"
                                iconSize: root.buttonIconSize - 2
                                fill: 1
                                color: Appearance.colors.colOnPrimaryContainer
                            }
                        }

                        MaterialShapeWrappedMaterialSymbol {
                            shape: MaterialShape.Shape.Cookie12Sided
                            color: Appearance.colors.colPrimary
                            colSymbol: Appearance.colors.colOnPrimary
                            text: root.currentPlayer?.isPlaying ? "pause" : "play_arrow"
                            iconSize: root.buttonIconSize + 4
                            fill: 1
                            padding: 7

                            MouseArea {
                                anchors.fill: parent
                                onClicked: root.currentPlayer?.togglePlaying()
                            }
                        }

                        RippleButton {
                            implicitWidth: 28
                            implicitHeight: 28
                            buttonRadius: Appearance.rounding?.full ?? 999
                            colBackground: "transparent"
                            colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                            colRipple: Appearance.colors.colPrimaryContainerActive
                            downAction: () => root.currentPlayer?.next()

                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: "skip_next"
                                iconSize: root.buttonIconSize - 2
                                fill: 1
                                color: Appearance.colors.colOnPrimaryContainer
                            }
                        }
                    }
                }
            }
        }

        // 2x2
        Component {
            id: twoByTwoContent
            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // Art 
                Rectangle {
                    id: bigArt
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Appearance.colors.colSurfaceContainerLow
                    topLeftRadius: card.radius
                    topRightRadius: card.radius
                    bottomLeftRadius: 0
                    bottomRightRadius: 0
                    clip: true
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: bigArt.width
                            height: bigArt.height
                            topLeftRadius: card.radius
                            topRightRadius: card.radius
                            bottomLeftRadius: 0
                            bottomRightRadius: 0
                        }
                    }

                    StyledImage {
                        anchors.fill: parent
                        source: root.displayedArtFilePath
                        fillMode: Image.PreserveAspectCrop
                        cache: false
                        antialiasing: true
                        sourceSize.width: bigArt.width * 2
                        sourceSize.height: bigArt.height * 2
                        visible: root.displayedArtFilePath !== ""
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        fill: 1
                        text: "music_note"
                        iconSize: root.cardHeight / 2.5
                        color: Appearance.colors.colOnSecondaryContainer
                        visible: root.displayedArtFilePath === ""
                    }
                }

                // Artist / title
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 14
                    Layout.rightMargin: 14
                    Layout.topMargin: 10
                    spacing: 2

                    StyledText {
                        Layout.fillWidth: true
                        text: root.currentPlayer?.trackArtist ?? "Play"
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colOnPrimaryContainer
                        elide: Text.ElideRight
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: root.currentPlayer?.trackTitle ?? Translation.tr("Something")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.65
                        elide: Text.ElideRight
                    }
                }

                // Controls
                RowLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    Layout.topMargin: 8
                    Layout.bottomMargin: 12
                    spacing: 6

                    RippleButton {
                        implicitWidth: 28
                        implicitHeight: 28
                        buttonRadius: Appearance.rounding?.full ?? 999
                        colBackground: "transparent"
                        colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                        colRipple: Appearance.colors.colPrimaryContainerActive
                        downAction: () => root.currentPlayer?.previous()

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "skip_previous"
                            iconSize: root.buttonIconSize - 2
                            fill: 1
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                    }

                    MaterialShapeWrappedMaterialSymbol {
                        shape: MaterialShape.Shape.Cookie12Sided
                        color: Appearance.colors.colPrimary
                        colSymbol: Appearance.colors.colOnPrimary
                        text: root.currentPlayer?.isPlaying ? "pause" : "play_arrow"
                        iconSize: root.buttonIconSize + 6
                        fill: 1
                        padding: 8

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.currentPlayer?.togglePlaying()
                        }
                    }

                    RippleButton {
                        implicitWidth: 28
                        implicitHeight: 28
                        buttonRadius: Appearance.rounding?.full ?? 999
                        colBackground: "transparent"
                        colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                        colRipple: Appearance.colors.colPrimaryContainerActive
                        downAction: () => root.currentPlayer?.next()

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: "skip_next"
                            iconSize: root.buttonIconSize - 2
                            fill: 1
                            color: Appearance.colors.colOnPrimaryContainer
                        }
                    }
                }
            }
        }

        // 1x3
        Component {
            id: oneByThreeContent
            Column {
                anchors.fill: parent
                spacing: 0

                // Main Row
                Item {
                    width: parent.width
                    height: root.cardHeight

                    Rectangle {
                        id: artRect
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: root.cardHeight
                        color: Appearance.colors.colSurfaceContainerLow
                        topLeftRadius: card.radius
                        bottomLeftRadius: card.radius
                        topRightRadius: 0
                        bottomRightRadius: 0
                        clip: true
                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: Rectangle {
                                width: artRect.width
                                height: artRect.height
                                topLeftRadius: card.radius
                                bottomLeftRadius: card.radius
                                topRightRadius: 0
                                bottomRightRadius: 0
                            }
                        }

                        StyledImage {
                            anchors.fill: parent
                            source: root.displayedArtFilePath
                            fillMode: Image.PreserveAspectCrop
                            cache: false
                            antialiasing: true
                            sourceSize.width: artRect.width * 2
                            sourceSize.height: artRect.height * 2
                            visible: root.displayedArtFilePath !== ""
                        }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            fill: 1
                            text: "music_note"
                            iconSize: root.cardHeight / 3
                            color: Appearance.colors.colOnSecondaryContainer
                            visible: root.displayedArtFilePath === ""
                        }
                    }

                    ColumnLayout {
                        anchors {
                            left: artRect.right
                            right: parent.right
                            top: parent.top
                            bottom: parent.bottom
                            leftMargin: 16
                            rightMargin: 14
                        }
                        spacing: -10

                        // Artist + Title
                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2

                            StyledText {
                                Layout.fillWidth: true
                                text: root.currentPlayer?.trackArtist ?? "Play"
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.DemiBold
                                color: Appearance.colors.colOnPrimaryContainer
                                elide: Text.ElideRight
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: root.currentPlayer?.trackTitle ?? Translation.tr("Something")
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOnPrimaryContainer
                                opacity: 0.65
                                elide: Text.ElideRight
                            }
                        }

                        // Controls 
                        Rectangle {
                            id: controlsPill
                            Layout.alignment: Qt.AlignRight
                            implicitWidth: controlsRow.implicitWidth + 10
                            implicitHeight: root.buttonSize + 8
                            radius: Appearance.rounding?.full ?? 999
                            color: ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.9)

                            RowLayout {
                                id: controlsRow
                                anchors.centerIn: parent
                                spacing: 2
                        
                                RippleButton {
                                    implicitWidth: root.buttonSize
                                    implicitHeight: root.buttonSize
                                    buttonRadius: Appearance.rounding?.full ?? 999
                                    colBackground: root.showLyrics
                                        ? Appearance.colors.colPrimary
                                        : "transparent"
                                    colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                                    colRipple: Appearance.colors.colPrimaryContainerActive
                                    downAction: () => { root.showLyrics = !root.showLyrics }

                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: "lyrics"
                                        iconSize: root.buttonIconSize
                                        fill: root.showLyrics ? 1 : 0
                                        color: root.showLyrics
                                            ? Appearance.colors.colOnPrimary
                                            : Appearance.colors.colOnPrimaryContainer
                                    }
                                }

                                MaterialShapeWrappedMaterialSymbol {
                                    shape: MaterialShape.Shape.Cookie12Sided
                                    color: Appearance.colors.colPrimary
                                    colSymbol: Appearance.colors.colOnPrimary
                                    text: root.currentPlayer?.isPlaying ? "pause" : "play_arrow"
                                    iconSize: root.buttonIconSize + 12
                                    fill: 1
                                    padding: 8

                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: root.currentPlayer?.togglePlaying()
                                    }
                                }

                                RippleButton {
                                    implicitWidth: root.buttonSize
                                    implicitHeight: root.buttonSize
                                    buttonRadius: Appearance.rounding?.full ?? 999
                                    colBackground: "transparent"
                                    colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                                    colRipple: Appearance.colors.colPrimaryContainerActive
                                    downAction: () => root.currentPlayer?.next()
                                    altAction: () => root.currentPlayer?.previous()

                                    MaterialSymbol {
                                        anchors.centerIn: parent
                                        text: "skip_next"
                                        iconSize: root.buttonIconSize
                                        fill: 1
                                        color: Appearance.colors.colOnPrimaryContainer
                                    }
                                }
                            }
                        }
                    }
                }

                // Divisor
                Item {
                    width: parent.width
                    height: root.showLyrics ? 2 : 0
                    visible: root.showLyrics

                    Rectangle {
                        anchors.centerIn: parent
                        width: parent.width - 48
                        height: 1
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0.0; color: "transparent" }
                            GradientStop { position: 0.2; color: Appearance.colors.colOnPrimaryContainer }
                            GradientStop { position: 0.8; color: Appearance.colors.colOnPrimaryContainer }
                            GradientStop { position: 1.0; color: "transparent" }
                        }
                        opacity: 0.15
                    }
                }

                Item {
                    width: parent.width
                    height: root.showLyrics ? 250 : 0
                    visible: root.showLyrics

                    Lyrics {
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        textAlignment: Text.AlignHCenter
                        textColor: Appearance.colors.colOnPrimaryContainer
                        activeColor: Appearance.colors.colPrimary
                        dimColor: Appearance.colors.colSubtext
                        indicatorColor: Appearance.colors.colPrimary
                        indicatorShapeColor: Appearance.colors.colOnPrimary
                    }
                }
            }
        }

        // 2x3
        Component {
            id: twoByThreeContent

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                Rectangle {
                    id: labelArea
                    Layout.fillWidth: true
                    Layout.preferredHeight: 82
                    color: Appearance.colors.colSurfaceContainerLow
                    topLeftRadius: card.radius
                    topRightRadius: card.radius
                    bottomLeftRadius: 0
                    bottomRightRadius: 0

                    RowLayout {
                        anchors {
                            fill: parent
                            leftMargin: 14
                            rightMargin: 16
                            topMargin: 14
                            bottomMargin: 14
                        }
                        spacing: 12

                        Rectangle {
                            id: labelArt
                            Layout.preferredWidth: 54
                            Layout.preferredHeight: 54
                            Layout.alignment: Qt.AlignVCenter
                            color: Appearance.colors.colPrimaryContainer
                            radius: Appearance.rounding?.normal ?? 12
                            clip: true
                            layer.enabled: true
                            layer.effect: OpacityMask {
                                maskSource: Rectangle {
                                    width: labelArt.width
                                    height: labelArt.height
                                    radius: labelArt.radius
                                }
                            }

                            StyledImage {
                                anchors.fill: parent
                                source: root.displayedArtFilePath
                                fillMode: Image.PreserveAspectCrop
                                cache: false
                                antialiasing: true
                                sourceSize.width: labelArt.width * 2
                                sourceSize.height: labelArt.height * 2
                                visible: root.displayedArtFilePath !== ""
                            }

                            MaterialSymbol {
                                anchors.centerIn: parent
                                fill: 1
                                text: "music_note"
                                iconSize: 22
                                color: Appearance.colors.colOnPrimaryContainer
                                visible: root.displayedArtFilePath === ""
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignVCenter
                            spacing: 2

                            StyledText {
                                Layout.fillWidth: true
                                text: root.currentPlayer?.trackTitle ?? Translation.tr("Something")
                                font.pixelSize: Appearance.font.pixelSize.small
                                font.weight: Font.DemiBold
                                font.italic: true
                                color: Appearance.colors.colOnPrimaryContainer
                                elide: Text.ElideRight
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: root.currentPlayer?.trackArtist ?? "Play"
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colOnPrimaryContainer
                                opacity: 0.65
                                elide: Text.ElideRight
                            }
                        }

                        // Controls
                        RowLayout { 
                            spacing: 2 // There were buttons here but I removed them.

                            MaterialShapeWrappedMaterialSymbol {
                                shape: MaterialShape.Shape.Cookie12Sided
                                color: Appearance.colors.colPrimary
                                colSymbol: Appearance.colors.colOnPrimary
                                text: root.currentPlayer?.isPlaying ? "pause" : "play_arrow"
                                iconSize: root.buttonIconSize + 10
                                fill: 1
                                padding: 6

                                MouseArea {
                                    anchors.fill: parent
                                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                                    onClicked: (mouse) => {
                                        if (mouse.button === Qt.RightButton) {
                                            root.currentPlayer?.next()
                                        } else {
                                            root.currentPlayer?.togglePlaying()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: ColorUtils.transparentize(Appearance.colors.colOnPrimaryContainer, 0.88)
                    topLeftRadius: 0
                    topRightRadius: 0
                    bottomLeftRadius: card.radius
                    bottomRightRadius: card.radius
                    clip: true

                    Lyrics {
                        anchors.fill: parent
                        anchors.margins: 10
                        textAlignment: Text.AlignHCenter
                        textColor: Appearance.colors.colOnPrimaryContainer
                        activeColor: Appearance.colors.colPrimary
                        dimColor: Appearance.colors.colSubtext
                        indicatorColor: Appearance.colors.colPrimary
                        indicatorShapeColor: Appearance.colors.colOnPrimary
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
            onResizeFinished: { root.configEntry.sizeMode = root.sizeMode }
        }
    }
}
