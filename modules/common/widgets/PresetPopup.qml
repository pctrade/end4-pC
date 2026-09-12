import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

Popup {
    id: root
    property var onOverwrite: () => {}
    property var onExportZip: () => {}

    width: 190
    padding: 8
    modal: false
    closePolicy: Popup.CloseOnPressOutside | Popup.CloseOnEscape

    background: Item {
        StyledRectangularShadow { target: popupBg }
        Rectangle {
            id: popupBg
            anchors.fill: parent
            radius: Appearance.rounding.small
            color: Appearance.m3colors.m3surfaceContainerHigh
            border.width: 1
            border.color: Appearance.colors.colLayer0Border
        }
    }

    contentItem: ColumnLayout {
        spacing: 2
        RippleButton {
            Layout.fillWidth: true
            implicitHeight: 40
            buttonRadius: Appearance.rounding.small
            colBackground: "transparent"
            colBackgroundHover: Appearance.colors.colLayer2Hover
            colRipple: Appearance.colors.colLayer2Active
            horizontalPadding: 12
            onClicked: { root.close(); root.onOverwrite() }
            contentItem: RowLayout {
                spacing: 10
                MaterialSymbol { text: "save_as"; iconSize: Appearance.font.pixelSize.normal; color: Appearance.colors.colOnLayer0 }
                StyledText { text: Translation.tr("Overwrite"); color: Appearance.colors.colOnLayer0; Layout.fillWidth: true; font.pixelSize: Appearance.font.pixelSize.small }
            }
        }
        RippleButton {
            Layout.fillWidth: true
            implicitHeight: 40
            buttonRadius: Appearance.rounding.small
            colBackground: "transparent"
            colBackgroundHover: Appearance.colors.colLayer2Hover
            colRipple: Appearance.colors.colLayer2Active
            horizontalPadding: 12
            onClicked: { root.close(); root.onExportZip() }
            contentItem: RowLayout {
                spacing: 10
                MaterialSymbol { text: "folder_zip"; iconSize: Appearance.font.pixelSize.normal; color: Appearance.colors.colOnLayer0 }
                StyledText { text: Translation.tr("Export ZIP"); color: Appearance.colors.colOnLayer0; Layout.fillWidth: true; font.pixelSize: Appearance.font.pixelSize.small }
            }
        }
    }
}
