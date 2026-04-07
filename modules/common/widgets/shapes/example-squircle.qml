import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import "material-shapes.js" as MaterialShapes
import "shapes/corner-rounding.js" as CornerRounding
import "geometry/offset.js" as Offset

Window {
    id: root
    title: "Custom shape: Squircle"
    color: "#211F21"
    width: radius * 2 + padding * 2
    height: radius * 2 + padding * 2
    visible: true
    onClosing: Qt.quit()

    property double radius: 50
    property double padding: 50
    property double shapePadding: 12

    RowLayout {
        id: rowLayout
        anchors.centerIn: parent
        spacing: 10
        Text {
            text: "Liquid"
            color: "#E6E1E3"
            font.pixelSize: root.radius / 2
        }
        //////////////////////////////// Begin juicy part ////////////////////////////////
        ShapeCanvas {
            id: shapeCanvas
            z: 2
            implicitWidth: root.radius * 2
            implicitHeight: root.radius * 2
            color: "#FF0036"
            // Nonzero smoothing of corner rounding gives squircle shape
            roundedPolygon: MaterialShapes.customPolygon([
                // bottom-right
                new MaterialShapes.PointNRound(new Offset.Offset(1, 0.67), // We specify the point...
                new CornerRounding.CornerRounding(0.211, 2)),              // ...and the rounding. The 1st value is size of the rounding, 2nd is smoothing
                // bottom-left
                new MaterialShapes.PointNRound(new Offset.Offset(0, 0.67), 
                new CornerRounding.CornerRounding(0.207, 2)), 
                // top-left
                new MaterialShapes.PointNRound(new Offset.Offset(0, 0), 
                new CornerRounding.CornerRounding(0.207, 2)), 
                // top-right
                new MaterialShapes.PointNRound(new Offset.Offset(1, 0), 
                new CornerRounding.CornerRounding(0.211, 2)),
            ], 1).normalized() // Make sure it's properly centered and scaled to perfectly fit [0, 1]
        }

        // Note 1:
        // The corner rounding is high just so it is obvious this is a squircle
        // Obvious squircles are atrocious. Obvious squircles are atrocious. Obvious squircles are atrocious. Obvious squircles are atrocious. Obvious squircles are atrocious. 

        // Note 2:
        // Unfortunately the YouTube logo is not simply a squircle
        // You'll probably need points in the middle of the edges for the right shape
        // I'm lazy, so this is an exercise for the reader

        //////////////////////////////// End juicy part ////////////////////////////////
        Text {
            Layout.leftMargin: -rowLayout.spacing + 2
            text: "ass"
            color: "#E6E1E3"
            font.pixelSize: root.radius / 2
        }
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
        text: "Custom Squircle Shape"
        font.pixelSize: 16
    }
}
