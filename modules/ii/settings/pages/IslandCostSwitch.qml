import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

// A Dynamic Island feature with what it actually costs: what runs, when, and a weight tag (heavy / medium /
// light). Turning it off stops that work, not just the drawing (each one was audited — ILHA.md § passivo).
RippleButton {
    id: row
    property string buttonIcon: ""
    property string title: ""
    property string detail: ""
    property string cost: "light"   // heavy | medium | light
    colBackgroundHover: "transparent"

    Layout.fillWidth: true
    Layout.bottomMargin: 6
    implicitHeight: content.implicitHeight + 12

    onClicked: row.checked = !row.checked

    readonly property color costColor: row.cost === "heavy" ? Appearance.colors.colError
        : row.cost === "medium" ? "#E3A33B" : Appearance.m3colors.m3success
    readonly property string costLabel: row.cost === "heavy" ? Translation.tr("Heavy")
        : row.cost === "medium" ? Translation.tr("Medium") : Translation.tr("Light")

    contentItem: RowLayout {
        id: content
        spacing: 10

        OptionalMaterialSymbol {
            icon: row.buttonIcon
            iconSize: Appearance.font.pixelSize.larger
            opacity: row.checked ? 1 : 0.5
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            RowLayout {
                spacing: 6
                StyledText {
                    text: row.title
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colOnSecondaryContainer
                }
                Rectangle {
                    implicitWidth: costText.implicitWidth + 12
                    implicitHeight: 17
                    radius: 8.5
                    color: ColorUtils.transparentize(row.costColor, row.checked ? 0.78 : 0.9)
                    StyledText {
                        id: costText
                        anchors.centerIn: parent
                        text: row.costLabel
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        font.weight: Font.DemiBold
                        color: row.costColor
                        opacity: row.checked ? 1 : 0.6
                    }
                }
            }
            StyledText {
                Layout.fillWidth: true
                visible: row.detail !== ""
                text: row.detail
                wrapMode: Text.WordWrap
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colOnSecondaryContainer
                opacity: 0.6
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
