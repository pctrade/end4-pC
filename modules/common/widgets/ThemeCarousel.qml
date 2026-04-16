import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

Item {
    id: carouselRoot

    Component.onCompleted: listView.forceActiveFocus()

    readonly property real totalUsable: width - 16 * 2
    readonly property int  largeWidth:  Math.round(totalUsable * 0.38)
    readonly property int  mediumWidth: Math.round(totalUsable * 0.15)
    readonly property int  smallWidth:  Math.round(totalUsable * 0.03)
    readonly property int  itemSpacing: 8

    ListModel {
        id: themeModel
        ListElement { name: "Catppuccin";  baseColor: "#b4befe"; image: "..." }
        ListElement { name: "Dracula";     baseColor: "#bd93f9"; image: "..." }
        ListElement { name: "Gruvbox";     baseColor: "#98971a"; image: "..." }
        ListElement { name: "Kanagawa";    baseColor: "#938aa9"; image: "..." }
        ListElement { name: "Material";    baseColor: "transparent"; image: "..." }
        ListElement { name: "Nord";        baseColor: "#88c0d0"; image: "..." }
        ListElement { name: "Rosepine";    baseColor: "#ebbcba"; image: "..." }
        ListElement { name: "Tokyo Night"; baseColor: "#7aa2f7"; image: "..." }
    }

    ListView {
        id: listView
        anchors.fill: parent
        model: themeModel
        orientation: ListView.Horizontal
        spacing: carouselRoot.itemSpacing
        leftMargin: 16
        rightMargin: 16
        clip: true

        snapMode: ListView.SnapToItem
        highlightMoveDuration: 350
        flickDeceleration: 2000
        maximumFlickVelocity: 2500

        focus: true
        Keys.onLeftPressed:  if (currentIndex > 0) currentIndex--
        Keys.onRightPressed: if (currentIndex < count - 1) currentIndex++
        Keys.onReturnPressed: console.log("Tema seleccionado: " + themeModel.get(currentIndex).name)
        Keys.onEnterPressed:  console.log("Tema seleccionado: " + themeModel.get(currentIndex).name)

        delegate: Rectangle {
            id: card

            property int  distFromCurrent: Math.abs(index - listView.currentIndex)
            property bool isActive: distFromCurrent === 0

            width: {
                if (distFromCurrent === 0) return carouselRoot.largeWidth
                if (distFromCurrent === 1) return carouselRoot.mediumWidth
                return carouselRoot.smallWidth
            }

            height: listView.height
            radius: 28
            clip:   true

            color: model.name === "Material"
                   ? Appearance.colors.colPrimary
                   : model.baseColor

            Behavior on width {
                NumberAnimation {
                    duration: 350
                    easing.type: Easing.OutCubic
                }
            }

            Image {
                anchors.fill: parent
                source: model.image
                fillMode: Image.PreserveAspectCrop
                opacity: card.isActive ? 0.9 : 0.5
                Behavior on opacity {
                    NumberAnimation { duration: 350 }
                }
            }

            Text {
                text: model.name
                color: "white"
                font.pixelSize: 22
                font.bold: true
                visible: card.isActive
                opacity: card.isActive ? 1.0 : 0.0
                anchors {
                    bottom:  parent.bottom
                    left:    parent.left
                    margins: 24
                }
                Behavior on opacity {
                    NumberAnimation { duration: 300 }
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    if (!card.isActive) {
                        listView.currentIndex = index
                    } else {
                        console.log("Tema seleccionado: " + model.name)
                    }
                }
            }
        }
    }
}