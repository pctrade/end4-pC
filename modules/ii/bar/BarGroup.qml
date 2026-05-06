import qs.modules.common
import QtQuick
import QtQuick.Layouts

Item {
    id: root
    property bool vertical: false
    property real padding: 5
    
    property int currentIndex: 0
    property int totalCount: 0

    readonly property real fullRadius: height / 2
    readonly property real midRadius: Config.options.bar.cornerStyle === 2 ? Appearance.rounding.unsharpenmore + 2 : Appearance.rounding.unsharpenmore

    property real startRadius: {
        if (totalCount <= 1) return fullRadius; 
        if (currentIndex === 0) return fullRadius; 
        return midRadius; 
    }

    property real endRadius: {
        if (totalCount <= 1) return fullRadius; 
        if (currentIndex === totalCount - 1) return fullRadius;
        return midRadius;
    }

    implicitWidth: vertical ? Appearance.sizes.baseVerticalBarWidth : (gridLayout.implicitWidth + padding * 2)
    implicitHeight: vertical ? (gridLayout.implicitHeight + padding * 2) : Appearance.sizes.baseBarHeight
    default property alias items: gridLayout.children

    Rectangle {
        id: background
        anchors {
            fill: parent
            topMargin: root.vertical ? 0 : 4
            bottomMargin: root.vertical ? 0 : 4
            leftMargin: root.vertical ? 4 : 0
            rightMargin: root.vertical ? 4 : 0
        }
        color: Config.options?.bar.borderless === "transparent" || Config.options.bar.cornerStyle === 3 ? "transparent" : Config.options.bar.cornerStyle === 2 ? Appearance.colors.colLayer0 : Appearance.colors.colLayer1
        
        topLeftRadius: Config.options?.bar.borderless === "separated" ? fullRadius : startRadius
        bottomLeftRadius: Config.options?.bar.borderless === "separated" ? fullRadius : root.vertical ? endRadius : startRadius
        topRightRadius: Config.options?.bar.borderless === "separated" ? fullRadius : root.vertical ? startRadius : endRadius
        bottomRightRadius: Config.options?.bar.borderless === "separated" ? fullRadius : endRadius
        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }
    }

    GridLayout {
        id: gridLayout
        columns: root.vertical ? 1 : -1
        anchors.centerIn: parent
        columnSpacing: 0
        rowSpacing: 0
    }
}