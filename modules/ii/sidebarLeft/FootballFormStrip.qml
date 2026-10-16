import QtQuick
import qs.modules.common
import qs.modules.common.widgets

Row {
    id: strip

    property var games: []
    property bool alignRight: false

    function colors(result) {
        if (result === "W") return { bg: Appearance.m3colors.m3success, fg: Appearance.m3colors.m3successContainer };
        if (result === "L") return { bg: Appearance.colors.colError, fg: Appearance.colors.colOnError };
        return { bg: "#E3C65A", fg: "#3A3000" };
    }

    layoutDirection: strip.alignRight ? Qt.RightToLeft : Qt.LeftToRight
    spacing: 3

    Repeater {
        model: strip.alignRight ? Array.from(strip.games).reverse() : strip.games

        delegate: Rectangle {
            id: pill
            required property var modelData
            implicitWidth: 24
            implicitHeight: 28
            radius: 8
            color: strip.colors(modelData.r).bg

            StyledText {
                anchors.centerIn: parent
                text: pill.modelData.r
                font.pixelSize: Appearance.font.pixelSize.smaller
                font.weight: Font.Bold
                color: strip.colors(pill.modelData.r).fg
            }

            HoverHandler {
                id: pillHover
            }
            StyledToolTip {
                extraVisibleCondition: pillHover.hovered
                text: `${pill.modelData.vs} ${pill.modelData.score}`
            }
        }
    }
}
