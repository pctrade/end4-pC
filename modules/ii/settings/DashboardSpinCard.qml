import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

DashboardCard {
    id: root

    property string controlKey: ""
    property string title: ""
    property string icon: "tune"
    property var tileShape: MaterialShape.Shape.Gem

    property var override: null
    readonly property var control: override ?? SettingsQuickControls.controls[controlKey] ?? null
    readonly property real current: control ? control.get() : 0

    tint: Appearance.colors.colPrimaryContainer

    function step(direction) {
        if (!control) return;
        const stepSize = control.stepSize ?? 1;
        const next = Math.max(control.from ?? -Infinity, Math.min(control.to ?? Infinity, current + direction * stepSize));
        Qt.callLater(() => control.set(next));
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 0

        RowLayout {
            Layout.fillWidth: true
            spacing: 10

            MaterialShapeWrappedMaterialSymbol {
                shape: root.tileShape
                text: root.icon
                iconSize: 22
                fill: 1
                padding: 9
                color: Appearance.colors.colPrimary
                colSymbol: Appearance.colors.colOnPrimary
            }

            StyledText {
                Layout.fillWidth: true
                text: root.title
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.DemiBold
                color: Appearance.colors.colOnPrimaryContainer
                wrapMode: Text.WordWrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
        }

        Item { Layout.fillHeight: true }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: [-1, 1]

                delegate: Item {
                    required property int modelData
                    Layout.fillWidth: modelData === 1
                    implicitWidth: 40
                    implicitHeight: 40

                    RippleButton {
                        anchors.right: modelData === 1 ? parent.right : undefined
                        implicitWidth: 40
                        implicitHeight: 40
                        buttonRadius: 20
                        colBackground: Qt.rgba(1, 1, 1, 0.14)
                        colBackgroundHover: Qt.rgba(1, 1, 1, 0.26)
                        colRipple: Qt.rgba(1, 1, 1, 0.35)
                        downAction: () => root.step(modelData)
                        contentItem: Item {
                            MaterialSymbol {
                                anchors.centerIn: parent
                                text: modelData === 1 ? "add" : "remove"
                                iconSize: 22
                                color: Appearance.colors.colOnPrimaryContainer
                            }
                        }
                    }
                }
            }
        }
    }

    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14
        text: Math.round(root.current)
        font.pixelSize: 28
        font.weight: Font.Light
        color: Appearance.colors.colOnPrimaryContainer
    }
}
