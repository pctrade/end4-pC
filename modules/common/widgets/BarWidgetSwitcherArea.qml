import qs.modules.common
import QtQuick
import QtQuick.Layouts

MouseArea {
    id: root
    property bool vertical: false
    property bool isMaterial: Config.options.bar.cornerStyle === 3 || Config.options.bar.cornerStyle === 4
    property real horizontalExtraPadding: 12
    property real leftExtraPadding: 0

    property Component colDefault
    property Component colMaterial
    property Component rowDefault
    property Component rowMaterial

    implicitWidth: root.vertical
        ? Appearance.sizes.verticalBarWidth
        : (rowLoader.item?.implicitWidth ?? 0) + (root.isMaterial ? 0 : root.horizontalExtraPadding) + root.leftExtraPadding
    implicitHeight: root.vertical
        ? (colLoader.item?.implicitHeight ?? 0)
        : Appearance.sizes.barHeight

    Loader {
        id: colLoader
        active: root.vertical
        visible: active
        anchors.centerIn: parent
        sourceComponent: root.isMaterial ? root.colMaterial : root.colDefault
    }

    Loader {
        id: rowLoader
        active: !root.vertical
        visible: active
        anchors.centerIn: parent
        anchors.horizontalCenterOffset: root.leftExtraPadding / 2
        sourceComponent: root.isMaterial ? root.rowMaterial : root.rowDefault
    }
}