pragma ComponentBehavior: Bound

import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import Quickshell
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    implicitHeight: col.implicitHeight

    readonly property var shapeOptions: [
        "Circle", "Square", "Cookie12Sided", "Clover4Leaf", "Pill", "Heart"
    ]

    ColumnLayout {
        id: col
        width: root.width
        spacing: 8

        // Scheme
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: schemeGrid.implicitHeight + 20
            radius: Appearance.rounding.verylarge
            color: Appearance.colors.colUiBackground

            GridLayout {
                id: schemeGrid
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
                columns: 3
                rowSpacing: 6
                columnSpacing: 6

                Repeater {
                    id: schemeRepeater
                    model: [
                        { value: "auto",               displayName: Translation.tr("Auto"),         icon: "auto_awesome" },
                        { value: "scheme-content",      displayName: Translation.tr("Content"),      icon: "image" },
                        { value: "scheme-expressive",   displayName: Translation.tr("Expressive"),   icon: "palette" },
                        { value: "scheme-fidelity",     displayName: Translation.tr("Fidelity"),     icon: "equal" },
                        { value: "scheme-fruit-salad",  displayName: Translation.tr("Fruit Salad"),  icon: "nutrition" },
                        { value: "scheme-monochrome",   displayName: Translation.tr("Monochrome"),   icon: "invert_colors" },
                        { value: "scheme-neutral",      displayName: Translation.tr("Neutral"),      icon: "tonality" },
                        { value: "scheme-rainbow",      displayName: Translation.tr("Rainbow"),      icon: "gradient" },
                        { value: "scheme-tonal-spot",   displayName: Translation.tr("Tonal Spot"),   icon: "lens" },
                    ]

                    delegate: Rectangle {
                        id: schemeTile
                        required property var modelData
                        required property int index

                        Layout.fillWidth: true
                        Layout.preferredHeight: 40

                        readonly property int columns: schemeGrid.columns
                        readonly property int count: schemeRepeater.count
                        readonly property int row: Math.floor(index / columns)
                        readonly property int col: index % columns
                        readonly property int lastRow: Math.floor((count - 1) / columns)
                        readonly property int lastRowCount: count - lastRow * columns

                        readonly property bool isTopLeft: row === 0 && col === 0
                        readonly property bool isTopRight: row === 0 && col === columns - 1
                        readonly property bool isBottomLeft: row === lastRow && col === 0
                        readonly property bool isBottomRight: row === lastRow && col === lastRowCount - 1

                        property bool isSelected: Config.options.appearance.palette.type === modelData.value
                        property bool hovered: hoverArea.containsMouse
                        property real ownRadius: isSelected ? height / 2 : Appearance.rounding.normal

                        topLeftRadius: isTopLeft ? Appearance.rounding.verylarge : ownRadius
                        topRightRadius: isTopRight ? Appearance.rounding.verylarge : ownRadius
                        bottomLeftRadius: isBottomLeft ? Appearance.rounding.verylarge : ownRadius
                        bottomRightRadius: isBottomRight ? Appearance.rounding.verylarge : ownRadius

                        color: isSelected ? Appearance.colors.colPrimary
                            : hovered ? Appearance.colors.colSecondaryContainerHover
                            : Appearance.colors.colSecondaryContainer

                        Behavior on ownRadius {
                            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
                        }
                        Behavior on color {
                            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                        }

                        MaterialSymbol {
                            anchors.centerIn: parent
                            text: schemeTile.modelData.icon
                            iconSize: Appearance.font.pixelSize.larger
                            color: schemeTile.isSelected ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSecondaryContainer
                        }

                        MouseArea {
                            id: hoverArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                Config.options.appearance.palette.type = schemeTile.modelData.value
                                Quickshell.execDetached(["bash", "-c", `${Directories.wallpaperSwitchScriptPath} --noswitch`])
                            }
                        }

                        StyledToolTip {
                            text: schemeTile.modelData.displayName
                        }
                    }
                }
            }
        }

        // Centered wallpaper
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: centeredCol.implicitHeight + 16
            radius: Appearance.rounding.verylarge
            color: Appearance.colors.colUiBackground

            ColumnLayout {
                id: centeredCol
                anchors { fill: parent; margins: 8 }
                spacing: 6

                ConfigSwitch {
                    Layout.fillWidth: true
                    buttonIcon: "check"
                    text: Translation.tr("Centered wallpaper")
                    checked: Config.options.background.centeredWallpaper
                    onCheckedChanged: Config.options.background.centeredWallpaper = checked
                }

                ConfigSwitch {
                    Layout.fillWidth: true
                    buttonIcon: "lock"
                    text: Translation.tr("Only when locked")
                    checked: Config.options.background.centeredWallpaperOnlyWhenLocked
                    enabled: Config.options.background.centeredWallpaper
                    onCheckedChanged: Config.options.background.centeredWallpaperOnlyWhenLocked = checked
                }

                ConfigSelectionShapeArray {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    visible: Config.options.background.centeredWallpaper
                    currentValue: Config.options.background.centeredWallpaperShape
                    shapeColor: Appearance.colors.colPrimary
                    backgroundColor: Appearance.colors.colPrimaryContainer
                    options: root.shapeOptions
                    onSelected: newValue => Config.options.background.centeredWallpaperShape = newValue
                }

                ColorSelectionArray {
                    Layout.fillWidth: true
                    Layout.leftMargin: 0
                    Layout.rightMargin: 0
                    visible: Config.options.background.centeredWallpaper
                    showLabel: false
                    itemSpacing: 5
                    currentValue: Config.options.background.centeredWallpaperColor
                    options: ["primary", "secondary", "tertiary", "primaryContainer", "secondaryContainer", "tertiaryContainer"]
                    onSelected: newValue => Config.options.background.centeredWallpaperColor = newValue
                }

                ConfigSlider {
                    Layout.fillWidth: true
                    showLabel: false
                    visible: Config.options.background.centeredWallpaper
                    value: Config.options.background.centeredWallpaperSize
                    usePercentTooltip: false
                    buttonIcon: "aspect_ratio"
                    from: 400
                    to: 800
                    stopIndicatorValues: [400]
                    onValueChanged: Config.options.background.centeredWallpaperSize = value
                }
            }
        }

        // Transitions
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: transCol.implicitHeight + 16
            radius: Appearance.rounding.verylarge
            color: Appearance.colors.colUiBackground

            ColumnLayout {
                id: transCol
                anchors { fill: parent; margins: 8 }

                Repeater {
                    model: [
                        { displayName: Translation.tr("Disable"),    icon: "block",        value: "" },
                        { displayName: Translation.tr("Magic"),   icon: "auto_awesome", value: "magic" },
                        { displayName: Translation.tr("Stripes"), icon: "texture_minus", value: "stripes" },
                        { displayName: Translation.tr("Random"),  icon: "shuffle",      value: "random" },
                    ]
                    delegate: RippleButton {
                        id: transRow
                        required property var modelData
                        Layout.fillWidth: true
                        implicitHeight: 40
                        toggled: Config.options.background.wallpaperAnimation === transRow.modelData.value
                        colBackground: "transparent"
                        buttonRadius: Appearance.rounding.verylarge
                        colBackgroundHover: Appearance.colors.colLayer2
                        colBackgroundToggled: Appearance.colors.colSecondaryContainer
                        colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
                        colRippleToggled: Appearance.colors.colSecondaryContainerActive
                        onClicked: Config.options.background.wallpaperAnimation = transRow.modelData.value
                        contentItem: RowLayout {
                            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                            spacing: 12
                            MaterialSymbol {
                                text: transRow.modelData.icon
                                iconSize: Appearance.font.pixelSize.larger
                                color: transRow.toggled ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
                                fill: transRow.toggled ? 1 : 0
                            }
                            StyledText {
                                Layout.fillWidth: true
                                text: transRow.modelData.displayName
                                font.pixelSize: Appearance.font.pixelSize.normal
                                color: transRow.toggled ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnLayer1
                            }
                            MaterialSymbol {
                                visible: transRow.toggled
                                text: "check"
                                iconSize: Appearance.font.pixelSize.normal
                                color: Appearance.colors.colOnSecondaryContainer
                            }
                        }
                    }
                }
            }
        }
    }
}