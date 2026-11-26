import QtQuick
import QtQuick.Shapes
import Qt5Compat.GraphicalEffects
import qs.modules.common

Item {
    id: root

    enum CornerEnum { TopLeft, TopRight, BottomLeft, BottomRight }
    property var corner: RoundCorner.CornerEnum.TopLeft
    property real leftVisualMargin: 0
    property real topVisualMargin: 0
    property real rightVisualMargin: 0
    property real bottomVisualMargin: 0

    property int implicitSize: 25
    property color color: "#000000"
    property bool glass: false
    readonly property bool glassOn: glass && color.a > 0 && Config.options.background.widgets.glass.enable

    implicitWidth: implicitSize
    implicitHeight: implicitSize

    property bool isTopLeft: corner === RoundCorner.CornerEnum.TopLeft
    property bool isBottomLeft: corner === RoundCorner.CornerEnum.BottomLeft
    property bool isTopRight: corner === RoundCorner.CornerEnum.TopRight
    property bool isBottomRight: corner === RoundCorner.CornerEnum.BottomRight
    property bool isTop: isTopLeft || isTopRight
    property bool isBottom: isBottomLeft || isBottomRight
    property bool isLeft: isTopLeft || isBottomLeft
    property bool isRight: isTopRight || isBottomRight

    Item {
        id: glassLayer
        visible: root.glassOn
        x: shape.x
        y: shape.y
        width: root.implicitSize
        height: root.implicitSize
        layer.enabled: root.glassOn
        layer.effect: OpacityMask {
            maskSource: shape
        }

        WindowGlass {
            anchors.fill: parent
            glassEnabled: root.glassOn
            tint: root.color
        }
    }

    Shape {
        id: shape
        visible: !root.glassOn
        x: root.isLeft ? root.leftVisualMargin : root.width - shape.width - root.rightVisualMargin
        y: root.isTop ? root.topVisualMargin : root.height - shape.height - root.bottomVisualMargin
        layer.enabled: true
        layer.smooth: true
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            id: shapePath
            strokeWidth: 0
            fillColor: root.color
            pathHints: ShapePath.PathSolid & ShapePath.PathNonIntersecting

            startX: switch (root.corner) {
                case RoundCorner.CornerEnum.TopLeft:
                case RoundCorner.CornerEnum.BottomLeft: return 0;
                case RoundCorner.CornerEnum.TopRight:
                case RoundCorner.CornerEnum.BottomRight: return root.implicitSize;
            }
            startY: switch (root.corner) {
                case RoundCorner.CornerEnum.TopLeft:
                case RoundCorner.CornerEnum.TopRight: return 0;
                case RoundCorner.CornerEnum.BottomLeft:
                case RoundCorner.CornerEnum.BottomRight: return root.implicitSize;
            }
            PathAngleArc {
                moveToStart: false
                centerX: root.implicitSize - shapePath.startX
                centerY: root.implicitSize - shapePath.startY
                radiusX: root.implicitSize
                radiusY: root.implicitSize
                startAngle: switch (root.corner) {
                    case RoundCorner.CornerEnum.TopLeft: return 180;
                    case RoundCorner.CornerEnum.TopRight: return -90;
                    case RoundCorner.CornerEnum.BottomLeft: return 90;
                    case RoundCorner.CornerEnum.BottomRight: return 0;
                }
                sweepAngle: 90
            }
            PathLine {
                x: shapePath.startX
                y: shapePath.startY
            }
        }
    }

}
