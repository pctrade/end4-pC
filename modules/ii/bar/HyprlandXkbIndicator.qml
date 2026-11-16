import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

/*
 * Active keyboard layout. A click goes to the next layout and the wheel
 * cycles through them; hovering lists every layout.
 */
MouseArea {
    id: root
    property color contentColor: Appearance.colors.colOnLayer0
    property bool contentColorOverridden: false
    signal styleEditorRequested()
    property bool vertical: false
    property color color: Appearance.colors.colOnSurfaceVariant
    // Inside the system icons: no bar-sized box and no popup of its own
    property bool compact: false

    readonly property bool isNiri: WM.compositor === "niri"
    readonly property string layoutCode: isNiri ? NiriXkb.currentLayoutCode : HyprlandXkb.currentLayoutCode
    readonly property int layoutCount: isNiri ? NiriXkb.layoutNames.length : HyprlandXkb.layoutCodes.length
    // [{ code, name, active }] for the popup
    readonly property var layouts: {
        if (isNiri) {
            return NiriXkb.layoutNames.map((name, i) => ({
                code: i === NiriXkb.currentIdx ? NiriXkb.currentLayoutCode : "",
                name: name,
                active: i === NiriXkb.currentIdx
            }));
        }
        return HyprlandXkb.layoutCodes.map((code, i) => ({
            code: code,
            name: HyprlandXkb.layoutDescriptions[code] ?? code,
            active: i === HyprlandXkb.currentLayoutIndex
        }));
    }

    function switchLayout(direction) {
        if (root.isNiri) NiriXkb.switchLayout(direction);
        else HyprlandXkb.switchLayout(direction);
    }

    hoverEnabled: !compact && !Config.options.bar.tooltips.clickToShow
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: layoutCount > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
    implicitWidth: vertical
        ? (compact ? codeText.implicitWidth : Appearance.sizes.verticalBarWidth)
        : codeText.implicitWidth + 8
    implicitHeight: vertical || compact
        ? codeText.implicitHeight + 6
        : Appearance.sizes.barHeight

    onClicked: mouse => {
        if (mouse.button === Qt.LeftButton) root.switchLayout("next");
    }
    onPressAndHold: mouse => {
        if (mouse.button === Qt.RightButton) root.styleEditorRequested();
    }
    onWheel: wheel => root.switchLayout(wheel.angleDelta.y > 0 ? "prev" : "next")

    StyledText {
        id: codeText
        anchors.centerIn: parent
        horizontalAlignment: Text.AlignHCenter
        text: root.layoutCode
        font.pixelSize: Appearance.font.pixelSize.small
        color: root.contentColor
        animateChange: true
    }

    KeyboardLayoutPopup {
        hoverTarget: root.compact ? null : root
        layouts: root.layouts
    }
}
