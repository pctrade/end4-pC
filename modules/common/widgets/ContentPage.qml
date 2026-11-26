import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Widgets
import qs.modules.common

/** Scrollable settings page with shared input handling and search highlights. */
Item {
    id: root
    clip: true

    property real baseWidth: 600
    property bool forceWidth: false
    property real bottomContentPadding: Config.options.settings.style === "minimal" ? 40 : 90

    // Children placed in ContentPage appear inside the ColumnLayout
    default property alias data: contentColumn.data

    implicitWidth: contentColumn.implicitWidth

    // =========================================================
    // Inner Flickable
    // =========================================================
    StyledFlickable {
        id: flickable
        anchors.fill: parent
        contentHeight: contentColumn.implicitHeight + root.bottomContentPadding
        onTouchpadScrollingChanged: if (touchpadScrolling) _scrollAnim.stop()

        ColumnLayout {
            id: contentColumn
            width: root.forceWidth ? root.baseWidth : Math.max(root.baseWidth, implicitWidth)
            anchors {
                top: parent.top
                horizontalCenter: parent.horizontalCenter
                margins: 20
            }
            spacing: 30
        }

        ClippingRectangle {
            id: highlight
            z: 10
            radius: Appearance.rounding.small
            color: Qt.rgba(Appearance.colors.colPrimary.r, Appearance.colors.colPrimary.g, Appearance.colors.colPrimary.b, 0.12)
            opacity: 0
            visible: opacity > 0

            property real sweep: 0

            Rectangle {
                width: highlight.width * 0.45
                height: highlight.height
                x: highlight.sweep * (highlight.width - width)
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop { position: 0.0; color: "transparent" }
                    GradientStop { position: 0.5; color: Qt.rgba(Appearance.colors.colPrimary.r, Appearance.colors.colPrimary.g, Appearance.colors.colPrimary.b, 0.4) }
                    GradientStop { position: 1.0; color: "transparent" }
                }
            }

            ParallelAnimation {
                id: flash

                SequentialAnimation {
                    NumberAnimation { target: highlight; property: "opacity"; to: 1; duration: 150 }
                    PauseAnimation { duration: 1500 }
                    NumberAnimation { target: highlight; property: "opacity"; to: 0; duration: 500 }
                }

                SequentialAnimation {
                    PropertyAction { target: highlight; property: "sweep"; value: 0 }
                    SequentialAnimation {
                        loops: 2
                        NumberAnimation { target: highlight; property: "sweep"; to: 1; duration: 450; easing.type: Easing.InOutSine }
                        NumberAnimation { target: highlight; property: "sweep"; to: 0; duration: 450; easing.type: Easing.InOutSine }
                    }
                }
            }
        }
    }

    // Search navigation animates independently from direct touchpad movement.
    NumberAnimation {
        id: _scrollAnim
        target: flickable
        property: "contentY"
        duration: 350
        easing.type: Easing.OutCubic
    }

    function _clampY(y) {
        return Math.max(0, Math.min(y, Math.max(0, flickable.contentHeight - flickable.height)))
    }

    function _findItem(rootItem, predicate) {
        for (let i = 0; i < rootItem.children.length; i++) {
            const child = rootItem.children[i]
            if (predicate(child)) return child
        }
        for (let i = 0; i < rootItem.children.length; i++) {
            const found = _findItem(rootItem.children[i], predicate)
            if (found) return found
        }
        return null
    }

    function _ownLabel(item) {
        const value = item.title ?? item.text
        return typeof value === "string" ? value.toLowerCase().trim() : ""
    }

    function goTo(label, section, subsection) {
        const wantedLabel = (label ?? "").toLowerCase().trim()
        const wantedSection = (section ?? "").toLowerCase().trim()

        const sectionItem = wantedSection === "" ? null
            : _findItem(contentColumn, item => item.sectionId !== undefined && _ownLabel(item) === wantedSection)
        const wantedSubsection = (subsection ?? "").toLowerCase().trim()
        const subsectionItem = wantedSubsection === "" ? null
            : _findItem(sectionItem ?? contentColumn, item => item.sectionId === undefined && typeof item.title === "string" && _ownLabel(item) === wantedSubsection)
        const scope = subsectionItem ?? sectionItem ?? contentColumn

        let target = sectionItem && (wantedLabel === "" || wantedLabel === wantedSection) ? sectionItem : null
        if (!target) target = _findItem(scope, item => _ownLabel(item) === wantedLabel)
        if (!target) target = _findItem(scope, item => _ownLabel(item).includes(wantedLabel))
        if (!target) return

        let expanded = false
        for (let parent = target; parent; parent = parent.parent) {
            if (parent.collapsed === true && typeof parent.toggleCollapsed === "function") {
                parent.toggleCollapsed()
                expanded = true
            }
        }
        _pendingTarget = target
        _goToPass = 0
        _syncHighlight()
        _goToTimer.interval = expanded ? 300 : 60
        _goToTimer.restart()
    }

    property Item _pendingTarget: null
    property int _goToPass: 0

    function _syncHighlight() {
        const target = root._pendingTarget
        if (!target) return
        if (typeof target.flashTitle === "function") return
        const pos = target.mapToItem(flickable.contentItem, 0, 0)
        highlight.x = pos.x
        highlight.y = pos.y
        highlight.width = target.width
        highlight.height = target.height
    }

    function _scrollToPending() {
        const target = root._pendingTarget
        if (!target) return
        const pos = target.mapToItem(flickable.contentItem, 0, 0)
        const wanted = root._clampY(pos.y - 24)
        if (root._goToPass > 0 && Math.abs(wanted - flickable.contentY) < 4) return
        _scrollAnim.stop()
        _scrollAnim.to = wanted
        _scrollAnim.start()
    }

    Timer {
        id: _goToTimer
        onTriggered: {
            root._scrollToPending()
            if (root._goToPass === 0) {
                root._goToPass = 1
                interval = 450
                restart()
                if (typeof root._pendingTarget.flashTitle === "function") root._pendingTarget.flashTitle()
                else flash.restart()
            }
        }
    }

    Timer {
        id: _followTimer
        interval: 33
        repeat: true
        running: highlight.visible
        onTriggered: root._syncHighlight()
    }

}
