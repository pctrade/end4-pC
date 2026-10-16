pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Widgets

PopupWindow {
    id: root

    signal popupClosed()

    readonly property real cardWidth: 372
    readonly property int columns: 4
    readonly property real cardRadius: 24
    readonly property real cardPadding: 8
    readonly property real innerRadius: cardRadius - cardPadding
    readonly property real gridPadding: 6
    readonly property real cell: (cardWidth - cardPadding * 2 - gridPadding * 2) / columns
    readonly property real gridMaxHeight: cell * 3
    readonly property bool hasFolder: Config.options.profile.avatarPath !== ""
    readonly property string displayName: Config.options.profile.displayName !== "" ? Config.options.profile.displayName : SystemInfo.username
    readonly property string description: Config.options.profile.descriptionText === "::distro::" ? SystemInfo.distroName : Config.options.profile.descriptionText
    property bool closing: false
    readonly property bool barVertical: Config.options.bar.vertical
    readonly property string barEdge: {
        if (!barVertical) return Config.options.bar.bottom ? "bottom" : "top"
        return Config.options.bar.bottom ? "right" : "left"
    }
    readonly property real bounceRoom: 24

    color: "transparent"
    implicitWidth: root.cardWidth + Appearance.sizes.elevationMargin * 2 + (barVertical ? bounceRoom : 0)
    implicitHeight: card.implicitHeight + Appearance.sizes.elevationMargin * 2 + (barVertical ? 0 : bounceRoom)

    function open() {
        root.visible = true
        closeAnim.stop()
        openAnim.restart()
    }

    function close() {
        if (root.closing) return
        root.closing = true
        openAnim.stop()
        closeAnim.restart()
    }

    Component.onCompleted: {
        GlobalFocusGrab.addDismissable(root)
        root.open()
    }
    Component.onDestruction: GlobalFocusGrab.removeDismissable(root)

    Connections {
        target: GlobalFocusGrab
        function onDismissed() { root.close() }
    }

    ParallelAnimation {
        id: openAnim
        NumberAnimation {
            target: cardScale
            property: root.barVertical ? "xScale" : "yScale"
            to: 1
            duration: 500
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
        }
        NumberAnimation {
            target: cardScale
            property: root.barVertical ? "yScale" : "xScale"
            to: 1
            duration: Appearance.animationCurves.expressiveDefaultSpatialDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.animationCurves.expressiveDefaultSpatial
        }
        NumberAnimation {
            target: card
            property: "opacity"
            to: 1
            duration: Appearance.animationCurves.expressiveEffectsDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.animationCurves.expressiveEffects
        }
        SequentialAnimation {
            PauseAnimation { duration: 90 }
            ParallelAnimation {
                NumberAnimation {
                    target: content
                    property: "opacity"
                    to: 1
                    duration: Appearance.animationCurves.expressiveEffectsDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animationCurves.expressiveEffects
                }
                NumberAnimation {
                    target: contentShift
                    properties: "x,y"
                    to: 0
                    duration: Appearance.animationCurves.expressiveDefaultSpatialDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.animationCurves.expressiveFastSpatial
                }
            }
        }
    }

    ParallelAnimation {
        id: closeAnim
        onFinished: {
            root.visible = false
            root.popupClosed()
        }
        NumberAnimation {
            target: cardScale
            property: root.barVertical ? "xScale" : "yScale"
            to: 0.4
            duration: 220
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.animationCurves.emphasizedAccel
        }
        NumberAnimation {
            target: cardScale
            property: root.barVertical ? "yScale" : "xScale"
            to: 0.85
            duration: 220
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.animationCurves.emphasizedAccel
        }
        NumberAnimation {
            target: card
            property: "opacity"
            to: 0
            duration: 200
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Appearance.animationCurves.emphasizedAccel
        }
        NumberAnimation {
            target: content
            property: "opacity"
            to: 0
            duration: 120
        }
    }

    FolderListModel {
        id: avatarModel
        folder: root.hasFolder ? Qt.resolvedUrl(Config.options.profile.avatarPath) : ""
        showDirs: false
        nameFilters: ["*.png", "*.svg", "*.jpg", "*.jpeg", "*.webp"]
    }

    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.close()

        StyledRectangularShadow {
            target: card
            opacity: card.opacity
        }

        Rectangle {
            id: card
            anchors {
                fill: parent
                leftMargin: Appearance.sizes.elevationMargin + (root.barEdge === "right" ? root.bounceRoom : 0)
                rightMargin: Appearance.sizes.elevationMargin + (root.barEdge === "left" ? root.bounceRoom : 0)
                topMargin: Appearance.sizes.elevationMargin + (root.barEdge === "bottom" ? root.bounceRoom : 0)
                bottomMargin: Appearance.sizes.elevationMargin + (root.barEdge === "top" ? root.bounceRoom : 0)
            }
            implicitHeight: content.implicitHeight + root.cardPadding * 2
            radius: root.cardRadius
            color: Appearance.colors.colUiPopupBackground
            border.width: 1
            border.color: Appearance.colors.colLayer0Border
            opacity: 0
            transform: Scale {
                id: cardScale
                origin.x: root.barEdge === "left" ? 0 : root.barEdge === "right" ? card.width : card.width / 2
                origin.y: root.barEdge === "top" ? 0 : root.barEdge === "bottom" ? card.height : card.height / 2
                xScale: root.barVertical ? 0.4 : 0.8
                yScale: root.barVertical ? 0.8 : 0.4
            }

            ColumnLayout {
                id: content
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: root.cardPadding
                }
                spacing: 8
                opacity: 0
                transform: Translate {
                    id: contentShift
                    x: root.barEdge === "left" ? -16 : root.barEdge === "right" ? 16 : 0
                    y: root.barEdge === "top" ? -16 : root.barEdge === "bottom" ? 16 : 0
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: headerRow.implicitHeight + 28
                    radius: root.innerRadius
                    color: Appearance.colors.colPrimaryContainer

                    RowLayout {
                        id: headerRow
                        anchors {
                            left: parent.left
                            right: parent.right
                            verticalCenter: parent.verticalCenter
                            margins: 16
                        }
                        spacing: 14

                        Item {
                            implicitWidth: 92
                            implicitHeight: 92

                            MaterialShape {
                                anchors.fill: parent
                                shape: MaterialShape.Shape.Cookie9Sided
                                color: Appearance.colors.colPrimary
                            }

                            UserAvatar {
                                anchors.centerIn: parent
                                width: 72
                                height: 72
                                iconSize: 36
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            StyledText {
                                Layout.fillWidth: true
                                text: root.displayName
                                font.pixelSize: Appearance.font.pixelSize.huge
                                font.weight: Font.Medium
                                color: Appearance.colors.colOnPrimaryContainer
                                elide: Text.ElideRight
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: root.description
                                visible: text.length > 0
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOnPrimaryContainer
                                opacity: 0.7
                                elide: Text.ElideRight
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: Translation.tr("Up • %1").arg(DateTime.uptime)
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: Appearance.colors.colOnPrimaryContainer
                                opacity: 0.7
                                elide: Text.ElideRight
                            }
                        }

                        RippleButton {
                            Layout.alignment: Qt.AlignTop
                            implicitWidth: 36
                            implicitHeight: 36
                            visible: root.hasFolder
                            buttonRadius: width / 2
                            colBackground: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.8)
                            colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.6)
                            colRipple: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.4)
                            onClicked: {
                                Quickshell.execDetached(["dolphin", Config.options.profile.avatarPath])
                                root.close()
                            }
                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                horizontalAlignment: Text.AlignHCenter
                                text: "folder_open"
                                iconSize: Appearance.font.pixelSize.larger
                                color: Appearance.colors.colOnPrimaryContainer
                            }
                            StyledToolTip {
                                text: Translation.tr("Open avatar folder")
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 6
                    Layout.rightMargin: 6

                    StyledText {
                        Layout.fillWidth: true
                        text: Translation.tr("Choose your avatar")
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnLayer0
                    }

                    Rectangle {
                        visible: root.hasFolder && avatarModel.count > 0
                        radius: Appearance.rounding.full
                        color: Appearance.colors.colSecondaryContainer
                        implicitWidth: countLabel.implicitWidth + 16
                        implicitHeight: countLabel.implicitHeight + 6

                        StyledText {
                            id: countLabel
                            anchors.centerIn: parent
                            text: avatarModel.count
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnSecondaryContainer
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: root.hasFolder && avatarModel.count > 0 ? Math.min(grid.contentHeight, root.gridMaxHeight) + root.gridPadding * 2 : 110
                    radius: root.innerRadius
                    color: Appearance.colors.colLayer2Base

                    GridView {
                        id: grid
                        visible: root.hasFolder && avatarModel.count > 0
                        anchors {
                            fill: parent
                            margins: root.gridPadding
                        }
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds
                        cellWidth: root.cell
                        cellHeight: root.cell
                        model: avatarModel
                        reuseItems: true

                        ScrollBar.vertical: StyledScrollBar {}

                        delegate: Item {
                            id: tile
                            required property string filePath
                            readonly property string path: FileUtils.trimFileProtocol(filePath.toString())
                            readonly property bool selected: tile.path === Config.options.profile.avatarPicture
                            width: root.cell
                            height: root.cell

                            ClippingRectangle {
                                id: avatarClip
                                anchors.centerIn: parent
                                width: root.cell - 20
                                height: width
                                radius: width / 2
                                color: Appearance.colors.colLayer2
                                scale: tileArea.pressed ? 0.92 : (tileArea.containsMouse || tile.selected ? 1.1 : 1)

                                Behavior on scale {
                                    NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 2 }
                                }

                                Image {
                                    anchors.fill: parent
                                    source: tile.filePath
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    cache: true
                                    sourceSize.width: 128
                                    sourceSize.height: 128
                                }
                            }

                            Rectangle {
                                anchors.centerIn: avatarClip
                                width: avatarClip.width + 8
                                height: width
                                radius: width / 2
                                color: "transparent"
                                border.width: tile.selected ? 3 : 0
                                border.color: Appearance.colors.colPrimary
                                scale: avatarClip.scale

                                Behavior on border.width {
                                    NumberAnimation { duration: 150 }
                                }
                            }

                            Rectangle {
                                visible: tile.selected
                                anchors.right: avatarClip.right
                                anchors.bottom: avatarClip.bottom
                                anchors.rightMargin: -4
                                anchors.bottomMargin: -4
                                width: 20
                                height: width
                                radius: width / 2
                                color: Appearance.colors.colPrimary

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "check"
                                    iconSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colOnPrimary
                                }
                            }

                            MouseArea {
                                id: tileArea
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Config.options.profile.avatarPicture = tile.path
                            }
                        }
                    }

                    ColumnLayout {
                        visible: !grid.visible
                        anchors.centerIn: parent
                        width: parent.width - 32
                        spacing: 6

                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.hasFolder ? "image_not_supported" : "add_photo_alternate"
                            iconSize: 32
                            color: Appearance.colors.colSubtext
                        }
                        StyledText {
                            Layout.fillWidth: true
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.Wrap
                            text: root.hasFolder
                                ? Translation.tr("No images found in your avatar folder")
                                : Translation.tr("Pick an avatar folder in Settings > Profile to see your avatars here")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colSubtext
                        }
                    }
                }
            }
        }
    }
}
