import qs.modules.common
import QtQuick
import QtQuick.Layouts

Rectangle {
    Layout.topMargin: DockStyle.mTop(DockStyle.separatorInnerMargin, DockStyle.separatorOuterMargin)
    Layout.bottomMargin: DockStyle.mBottom(DockStyle.separatorInnerMargin, DockStyle.separatorOuterMargin)
    Layout.leftMargin: DockStyle.mLeft(DockStyle.separatorInnerMargin, DockStyle.separatorOuterMargin)
    Layout.rightMargin: DockStyle.mRight(DockStyle.separatorInnerMargin, DockStyle.separatorOuterMargin)
    Layout.fillHeight: !DockStyle.vertical
    Layout.fillWidth: DockStyle.vertical
    implicitWidth: 1
    implicitHeight: 1
    color: Appearance.colors.colOutlineVariant
}
