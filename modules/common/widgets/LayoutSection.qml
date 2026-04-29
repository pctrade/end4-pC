import qs.modules.common
import qs.modules.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts

ContentSubsection {
    id: root

    property string sectionTitle
    property var layout
    property var getWidgetName: (id) => id
    property var availableWidgets: []
    property var onUpdate: (list) => {}

    title: sectionTitle
    Layout.fillWidth: true

    RowLayout {
        Layout.fillWidth: true
        spacing: 2

        Item {
            Layout.fillWidth: true
            implicitHeight: itemFlow.implicitHeight

            Flow {
                id: itemFlow
                anchors.fill: parent
                spacing: 2

                Repeater {
                    id: itemRepeater
                    model: root.layout

                    delegate: SelectionGroupButton {
                        required property var modelData
                        required property int index
                        isDragging: dragHandler.active
                        leftmost: true; rightmost: true
                        buttonIcon: "close"
                        buttonText: root.getWidgetName(modelData)
                        toggled: !dragHandler.active

                        DragHandler {
                            id: dragHandler
                            target: null

                            function findNewIndex(dragX, dragY) {
                                let newIndex = index
                                let minDist = Infinity

                                for (let i = 0; i < itemRepeater.count; i++) {
                                    if (i === index) continue
                                    const child = itemRepeater.itemAt(i)
                                    if (!child) continue
                                    const childCenter = child.mapToItem(null, child.width / 2, child.height / 2)
                                    const dx = dragX - childCenter.x
                                    const dy = dragY - childCenter.y
                                    const dist = Math.sqrt(dx * dx + dy * dy)
                                    if (dist < minDist) {
                                        minDist = dist
                                        newIndex = i
                                    }
                                }
                                return newIndex
                            }

                            onActiveChanged: {
                                if (!active) {
                                    dropIndicator.visible = false
                                    dropIndicator.targetIndex = -1
                                    const dragX = dragHandler.centroid.scenePosition.x
                                    const dragY = dragHandler.centroid.scenePosition.y
                                    const newIndex = findNewIndex(dragX, dragY)
                                    if (newIndex !== index) {
                                        let list = root.layout.slice()
                                        const item = list.splice(index, 1)[0]
                                        list.splice(newIndex, 0, item)
                                        root.onUpdate(list)
                                    }
                                }
                            }

                            onCentroidChanged: {
                                if (!active) return
                                const dragX = dragHandler.centroid.scenePosition.x
                                const dragY = dragHandler.centroid.scenePosition.y
                                const newIndex = findNewIndex(dragX, dragY)

                                if (newIndex !== index) {
                                    const refChild = itemRepeater.itemAt(newIndex)
                                    if (refChild) {
                                        const refLocal = refChild.mapToItem(itemFlow, 0, 0)
                                        dropIndicator.x = newIndex < index
                                            ? refLocal.x - 5
                                            : refLocal.x + refChild.width + 1
                                        dropIndicator.y = refLocal.y
                                        dropIndicator.height = refChild.height
                                        dropIndicator.visible = true
                                        dropIndicator.targetIndex = newIndex
                                    }
                                } else {
                                    dropIndicator.visible = false
                                    dropIndicator.targetIndex = -1
                                }
                            }
                        }

                        onClicked: {
                            let list = root.layout.slice()
                            list.splice(index, 1)
                            root.onUpdate(list)
                        }
                    }
                }
            }

            Rectangle {
                id: dropIndicator
                property int targetIndex: -1
                visible: false
                width: 3
                height: 32 
                radius: 2
                color: Appearance.colors.colPrimary

                Behavior on x { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                Behavior on y { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
                Behavior on opacity { NumberAnimation { duration: 150 } }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: -4
                    width: 8; height: 8; radius: 4
                    color: Appearance.colors.colPrimary
                }

                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: -4
                    width: 8; height: 8; radius: 4
                    color: Appearance.colors.colPrimary
                }
            }
        }

        ToolbarPairedFab {
            Layout.alignment: Qt.AlignVCenter
            Layout.topMargin: -15
            iconText: dropdown.visible ? "keyboard_arrow_up" : "add"
            onClicked: dropdown.visible = !dropdown.visible
        }
    }

    Item {
        id: dropdown
        Layout.fillWidth: true
        Layout.topMargin: 5
        visible: false
        implicitHeight: visible ? dropdownRect.height + 8 : 0
        Behavior on opacity { NumberAnimation { duration: 200 } }

        Rectangle {
            id: dropdownRect
            anchors.top: parent.top
            anchors.topMargin: 4
            width: parent.width
            implicitHeight: dropdownFlow.implicitHeight + 16
            color: Appearance.colors.colLayer1
            radius: Appearance.rounding.large
            border.width: 1
            border.color: Appearance.colors.colLayer0Border

            Flow {
                id: dropdownFlow
                anchors { fill: parent; margins: 8 }
                spacing: 2
                Repeater {
                    model: root.availableWidgets
                    delegate: SelectionGroupButton {
                        required property var modelData
                        leftmost: true; rightmost: true
                        buttonText: modelData.name
                        buttonIcon: modelData.icon ?? ""  
                        onClicked: {
                            let list = root.layout.slice()
                            list.push(modelData.id)
                            root.onUpdate(list)
                            dropdown.visible = false
                        }
                    }
                }
                StyledText {
                    visible: root.availableWidgets.length === 0
                    text: Translation.tr("No widgets available")
                    color: Appearance.colors.colSubtext
                    font.pixelSize: Appearance.font.pixelSize.small
                }
            }
        }
    }
}
