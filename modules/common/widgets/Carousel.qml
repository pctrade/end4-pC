import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects

Item {
    id: root

    property var model: []
    property Component delegate: null
    property bool showCurrentIndicator: true
    property real largeItemWidthRatio: 0.52
    property real mediumItemWidthRatio: 0.32
    property real smallItemWidthRatio: 0.12
    property real itemSpacing: 6
    property alias currentIndex: listView.currentIndex

    property bool wheelEnabled: true
    property bool dragEnabled: true

    property int hoveredIndex: -1
    readonly property int focusedIndex: hoveredIndex >= 0 ? hoveredIndex : listView.currentIndex
    
    property var clickAction: null

    signal wallpaperSelected(string path)

    implicitHeight: 220

    function widthForOffset(offset) {
        if (offset === 0) return width * largeItemWidthRatio
        if (Math.abs(offset) === 1) return width * mediumItemWidthRatio
        return width * smallItemWidthRatio
    }

    function handleItemClick(index, modelData) {
        if (root.clickAction) {
            root.clickAction(index, modelData);
            return;
        }
        listView.currentIndex = index;
        root.wallpaperSelected(modelData);
    }

    ListView {
        id: listView
        anchors.fill: parent
        orientation: ListView.Horizontal
        spacing: root.itemSpacing
        clip: true
        interactive: root.dragEnabled
        snapMode: ListView.SnapOneItem
        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: 0
        preferredHighlightEnd: 0
        highlightMoveDuration: 250
        model: root.model

        WheelHandler {
            id: wheelHandler
            target: listView
            enabled: root.wheelEnabled
            acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
            property bool coolingDown: false
            onWheel: (event) => {
                if (coolingDown) return
                coolingDown = true
                debounceTimer.restart()

                if (event.angleDelta.y < 0 || event.angleDelta.x > 0)
                    listView.incrementCurrentIndex()
                else
                    listView.decrementCurrentIndex()
            }
        }

        Timer { // just in case =P
            id: debounceTimer
            interval: 80
            onTriggered: wheelHandler.coolingDown = false
        }

        delegate: Item {
            id: itemRoot
            required property var modelData
            required property int index

            property int offsetFromCurrent: index - root.focusedIndex
            width: root.widthForOffset(offsetFromCurrent)
            height: listView.height

            Behavior on width {
                animation: Appearance.animation.elementMoveSmall.numberAnimation.createObject(this)
            }

            Rectangle {
                id: cardBg
                anchors.fill: parent
                radius: Appearance.rounding.large
                color: Appearance.colors.colSurfaceContainerHigh
                clip: true

                Loader {
                    anchors.fill: parent
                    sourceComponent: root.delegate ?? defaultImageDelegate
                    property var modelData: itemRoot.modelData
                    property real fixedWidth: root.width * root.largeItemWidthRatio
                    property real fixedHeight: listView.height
                }

                Rectangle { // later I'll see if I remove it
                    id: currentIndicator
                    visible: itemRoot.index === 0 && root.showCurrentIndicator
                    anchors.centerIn: parent
                    width: 32
                    height: 32
                    radius: width / 2
                    color: Appearance.colors.colPrimary

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "check"
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colOnPrimary
                        fill: 1
                    }
                }

                layer.enabled: true
                layer.effect: OpacityMask {
                    maskSource: Rectangle {
                        width: cardBg.width
                        height: cardBg.height
                        radius: cardBg.radius
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onEntered: root.hoveredIndex = itemRoot.index
                    onExited: if (root.hoveredIndex === itemRoot.index)
                                root.hoveredIndex = -1
                    onClicked: root.handleItemClick(itemRoot.index, itemRoot.modelData)
                }
            }
        }
    }

    Component {
        id: defaultImageDelegate
        StyledImage {
            id: img
            property real fixedWidth: parent?.fixedWidth ?? width
            property real fixedHeight: parent?.fixedHeight ?? height
            source: "file://" + FileUtils.trimFileProtocol(modelData)
            fillMode: Image.PreserveAspectCrop
            cache: true
            asynchronous: true
            sourceSize.width: fixedWidth * 1.5
            sourceSize.height: fixedHeight * 1.5
        }
    }
}