import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: root

    required property var collage

    readonly property var result: root.collage.result

    Repeater {
        model: ScriptModel {
            values: root.result.leaves
            objectProp: "id"
        }

        delegate: Item {
            id: tileDrop
            required property var modelData

            x: modelData.x
            y: modelData.y
            width: modelData.w
            height: modelData.h

            Behavior on x { enabled: !Collage.dragging; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on y { enabled: !Collage.dragging; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on width { enabled: !Collage.dragging; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on height { enabled: !Collage.dragging; NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

            DropArea {
                id: dropArea
                anchors.fill: parent
                keys: ["text/uri-list"]
                onEntered: drag => { drag.accepted = drag.hasUrls && drag.urls.length === 1 }
                onDropped: drop => {
                    drop.accepted = Collage.dropImage(tileDrop.modelData.id, drop.urls)
                }

                Rectangle {
                    anchors.fill: parent
                    visible: dropArea.containsDrag
                    radius: Collage.radius
                    color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.55)
                    border.width: 3
                    border.color: Appearance.colors.colPrimary

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        MaterialSymbol {
                            Layout.alignment: Qt.AlignHCenter
                            text: "add_photo_alternate"
                            iconSize: 48
                            color: Appearance.colors.colOnPrimary
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: Translation.tr("Drop to replace this wallpaper")
                            color: Appearance.colors.colOnPrimary
                        }
                    }
                }
            }
        }
    }
}
