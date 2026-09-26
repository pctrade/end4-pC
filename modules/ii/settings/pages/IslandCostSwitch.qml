import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// A Dynamic Island feature with what it actually costs: what runs, when, and how heavy it is (a three-bar meter,
// like signal strength). Turning it off stops that work, not just the drawing (each one was audited to be passive).
RippleButton {
    id: row
    property string buttonIcon: ""
    property string title: ""
    property string detail: ""
    property string cost: "light"   // heavy | medium | light
    colBackgroundHover: "transparent"

    Layout.fillWidth: true
    Layout.bottomMargin: 6
    implicitHeight: content.implicitHeight + 8
    font.pixelSize: Appearance.font.pixelSize.small

    onClicked: row.checked = !row.checked

    readonly property int level: row.cost === "heavy" ? 3 : row.cost === "medium" ? 2 : 1
    readonly property color levelColor: row.cost === "heavy" ? Appearance.colors.colError
        : row.cost === "medium" ? Appearance.colors.colTertiary : Appearance.colors.colPrimary
    readonly property string levelLabel: row.cost === "heavy" ? Translation.tr("High")
        : row.cost === "medium" ? Translation.tr("Medium") : Translation.tr("Low")

    contentItem: RowLayout {
        id: content
        spacing: 10

        OptionalMaterialSymbol {
            icon: row.buttonIcon
            iconSize: Appearance.font.pixelSize.larger
            opacity: row.checked ? 1 : 0.45
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: 0
            spacing: 0

            StyledText {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                text: row.title
                font: row.font
                color: Appearance.colors.colOnSecondaryContainer
                elide: Text.ElideRight
            }
            StyledText {
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                visible: row.detail !== ""
                text: row.detail
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
                elide: Text.ElideRight
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: 6
            opacity: row.checked ? 1 : 0.45

            Row {
                Layout.alignment: Qt.AlignVCenter
                spacing: 2
                Repeater {
                    model: 3
                    Rectangle {
                        required property int index
                        anchors.bottom: parent.bottom
                        width: 4
                        height: 6 + index * 4
                        radius: 2
                        color: index < row.level ? row.levelColor
                            : ColorUtils.transparentize(Appearance.colors.colOnSecondaryContainer, 0.82)
                    }
                }
            }
            StyledText {
                Layout.alignment: Qt.AlignVCenter
                Layout.preferredWidth: 52
                text: row.levelLabel
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }
        }

        StyledSwitch {
            Layout.fillWidth: false
            down: row.down
            checked: row.checked
            onClicked: row.clicked()
        }
    }
}
