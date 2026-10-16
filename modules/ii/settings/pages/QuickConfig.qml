import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io
import Qt.labs.folderlistmodel
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.common.models

ContentPage {
    id: page
    property bool isMinimal: Config.options.settings.style === "minimal"
    property string openPopup: ""
    forceWidth: true
    baseWidth: !isMinimal ? 700 : 600
    bottomContentPadding: 35

    component SmallLightDarkPreferenceButton: RippleButton {
        id: smallLightDarkPreferenceButton
        required property bool dark
        property color colText: toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer2
        padding: 0
        Layout.fillHeight: true
        Layout.preferredWidth: 46
        toggled: Appearance.m3colors.darkmode === dark
        colBackground: toggled ? Appearance.colors.colPrimary : ColorUtils.transparentize(Appearance.colors.colLayer2, 0.45)
        onClicked: {
            Quickshell.execDetached(["bash", "-c", `${Directories.wallpaperSwitchScriptPath} --mode ${dark ? "dark" : "light"} --noswitch`]);
        }
        contentItem: RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 12
            anchors.rightMargin: 12
            spacing: 7

            MaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                iconSize: 24
                fill: toggled ? 1 : 0
                text: smallLightDarkPreferenceButton.dark ? "dark_mode" : "light_mode"
                color: smallLightDarkPreferenceButton.colText
            }
        }
    }

    component GlassCard: Item {
        id: glass
        required property Item backdrop
        property real cardRadius: Appearance.rounding.large
        default property alias content: contentHolder.data

        Item {
            anchors.fill: parent
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: glass.width
                    height: glass.height
                    radius: glass.cardRadius
                }
            }

            ShaderEffectSource {
                id: blurSource
                anchors.fill: parent
                sourceItem: glass.backdrop
                sourceRect: Qt.rect(glass.x, glass.y, glass.width, glass.height)
                visible: false
            }
            FastBlur {
                anchors.fill: parent
                source: blurSource
                radius: 128
            }
            Rectangle {
                anchors.fill: parent
                color: ColorUtils.transparentize(Appearance.colors.colLayer1, 0.4)
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: glass.cardRadius
            color: "transparent"
        }

        Item {
            id: contentHolder
            anchors.fill: parent
        }
    }

    component GlassPopup: Item {
        id: glassPopup
        required property Item backdrop
        property real cardRadius: Appearance.rounding.normal
        default property alias content: contentHolder.data

        function syncBackdropRect() {
            if (!backdrop)
                return
            const p = glassPopup.mapToItem(backdrop, 0, 0)
            const x = Math.max(0, Math.min(p.x, backdrop.width - glassPopup.width))
            const y = Math.max(0, Math.min(p.y, backdrop.height - glassPopup.height))
            const w = Math.min(glassPopup.width, backdrop.width)
            const h = Math.min(glassPopup.height, backdrop.height)
            popupBlurSource.sourceRect = Qt.rect(x, y, w, h)
        }
        onWidthChanged: syncBackdropRect()
        onHeightChanged: syncBackdropRect()
        onXChanged: syncBackdropRect()
        onYChanged: syncBackdropRect()
        onBackdropChanged: syncBackdropRect()
        Component.onCompleted: syncBackdropRect()

        Connections {
            target: glassPopup.backdrop
            function onWidthChanged() { glassPopup.syncBackdropRect() }
            function onHeightChanged() { glassPopup.syncBackdropRect() }
            function onXChanged() { glassPopup.syncBackdropRect() }
            function onYChanged() { glassPopup.syncBackdropRect() }
        }

        Item {
            anchors.fill: parent
            layer.enabled: true
            layer.effect: OpacityMask {
                maskSource: Rectangle {
                    width: glassPopup.width
                    height: glassPopup.height
                    radius: glassPopup.cardRadius
                }
            }

            ShaderEffectSource {
                id: popupBlurSource
                anchors.fill: parent
                sourceItem: glassPopup.backdrop
                visible: false
            }
            FastBlur {
                anchors.fill: parent
                source: popupBlurSource
                radius: 64
            }
            Rectangle {
                anchors.fill: parent
                color: ColorUtils.transparentize(Appearance.colors.colLayer1, 0.25)
            }
        }

        Item {
            id: contentHolder
            anchors.fill: parent
        }
    }

    component BarScreenPopupButton: RippleButton {
        id: barScreenPopupButton
        property string iconText
        property string popupId
        property var popupHost: null
        property int maxVisibleRows: 9
        property Item backdrop
        property string popupTitle
        property real popupXOffset: 0
        property var options: []
        property var isCurrentValue: value => false
        property var pickValue: value => {}
        readonly property bool popupVisible: popupHost !== null && popupHost.openPopup === popupId
        readonly property bool hoveredAnywhere: buttonHoverHandler.hovered || popupHoverHandler.hovered

        onPopupVisibleChanged: {
            if (popupVisible)
                popupGlass.syncBackdropRect();
        }

        onHoveredAnywhereChanged: {
            if (hoveredAnywhere) {
                popupCloseTimer.stop();
                if (popupHost !== null)
                    popupHost.openPopup = popupId;
            } else {
                popupCloseTimer.restart();
            }
        }

        padding: 0
        Layout.fillHeight: true
        Layout.preferredWidth: 48

        colBackground: ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.9)

        contentItem: Item {
            anchors.fill: parent

            MaterialSymbol {
                anchors.centerIn: parent
                text: barScreenPopupButton.iconText
                iconSize: 22
                color: Appearance.colors.colOnLayer1
            }
        }

        HoverHandler {
            id: buttonHoverHandler
        }

        Timer {
            id: popupCloseTimer
            interval: 200
            onTriggered: {
                if (!barScreenPopupButton.hoveredAnywhere && barScreenPopupButton.popupHost !== null && barScreenPopupButton.popupHost.openPopup === barScreenPopupButton.popupId)
                    barScreenPopupButton.popupHost.openPopup = "";
            }
        }

        Item {
            id: sectionPopup
            x: (barScreenPopupButton.width - width) / 2 + barScreenPopupButton.popupXOffset
            y: -height - 8
            width: 248
            height: popupColumn.implicitHeight + 12
            opacity: barScreenPopupButton.popupVisible ? 1 : 0
            visible: opacity > 0.01
            enabled: barScreenPopupButton.popupVisible
            scale: barScreenPopupButton.popupVisible ? 1 : 0.92
            transformOrigin: Item.Bottom

            Behavior on opacity {
                NumberAnimation {
                    duration: 130
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: 130
                    easing.type: Easing.OutCubic
                }
            }

            HoverHandler {
                id: popupHoverHandler
            }

            GlassPopup {
                id: popupGlass
                anchors.fill: parent
                backdrop: barScreenPopupButton.backdrop

                Rectangle {
                    anchors.fill: parent
                    radius: Appearance.rounding.normal
                    color: "transparent"
                }

                ColumnLayout {
                    id: popupColumn
                    anchors.fill: parent
                    anchors.margins: 6
                    spacing: 2

                    StyledText {
                        Layout.fillWidth: true
                        Layout.leftMargin: 8
                        Layout.topMargin: 2
                        Layout.bottomMargin: 2
                        text: barScreenPopupButton.popupTitle
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.45)
                    }

                    Flickable {
                        id: optionsFlick
                        Layout.fillWidth: true
                        Layout.preferredHeight: Math.min(optionsColumn.implicitHeight, barScreenPopupButton.maxVisibleRows * 30 + (barScreenPopupButton.maxVisibleRows - 1) * 2)
                        contentWidth: width
                        contentHeight: optionsColumn.implicitHeight
                        clip: true
                        interactive: contentHeight > height
                        boundsBehavior: Flickable.StopAtBounds
                        ScrollBar.vertical: StyledScrollBar {}

                        ColumnLayout {
                            id: optionsColumn
                            width: optionsFlick.width
                            spacing: 2

                        Repeater {
                            model: barScreenPopupButton.options

                            delegate: Rectangle {
                                id: popupOptionRow
                                required property var modelData
                                Layout.fillWidth: true
                                Layout.preferredHeight: 30
                                radius: Appearance.rounding.normal

                                property bool isSelected: barScreenPopupButton.isCurrentValue(modelData.value)
                                readonly property bool rowHovered: optionMouseArea.containsMouse

                                color: isSelected ? Appearance.colors.colPrimary
                                    : rowHovered ? ColorUtils.transparentize(Appearance.colors.colOnLayer1, 0.9)
                                    : "transparent"

                                MouseArea {
                                    id: optionMouseArea
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        barScreenPopupButton.pickValue(popupOptionRow.modelData.value);
                                        if (barScreenPopupButton.popupHost !== null)
                                            barScreenPopupButton.popupHost.openPopup = "";
                                    }
                                }

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.leftMargin: 10
                                    anchors.rightMargin: 10
                                    spacing: 8

                                    MaterialSymbol {
                                        text: popupOptionRow.modelData.icon
                                        iconSize: Appearance.font.pixelSize.larger
                                        color: popupOptionRow.isSelected ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: popupOptionRow.modelData.displayName
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        font.weight: Font.Medium
                                        elide: Text.ElideRight
                                        color: popupOptionRow.isSelected ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                                    }

                                    MaterialSymbol {
                                        visible: popupOptionRow.isSelected
                                        text: "check"
                                        iconSize: Appearance.font.pixelSize.larger
                                        color: Appearance.colors.colOnPrimary
                                    }
                                }
                            }
                        }
                        }
                    }
                }
            }
        }
    }

    ColumnLayout {
        id: mainLayout
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 6

        ContentSection {
            icon: "screenshot_monitor"
            title: Translation.tr("Wallpaper & Colors")
            shape: MaterialShape.Shape.Puffy
            Layout.fillWidth: true
            collapsible: false

            Rectangle {
                id: mBox
                Layout.fillWidth: true
                Layout.preferredHeight: isMinimal ? 400 : 556
                radius: Appearance.rounding.large - 3
                color: Appearance.colors.colLayer2
                clip: true

                StyledImage {
                    id: wallpaperImg
                    anchors.fill: parent
                    sourceSize.height: 1080
                    fillMode: Image.PreserveAspectCrop
                    source: /\.(mp4|webm|mkv|avi|mov)$/i.test(Config.options.background.wallpaperPath)
                        ? Config.options.background.thumbnailPath
                        : Config.options.background.wallpaperPath
                    cache: false
                    layer.enabled: true
                    layer.effect: OpacityMask {
                        maskSource: Rectangle {
                            width: mBox.width
                            height: mBox.height
                            radius: mBox.radius
                        }
                    }
                }

                GlassCard {
                    id: bottomBar
                    backdrop: wallpaperImg
                    height: 64
                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                        margins: 12
                    }

                    Item {
                        id: barControls
                        anchors.fill: parent
                        anchors.margins: 8

                        RowLayout {
                            id: modeButtonsRow
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            height: parent.height
                            spacing: 6
                            uniformCellSizes: true

                            SmallLightDarkPreferenceButton {
                                dark: false
                            }
                            SmallLightDarkPreferenceButton {
                                dark: true
                            }
                        }

                        RowLayout {
                            id: sectionButtonsRow
                            z: 10
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.verticalCenter: parent.verticalCenter
                            height: parent.height
                            spacing: 6

                            BarScreenPopupButton {
                                iconText: "position_bottom_right"
                                popupId: "barPosition"
                                popupHost: page
                                backdrop: wallpaperImg
                                popupTitle: Translation.tr("Bar position")
                                options: [
                                    { displayName: Translation.tr("Top"), icon: "arrow_upward", value: 0 },
                                    { displayName: Translation.tr("Left"), icon: "arrow_back", value: 2 },
                                    { displayName: Translation.tr("Bottom"), icon: "arrow_downward", value: 1 },
                                    { displayName: Translation.tr("Right"), icon: "arrow_forward", value: 3 }
                                ]
                                isCurrentValue: value => ((Config.options.bar.bottom ? 1 : 0) | (Config.options.bar.vertical ? 2 : 0)) === value
                                pickValue: value => {
                                    Config.options.bar.bottom = (value & 1) !== 0;
                                    Config.options.bar.vertical = (value & 2) !== 0;
                                }
                            }
                            BarScreenPopupButton {
                                iconText: "settop_component"
                                popupId: "barStyle"
                                popupHost: page
                                backdrop: wallpaperImg
                                popupTitle: Translation.tr("Bar style")
                                options: [
                                    { displayName: Translation.tr("Hug"), icon: "line_curve", value: 0 },
                                    { displayName: Translation.tr("Split Hug"), icon: "splitscreen", value: 6 },
                                    { displayName: Translation.tr("Float"), icon: "view_day", value: 1 },
                                    { displayName: Translation.tr("Islands"), icon: "crop_3_2", value: 2 },
                                    { displayName: Translation.tr("M3"), icon: "interests", value: 3 },
                                    { displayName: Translation.tr("M3 Hug"), icon: "category", value: 4 },
                                    { displayName: Translation.tr("Panel"), icon: "toolbar", value: 5 }
                                ]
                                isCurrentValue: value => Config.options.bar.cornerStyle === value
                                pickValue: value => {
                                    Config.options.bar.cornerStyle = value;
                                }
                            }
                            BarScreenPopupButton {
                                iconText: "tab_group"
                                popupId: "groupStyle"
                                popupHost: page
                                backdrop: wallpaperImg
                                popupTitle: Translation.tr("Group style")
                                options: [
                                    { displayName: Translation.tr("None"), icon: "block", value: "transparent" },
                                    { displayName: Translation.tr("Pills"), icon: "pill", value: "pills" },
                                    { displayName: Translation.tr("Separated"), icon: "view_column_2", value: "separated" },
                                    { displayName: Translation.tr("Segmented"), icon: "tablet", value: "segmented" }
                                ]
                                isCurrentValue: value => Config.options.bar.borderless === value
                                pickValue: value => {
                                    Config.options.bar.borderless = value;
                                }
                            }
                            BarScreenPopupButton {
                                iconText: "rounded_corner"
                                popupId: "screenCorner"
                                popupHost: page
                                backdrop: wallpaperImg
                                popupTitle: Translation.tr("Screen round corner")
                                options: [
                                    { displayName: Translation.tr("No"), icon: "close", value: 0 },
                                    { displayName: Translation.tr("Yes"), icon: "check", value: 1 },
                                    { displayName: Translation.tr("When not fullscreen"), icon: "fullscreen_exit", value: 2 }
                                ]
                                isCurrentValue: value => Config.options.appearance.fakeScreenRounding === value
                                pickValue: value => {
                                    Config.options.appearance.fakeScreenRounding = value;
                                }
                            }
                        }

                        RippleButton {
                            id: accentColorButton
                            visible: ColorSchemes.current === ""
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            width: 48
                            height: parent.height
                            padding: 0
                            colBackground: Appearance.colors.colTertiaryContainer
                            colBackgroundHover: Appearance.colors.colTertiaryContainerHover
                            onClicked: {
                                Quickshell.execDetached([Directories.wallpaperSwitchScriptPath, "--noswitch", "--color"]);
                            }
                            contentItem: Item {
                                anchors.fill: parent

                                MaterialSymbol {
                                    anchors.centerIn: parent
                                    text: "colorize"
                                    iconSize: 22
                                    color: Appearance.colors.colOnLayer1
                                }
                            }
                            StyledToolTip {
                                text: "Change accent color"
                            }
                        }

                        BarScreenPopupButton {
                            id: schemeButton
                            z: 11
                            anchors.right: accentColorButton.visible ? accentColorButton.left : parent.right
                            anchors.rightMargin: accentColorButton.visible ? 6 : 0
                            anchors.verticalCenter: parent.verticalCenter
                            width: 48
                            height: parent.height
                            iconText: "palette"
                            popupId: "schemes"
                            popupHost: page
                            popupXOffset: (isMinimal ? -30 : -40) - (namedMode ? 68 : 0)
                            backdrop: wallpaperImg
                            popupTitle: Translation.tr("Color scheme")
                            readonly property bool namedMode: ColorSchemes.current !== ""
                            options: namedMode ? [{ displayName: "Material", icon: "auto_awesome", value: "" }].concat(
                                ColorSchemes.schemeOptions().filter(o => o.value !== "").map(o => ({ displayName: o.displayName, icon: "palette", value: o.value }))
                            ) : [
                                { displayName: Translation.tr("Auto"),        icon: "auto_awesome",  value: "auto" },
                                { displayName: Translation.tr("Content"),     icon: "image",         value: "scheme-content" },
                                { displayName: Translation.tr("Expressive"),  icon: "palette",       value: "scheme-expressive" },
                                { displayName: Translation.tr("Fidelity"),    icon: "equal",         value: "scheme-fidelity" },
                                { displayName: Translation.tr("Fruit Salad"), icon: "nutrition",     value: "scheme-fruit-salad" },
                                { displayName: Translation.tr("Mono"),        icon: "invert_colors", value: "scheme-monochrome" },
                                { displayName: Translation.tr("Neutral"),     icon: "tonality",      value: "scheme-neutral" },
                                { displayName: Translation.tr("Rainbow"),     icon: "gradient",      value: "scheme-rainbow" },
                                { displayName: Translation.tr("Tonal Spot"),  icon: "lens",          value: "scheme-tonal-spot" }
                            ]
                            isCurrentValue: value => namedMode ? ColorSchemes.current === value : Config.options.appearance.palette.type === value
                            pickValue: value => {
                                if (namedMode) {
                                    ColorSchemes.setScheme(value);
                                    return;
                                }
                                Config.options.appearance.palette.type = value;
                                Quickshell.execDetached(["bash", "-c", `${Directories.wallpaperSwitchScriptPath} --noswitch`]);
                            }
                        }
                    }
                }
            }
        }
    }
}
