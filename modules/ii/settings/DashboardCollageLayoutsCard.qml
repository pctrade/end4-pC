import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

DashboardCard {
    id: root

    property string title: ""
    property string icon: "dashboard_customize"
    property var tileShape: MaterialShape.Shape.Clover4Leaf

    readonly property string currentSignature: Collage.signature(Collage.tree)
    readonly property int gap: 8
    readonly property int count: Collage.presets.length
    readonly property real areaWidth: gridArea.width
    readonly property real areaHeight: gridArea.height
    readonly property int columns: bestColumns(areaWidth, areaHeight)
    readonly property int rows: Math.ceil(count / columns)
    readonly property real thumbWidth: (areaWidth - (columns - 1) * gap) / columns
    readonly property real thumbHeight: (areaHeight - (rows - 1) * gap) / rows

    function bestColumns(w, h) {
        if (w <= 0 || h <= 0 || count <= 0) return 10;
        let best = 1;
        let bestScore = Infinity;
        for (let c = 1; c <= count; c++) {
            const r = Math.ceil(count / c);
            const tw = (w - (c - 1) * gap) / c;
            const th = (h - (r - 1) * gap) / r;
            if (tw < 30 || th < 20) continue;
            const empty = (r * c - count) / (r * c);
            const score = Math.abs(Math.log(tw / th / 1.6)) + empty * 3;
            if (score < bestScore) {
                bestScore = score;
                best = c;
            }
        }
        return best;
    }

    tint: Appearance.colors.colTertiaryContainer

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            MaterialShapeWrappedMaterialSymbol {
                shape: root.tileShape
                text: root.icon
                iconSize: 22
                fill: 1
                padding: 9
                color: Appearance.colors.colTertiary
                colSymbol: Appearance.colors.colOnTertiary
            }

            StyledText {
                Layout.fillWidth: true
                text: root.title
                font.pixelSize: Appearance.font.pixelSize.larger
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnTertiaryContainer
                elide: Text.ElideRight
            }

            RippleButton {
                id: resetButton
                enabled: Collage.leafCount > 1
                opacity: enabled ? 1 : 0.5
                implicitHeight: 36
                horizontalPadding: 16
                buttonRadius: 18
                colBackground: Appearance.colors.colTertiary
                colBackgroundHover: Appearance.colors.colTertiary
                colRipple: Qt.rgba(1, 1, 1, 0.3)
                downAction: () => Qt.callLater(() => Collage.reset())

                contentItem: RowLayout {
                    spacing: 6

                    MaterialSymbol {
                        text: "restart_alt"
                        iconSize: 18
                        fill: 1
                        color: Appearance.colors.colOnTertiary
                    }
                    StyledText {
                        text: Translation.tr("Reset")
                        font.pixelSize: Appearance.font.pixelSize.small
                        font.weight: Font.Medium
                        color: Appearance.colors.colOnTertiary
                    }
                }
            }
        }

        Item {
            id: gridArea
            Layout.fillWidth: true
            Layout.fillHeight: true

        Grid {
            columns: root.columns
            spacing: root.gap

            Repeater {
                model: Collage.presets

                delegate: Rectangle {
                    id: thumb
                    required property var modelData

                    readonly property bool selected: root.currentSignature === Collage.signature(modelData.tree)

                    width: root.thumbWidth
                    height: root.thumbHeight
                    radius: 10
                    color: selected ? Appearance.colors.colTertiary : Qt.rgba(1, 1, 1, 0.12)

                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }

                    Item {
                        anchors.fill: parent
                        anchors.margins: 5

                        Repeater {
                            model: Collage.rects(thumb.modelData.tree, 0, 0, 1, 1, [])

                            delegate: Rectangle {
                                required property var modelData
                                x: modelData.x * parent.width + 1.5
                                y: modelData.y * parent.height + 1.5
                                width: modelData.w * parent.width - 3
                                height: modelData.h * parent.height - 3
                                radius: 4
                                color: thumb.selected ? Appearance.colors.colOnTertiary : Appearance.colors.colTertiary
                                opacity: thumb.selected ? 0.9 : 0.7
                            }
                        }
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            const spec = thumb.modelData.tree;
                            Qt.callLater(() => Collage.applyPreset(spec));
                        }
                    }
                }
            }
        }
        }
    }
}
