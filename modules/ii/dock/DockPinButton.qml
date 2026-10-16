import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts

VerticalButtonGroup {
    id: root

    property bool pinned: false
    readonly property real alongMargin: Appearance.sizes.hyprlandGapsOut + (pinned ? 4 : 0)
    signal toggled()

    visible: Config.options.dock.showPinButton
    Layout.alignment: DockStyle.vertical ? Qt.AlignHCenter : Qt.AlignVCenter
    Layout.topMargin: DockStyle.mTop(DockStyle.pinInnerMargin, 0, alongMargin)
    Layout.bottomMargin: DockStyle.mBottom(DockStyle.pinInnerMargin, 0, alongMargin)
    Layout.leftMargin: DockStyle.mLeft(DockStyle.pinInnerMargin, 0, alongMargin)
    Layout.rightMargin: DockStyle.mRight(DockStyle.pinInnerMargin, 0, alongMargin)

    GroupButton {
        baseWidth: DockStyle.pinButtonSize
        baseHeight: DockStyle.pinButtonSize
        clickedWidth: baseWidth
        clickedHeight: baseHeight + 20
        buttonRadius: Appearance.rounding.normal
        toggled: root.pinned
        onClicked: root.toggled()
        contentItem: MaterialSymbol {
            text: "keep"
            horizontalAlignment: Text.AlignHCenter
            iconSize: Appearance.font.pixelSize.larger
            color: root.pinned ? Appearance.m3colors.m3onPrimary : Appearance.colors.colOnLayer0
        }
    }
}
