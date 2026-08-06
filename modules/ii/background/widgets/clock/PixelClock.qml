pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.ii.background.widgets

Item {
    id: root

    readonly property bool isVertical: Config.options.background.widgets.clock.pixel.orientation === "vertical"

    implicitWidth: isVertical ? 276 : 420
    implicitHeight: isVertical ? 252 : 150

    readonly property string glyphTopLeft: DateTime.digitH0
    readonly property string glyphTopRight: DateTime.digitH1
    readonly property string glyphBottomLeft: DateTime.digitM0
    readonly property string glyphBottomRight: DateTime.digitM1
    readonly property color tintSoft: Appearance.colors.colPrimaryContainer
    readonly property color tintBold: Appearance.colors.colPrimary

    readonly property real fringeSize: isVertical ? root.width * 0.026 : root.height * 0.03
    readonly property real tileW: isVertical ? root.width * 0.66 : root.width * 0.30
    readonly property real tileH: isVertical ? root.height * 0.66 : root.height * 0.9
    readonly property real glyphSize: isVertical ? root.height * 0.66 : root.height * 0.85

    readonly property real pos0X: isVertical ? root.width * 0.00 : root.width * 0.00
    readonly property real pos1X: isVertical ? root.width * 0.30 : root.width * 0.15
    readonly property real pos2X: isVertical ? root.width * 0.00 : root.width * 0.46
    readonly property real pos3X: isVertical ? root.width * 0.30 : root.width * 0.60

    readonly property real pos0Y: isVertical ? root.height * -0.04 : root.height * 0.05
    readonly property real pos1Y: isVertical ? root.height * -0.04 : root.height * 0.05
    readonly property real pos2Y: isVertical ? root.height * 0.42 : root.height * 0.05
    readonly property real pos3Y: isVertical ? root.height * 0.42  : root.height * 0.05

    readonly property real colonX: root.pos1X + root.tileW + (root.pos2X - (root.pos1X + root.tileW)) / 2 - root.width * 0.03
    readonly property real colonDotSize: root.height * 0.2
    readonly property real colonGap: root.height * 0.04

    function ringSamples(count, radius) {
        let pts = [{ dx: 0, dy: 0 }]
        for (let i = 0; i < count; i++) {
            const a = (i / count) * Math.PI * 2
            pts.push({ dx: Math.cos(a) * radius, dy: Math.sin(a) * radius })
        }
        return pts
    }
    readonly property var fringeSamples: ringSamples(16, fringeSize)

    StyledDropShadow {
        id: glyphShadow
        target: glyphStage
        visible: Config.options.background.widgets.enableShadows ?? false
    }

    Item {
        id: glyphStage
        anchors.fill: parent

        component GlyphTile: Text {
            width: root.tileW
            height: root.tileH
            font {
                family: "Google Sans Flex"
                weight: 1000
                bold: true
                pixelSize: root.glyphSize
                variableAxes: ({ "wght": 1000 })
            }
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        Item {
            id: tileAFace
            anchors.fill: parent
            visible: false
            GlyphTile {
                x: root.pos0X
                y: root.pos0Y
                text: root.glyphTopLeft
                color: root.tintSoft
            }
        }
        Item {
            id: tileAPunch
            anchors.fill: parent
            visible: false
            Repeater {
                model: root.fringeSamples
                Item {
                    id: punchA
                    required property var modelData
                    anchors.fill: parent
                    GlyphTile { x: root.pos1X + punchA.modelData.dx; y: root.pos1Y + punchA.modelData.dy; text: root.glyphTopRight; color: "black" }
                    GlyphTile { x: root.pos2X + punchA.modelData.dx; y: root.pos2Y + punchA.modelData.dy; text: root.glyphBottomLeft; color: "black" }
                    GlyphTile { x: root.pos3X + punchA.modelData.dx; y: root.pos3Y + punchA.modelData.dy; text: root.glyphBottomRight; color: "black" }
                }
            }
        }
        OpacityMask {
            anchors.fill: parent
            source: tileAFace
            maskSource: tileAPunch
            invert: true
            z: 0
        }

        Item {
            id: tileBFace
            anchors.fill: parent
            visible: false
            GlyphTile {
                x: root.pos1X
                y: root.pos1Y
                text: root.glyphTopRight
                color: root.tintBold
            }
        }
        Item {
            id: tileBPunch
            anchors.fill: parent
            visible: false
            Repeater {
                model: root.fringeSamples
                Item {
                    id: punchB
                    required property var modelData
                    anchors.fill: parent
                    GlyphTile { x: root.pos2X + punchB.modelData.dx; y: root.pos2Y + punchB.modelData.dy; text: root.glyphBottomLeft; color: "black" }
                    GlyphTile { x: root.pos3X + punchB.modelData.dx; y: root.pos3Y + punchB.modelData.dy; text: root.glyphBottomRight; color: "black" }
                }
            }
        }
        OpacityMask {
            anchors.fill: parent
            source: tileBFace
            maskSource: tileBPunch
            invert: true
            z: 1
        }

        Item {
            id: tileCFace
            anchors.fill: parent
            visible: false
            GlyphTile {
                x: root.pos2X
                y: root.pos2Y
                text: root.glyphBottomLeft
                color: root.tintBold
            }
        }
        Item {
            id: tileCPunch
            anchors.fill: parent
            visible: false
            Repeater {
                model: root.fringeSamples
                Item {
                    id: punchC
                    required property var modelData
                    anchors.fill: parent
                    GlyphTile { x: root.pos3X + punchC.modelData.dx; y: root.pos3Y + punchC.modelData.dy; text: root.glyphBottomRight; color: "black" }
                }
            }
        }
        OpacityMask {
            anchors.fill: parent
            source: tileCFace
            maskSource: tileCPunch
            invert: true
            z: 2
        }

        GlyphTile {
            x: root.pos3X
            y: root.pos3Y
            text: root.glyphBottomRight
            color: root.tintSoft
            z: 3
        }

        Column {
            visible: !root.isVertical
            x: root.colonX
            y: root.pos0Y + root.tileH / 2 - height / 2
            spacing: root.colonGap
            z: 4

            Rectangle {
                width: root.colonDotSize
                height: root.colonDotSize
                radius: width / 2
                color: root.tintBold
                anchors.horizontalCenter: parent.horizontalCenter
            }
            Rectangle {
                width: root.colonDotSize
                height: root.colonDotSize
                radius: width / 2
                color: root.tintBold
                anchors.horizontalCenter: parent.horizontalCenter
            }
        }
    }
}