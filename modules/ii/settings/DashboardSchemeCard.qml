import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import qs.services
import qs.modules.common.functions
import qs.modules.common
import qs.modules.common.widgets

DashboardCard {
    id: root

    readonly property string modeKey: Appearance.m3colors.darkmode ? "dark" : "light"
    readonly property var options: ColorSchemes.schemeOptions()

    tint: Appearance.colors.colLayer1

    function dotsFor(value) {
        if (value === "") return ColorSchemes.materialPreview().slice(0, 3).map(o => o.color);
        const data = ColorSchemes.schemes[value];
        if (!data) return [];
        const accents = data.accents[root.modeKey];
        return ["primary", "secondary", "tertiary"].map(slot => accents[data.defaults[slot]]).filter(c => c !== undefined);
    }

    component AccentRow: RowLayout {
        id: accentRow
        property string slot: "primary"
        property string label: ""

        Layout.fillWidth: true
        spacing: 4

        StyledText {
            text: accentRow.label
            font.pixelSize: Appearance.font.pixelSize.smaller
            color: Appearance.colors.colSubtext
        }

        Item { Layout.fillWidth: true }

        Repeater {
            model: ColorSchemes.accentOptions()

            delegate: DashboardSwatchDot {
                required property var modelData

                swatchColor: modelData.color
                selected: ColorSchemes.currentAccent(accentRow.slot) === modelData.value
                ringColor: Appearance.colors.colOnLayer1
                onClicked: {
                    const value = modelData.value;
                    Qt.callLater(() => ColorSchemes.setAccent(accentRow.slot, value, false));
                }
            }
        }
    }

    readonly property real tileWidth: 118
    readonly property real tileGap: 10

    readonly property real accentTarget: ColorSchemes.current !== "" ? 104 : 0
    property real accentHeight: accentTarget

    Behavior on accentHeight {
        SpringAnimation { spring: 3.2; damping: 0.28 }
    }

    function scrollBy(delta) {
        const maxX = Math.max(0, chipsFlick.contentWidth - chipsFlick.width);
        chipsFlick.contentX = Math.max(0, Math.min(maxX, chipsFlick.contentX + delta));
    }

    function revealSelected() {
        for (let i = 0; i < tileRepeater.count; i++) {
            const tile = tileRepeater.itemAt(i);
            if (tile && tile.selected) {
                const maxX = Math.max(0, chipsFlick.contentWidth - chipsFlick.width);
                chipsFlick.contentX = Math.max(0, Math.min(maxX, tile.x - (chipsFlick.width - tile.width) / 2));
                return;
            }
        }
    }

    Component.onCompleted: Qt.callLater(revealSelected)

    Connections {
        target: ColorSchemes
        function onSchemesChanged() { Qt.callLater(root.revealSelected) }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            Layout.bottomMargin: 12
            spacing: 12

            MaterialShapeWrappedMaterialSymbol {
                shape: MaterialShape.Shape.Flower
                text: "palette"
                iconSize: 26
                fill: 1
                padding: 11
                color: Appearance.colors.colTertiary
                colSymbol: Appearance.colors.colOnTertiary
            }

            ColumnLayout {
                spacing: 0

                StyledText {
                    text: Translation.tr("Color scheme")
                    font.pixelSize: Appearance.font.pixelSize.larger
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer1
                }
                StyledText {
                    text: ColorSchemes.currentData?.name ?? "Material"
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
            }

            Item { Layout.fillWidth: true }

            RippleButton {
                implicitHeight: 36
                horizontalPadding: 14
                buttonRadius: 18
                colBackground: Appearance.colors.colSecondaryContainer
                colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                colRipple: Appearance.colors.colSecondaryContainerActive
                downAction: () => Qt.callLater(() => ColorSchemes.addScheme())
                contentItem: RowLayout {
                    spacing: 6
                    MaterialSymbol {
                        text: "add"
                        iconSize: 18
                        color: Appearance.colors.colOnSecondaryContainer
                    }
                    StyledText {
                        text: Translation.tr("Add scheme")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colOnSecondaryContainer
                    }
                }
            }
        }

        Item {
            id: chipsArea
            Layout.fillWidth: true
            Layout.fillHeight: true

            Flickable {
                id: chipsFlick
                anchors.fill: parent
                clip: true
                interactive: false
                contentWidth: Math.max(width, tiles.implicitWidth)
                contentHeight: height
                boundsBehavior: Flickable.StopAtBounds

                Behavior on contentX {
                    NumberAnimation { duration: 300; easing.type: Easing.OutCubic }
                }

                Row {
                    id: tiles
                    height: chipsFlick.height
                    spacing: root.tileGap

                    Repeater {
                        id: tileRepeater
                        model: root.options

                        delegate: RippleButton {
                            id: tile
                            required property var modelData

                            readonly property bool selected: ColorSchemes.current === modelData.value
                            readonly property var scheme: ColorSchemes.schemes[modelData.value] ?? null
                            readonly property string schemePath: scheme === null ? ""
                                : scheme.source === "user" ? `${ColorSchemes.userDir}/${modelData.value}.json`
                                : `${FileUtils.trimFileProtocol(Directories.scriptPath)}/colors/schemes/${modelData.value}.json`
                            property var palette: ({})
                            readonly property var dots: root.dotsFor(modelData.value)
                            readonly property color surfaceColor: modelData.value === "" ? Appearance.colors.colSecondaryContainer
                                : (palette.surface_container ?? palette.surface ?? Appearance.colors.colSecondaryContainer)
                            readonly property color textColor: modelData.value === "" ? Appearance.colors.colOnSecondaryContainer
                                : (palette.on_surface ?? Appearance.colors.colOnSecondaryContainer)

                            width: root.tileWidth
                            height: tiles.height
                            buttonRadius: 18
                            border: selected
                            borderWidth: 2
                            colBorder: dots.length > 0 ? dots[0] : Appearance.colors.colPrimary
                            colBackground: surfaceColor
                            colBackgroundHover: Qt.lighter(surfaceColor, 1.1)
                            colRipple: Qt.rgba(1, 1, 1, 0.25)
                            downAction: () => {
                                const value = modelData.value;
                                Qt.callLater(() => ColorSchemes.setScheme(value, false));
                            }

                            FileView {
                                path: tile.schemePath
                                onLoaded: {
                                    try {
                                        tile.palette = JSON.parse(text())[root.modeKey] ?? {};
                                    } catch (e) {
                                        tile.palette = {};
                                    }
                                }
                            }

                            contentItem: ColumnLayout {
                                spacing: 6

                                Row {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    Layout.margins: 2
                                    spacing: 5

                                    Repeater {
                                        model: tile.dots

                                        delegate: Rectangle {
                                            required property var modelData

                                            width: (parent.width - 5 * (tile.dots.length - 1)) / Math.max(1, tile.dots.length)
                                            height: parent.height
                                            radius: 11
                                            color: modelData
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.leftMargin: 4
                                    Layout.rightMargin: 4
                                    Layout.bottomMargin: 2
                                    spacing: 4

                                    StyledText {
                                        Layout.fillWidth: true
                                        text: tile.modelData.displayName
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        font.weight: tile.selected ? Font.DemiBold : Font.Normal
                                        color: tile.textColor
                                        elide: Text.ElideRight
                                    }

                                    MaterialSymbol {
                                        visible: tile.selected
                                        text: "check_circle"
                                        fill: 1
                                        iconSize: 18
                                        color: tile.dots.length > 0 ? tile.dots[0] : tile.textColor
                                    }
                                }
                            }
                        }
                    }
                }

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => {
                        const maxX = Math.max(0, chipsFlick.contentWidth - chipsFlick.width);
                        const raw = event.angleDelta.x !== 0 ? event.angleDelta.x : event.angleDelta.y;
                        const dx = -raw;
                        const canScroll = (dx < 0 && chipsFlick.contentX > 0) || (dx > 0 && chipsFlick.contentX < maxX);
                        if (canScroll) chipsFlick.contentX = Math.max(0, Math.min(maxX, chipsFlick.contentX + dx * 0.8));
                        else if (root.pager) root.pager.scrollSettingsBy(-event.angleDelta.y);
                        event.accepted = true;
                    }
                }
            }

            Timer {
                id: hoverTimer
                property int direction: 1
                interval: 360
                repeat: true
                triggeredOnStart: true
                onTriggered: root.scrollBy(direction * (root.tileWidth + root.tileGap))
            }

            Repeater {
                model: [-1, 1]

                delegate: Rectangle {
                    id: arrow
                    required property int modelData

                    readonly property bool shown: modelData < 0
                        ? chipsFlick.contentX > 2
                        : chipsFlick.contentX < chipsFlick.contentWidth - chipsFlick.width - 2

                    x: modelData < 0 ? 6 : chipsArea.width - width - 6
                    anchors.verticalCenter: parent.verticalCenter
                    width: 38
                    height: 38
                    radius: 19
                    color: Appearance.colors.colSecondaryContainer
                    opacity: shown ? (arrowArea.containsMouse ? 1 : 0.85) : 0
                    visible: opacity > 0.01

                    Behavior on opacity {
                        NumberAnimation { duration: 150 }
                    }

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: arrow.modelData < 0 ? "chevron_left" : "chevron_right"
                        iconSize: 24
                        color: Appearance.colors.colOnSecondaryContainer
                    }

                    MouseArea {
                        id: arrowArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: {
                            hoverTimer.direction = arrow.modelData;
                            hoverTimer.restart();
                        }
                        onExited: hoverTimer.stop()
                    }
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.max(0, root.accentHeight)
            clip: true

            ColumnLayout {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                spacing: 12

                AccentRow { slot: "primary"; label: Translation.tr("Primary") }
                AccentRow { slot: "secondary"; label: Translation.tr("Secondary") }
            }
        }
    }
}
