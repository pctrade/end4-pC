import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts

RippleButton {
    id: root
    glass: true
    property string displayText: ""
    property color buttonColor: Appearance.colors.colLayer2
    colBackground: buttonColor
    colBackgroundHover: Appearance.colors.colPrimaryContainer
    buttonRadius: Appearance.rounding.full

    implicitWidth: contentItem.implicitWidth + horizontalPadding * 2 + 10
    implicitHeight: contentItem.implicitHeight + verticalPadding * 2 + 20 

    contentItem: Item {
        anchors.centerIn: parent
        implicitWidth: languageRow.implicitWidth
        implicitHeight: languageText.implicitHeight
        RowLayout {
            id: languageRow
            anchors.centerIn: parent
            spacing: 0
            StyledText {
                id: languageText
                Layout.alignment: Qt.AlignVCenter
                Layout.leftMargin: 5
                text: root.displayText
                color: Appearance.colors.colOnLayer2
                font.pixelSize: Appearance.font.pixelSize.small
            }
            MaterialSymbol {
                Layout.alignment: Qt.AlignVCenter
                iconSize: Appearance.font.pixelSize.hugeass
                text: "arrow_drop_down"
                color: Appearance.colors.colOnLayer2
            }
        }
    }
}
