import QtQuick
import QtQuick.Window
import "material-shapes.js" as MaterialShapes

Window {
    id: root
    title: "Shape Morph Demo"
    color: "#211F21"
    width: radius * 2 + padding * 2
    height: radius * 2 + padding * 2
    visible: true
    onClosing: Qt.quit()

    property double radius: 50
    property double padding: 50
    property double shapePadding: 12

    //////////////////////////////// Begin juicy part ////////////////////////////////
    // All 35 shapes
    property var shapeGetters: [ MaterialShapes.getCircle, MaterialShapes.getSquare, MaterialShapes.getSlanted, MaterialShapes.getArch, MaterialShapes.getFan, MaterialShapes.getArrow, MaterialShapes.getSemiCircle, MaterialShapes.getOval, MaterialShapes.getPill, MaterialShapes.getTriangle, MaterialShapes.getDiamond, MaterialShapes.getClamShell, MaterialShapes.getPentagon, MaterialShapes.getGem, MaterialShapes.getSunny, MaterialShapes.getVerySunny, MaterialShapes.getCookie4Sided, MaterialShapes.getCookie6Sided, MaterialShapes.getCookie7Sided, MaterialShapes.getCookie9Sided, MaterialShapes.getCookie12Sided, MaterialShapes.getGhostish, MaterialShapes.getClover4Leaf, MaterialShapes.getClover8Leaf, MaterialShapes.getBurst, MaterialShapes.getSoftBurst, MaterialShapes.getBoom, MaterialShapes.getSoftBoom, MaterialShapes.getFlower, MaterialShapes.getPuffy, MaterialShapes.getPuffyDiamond, MaterialShapes.getPixelCircle, MaterialShapes.getPixelTriangle, MaterialShapes.getBun, MaterialShapes.getHeart]
    property int shapeIndex: 0
    // Automatic morphing
    Timer {
        id: morphTimer
        interval: 700
        running: true
        repeat: true
        onTriggered: root.shapeIndex = (root.shapeIndex + 1) % root.shapeGetters.length;
    }
    // The actual shape
    ShapeCanvas {
        id: shapeCanvas
        z: 2
        anchors.centerIn: parent
        implicitWidth: root.radius * 2
        implicitHeight: root.radius * 2
        color: "#685496"
        roundedPolygon: root.shapeGetters[root.shapeIndex]()
    }
    //////////////////////////////// End juicy part ////////////////////////////////

    // Background circle
    Rectangle {
        z: 1
        anchors.fill: parent
        anchors.margins: root.padding - root.shapePadding
        width: radius * 2 + 50
        height: height
        radius: height / 2
        color: "#C7B3FC"
    }

    // Text
    Text {
        z: 3
        anchors {
            horizontalCenter: parent.horizontalCenter
            top: parent.top
            topMargin: 8
        }
        color: "#E6E1E3"
        text: "Shape %1/%2".arg(root.shapeIndex+1).arg(root.shapeGetters.length)
        font.pixelSize: 16
    }

    MouseArea {
        anchors.fill: parent
        onClicked: {
            morphTimer.running = !morphTimer.running
        }
        onWheel: (wheel) => {
            if (wheel.angleDelta.y < 0) {
                root.shapeIndex = (root.shapeIndex + 1) % root.shapeGetters.length;
            } else {
                root.shapeIndex = (root.shapeIndex - 1 + root.shapeGetters.length) % root.shapeGetters.length;
            }
        }
    }
}

