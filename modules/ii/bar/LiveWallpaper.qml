pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs
import QtQuick
import QtQuick.Layouts

/*
 * Play and pause the mpvpaper live wallpaper from the bar.
 * Hides itself when no live wallpaper is running, so it costs nothing on a
 * still wallpaper.
 */
MouseArea {
    id: root
    property color contentColor: Appearance.colors.colOnLayer1
    property bool contentColorOverridden: false
    signal styleEditorRequested()
    property bool vertical: Config.options.bar.vertical
    property bool isMaterial: Config.options.bar.cornerStyle === 3 || Config.options.bar.cornerStyle === 4

    visible: LiveWallpaper.available
    implicitWidth: !visible ? 0 : vertical ? Appearance.sizes.verticalBarWidth : (contentLoader.item?.implicitWidth ?? 0)
    implicitHeight: !visible ? 0 : vertical ? (contentLoader.item?.implicitHeight ?? 0) : Appearance.sizes.barHeight

    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton

    onClicked: (mouse) => {
        if (mouse.button === Qt.LeftButton) LiveWallpaper.toggle();
    }
    onPressAndHold: (mouse) => {
        if (mouse.button === Qt.RightButton) root.styleEditorRequested();
    }

    StyledToolTip {
        // A MouseArea has containsMouse, not hovered, and StyledToolTip reads an
        // undefined hovered as "always on". Without this the tip never goes away.
        extraVisibleCondition: root.containsMouse
        text: LiveWallpaper.paused
            ? Translation.tr("Live wallpaper paused")
            : Translation.tr("Live wallpaper playing")
    }

    component Glyph: MaterialSymbol {
        text: LiveWallpaper.paused ? "play_arrow" : "pause"
        iconSize: Appearance.font.pixelSize.normal
        fill: 1
        color: root.isMaterial ? Appearance.colors.colPrimary : root.contentColor
        // Dimmed while paused: the bar should read at a glance
        opacity: LiveWallpaper.paused ? 0.75 : 1

        Behavior on opacity {
            animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
        }
    }

    Component {
        id: rowContent
        RowLayout {
            spacing: 4
            Glyph { Layout.alignment: Qt.AlignVCenter; Layout.leftMargin: 5; Layout.rightMargin: 5 }
        }
    }

    Component {
        id: colContent
        ColumnLayout {
            spacing: 4
            Glyph { Layout.alignment: Qt.AlignHCenter; Layout.topMargin: 5; Layout.bottomMargin: 5 }
        }
    }

    Loader {
        id: contentLoader
        anchors.centerIn: parent
        sourceComponent: root.vertical ? colContent : rowContent
    }
}
