import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import QtQuick
import QtQuick.Controls
import Qt5Compat.GraphicalEffects

/**
 * A progress bar with both ends rounded and text acts as clipping like OneUI 7's battery indicator.
 */
ProgressBar {
    id: root
    property bool vertical: false
    property real valueBarWidth: 30
    property real valueBarHeight: 18
    property color highlightColor: Appearance?.colors.colOnSecondaryContainer ?? "#685496"
    property color trackColor: ColorUtils.transparentize(highlightColor, 0.5) ?? "#F1D3F9"
    property alias radius: contentItem.radius
    property string text
    property bool showTip: true 
    property real tipWidth: 2   
    property real tipHeight: 10  
    
    default property Item textMask: Item {
        width: valueBarWidth
        height: valueBarHeight
        StyledText {
            anchors.centerIn: parent
            font: root.font
            text: root.text
        }
    }
    
    text: Math.round(value * 100)
    font {
        pixelSize: 13
        weight: text.length > 2 ? Font.Medium : Font.DemiBold
    }
    
    background: Item {
        implicitHeight: valueBarHeight
        implicitWidth: valueBarWidth + (root.showTip ? root.tipWidth + 1 : 0)
    }
    
    contentItem: Item {
        id: contentItem
        anchors.fill: parent
        property alias radius: mainRect.radius
        visible: false
        
        Rectangle {
            id: mainRect
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }
            width: root.valueBarWidth
            radius: 6
            color: root.trackColor
            
            Rectangle {
                id: progressFill
                anchors {
                    top: parent.top
                    bottom: parent.bottom
                    left: parent.left
                    right: undefined
                }
                width: parent.width * root.visualPosition
                height: parent.height
                states: State {
                    name: "vertical"
                    when: root.vertical
                    AnchorChanges {
                        target: progressFill
                        anchors {
                            top: undefined
                            bottom: parent.bottom
                            left: parent.left
                            right: parent.right
                        }
                    }
                    PropertyChanges {
                        target: progressFill
                        width: parent.width
                        height: parent.height * root.visualPosition
                    }
                }
                radius: Appearance.rounding.unsharpen
                color: root.highlightColor
            }
        }
        
        // Tiny box
        Rectangle {
            id: batteryTip
            visible: root.showTip
            anchors {
                left: mainRect.right
                leftMargin: 1
                verticalCenter: parent.verticalCenter
            }
            width: root.tipWidth
            height: root.tipHeight
            radius: 1
            color: root.trackColor
            
            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: root.highlightColor
                visible: root.visualPosition > 0.95 
            }
        }
    }
    
    OpacityMask {
        id: roundingMask
        visible: false
        anchors.fill: parent
        source: contentItem
        maskSource: Item {
            width: contentItem.width
            height: contentItem.height
            Rectangle {
                width: root.valueBarWidth
                height: root.valueBarHeight
                radius: contentItem.radius
            }
            Rectangle {
                visible: root.showTip
                anchors {
                    left: parent.left
                    leftMargin: root.valueBarWidth + 1
                    verticalCenter: parent.verticalCenter
                }
                width: root.tipWidth
                height: root.tipHeight
                radius: 1
            }
        }
    }
    
    OpacityMask {
        anchors.fill: parent
        source: roundingMask
        invert: true
        maskSource: root.textMask
    }
}