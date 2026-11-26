import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs
import qs.modules.common
import qs.modules.common.widgets

ColumnLayout {
    id: root
    property var shape: MaterialShape.Shape.Clover4Leaf
    property string title
    property string icon: ""
    property var bgColor: Appearance.colors.colSecondaryContainer
    property bool collapsible: true
    property string hint: ""
    property string hintIcon: "info"
    default property alias data: sectionContent.data

    readonly property string sectionId: root.title
    readonly property bool collapsed: root.collapsible && Config.options.settings.collapsedSections.includes(root.sectionId)

    property real flashScan: 0
    property real flashPop: 0
    property real flashTint: 0

    function flashTitle() {
        titleFlash.restart()
    }

    ParallelAnimation {
        id: titleFlash

        SequentialAnimation {
            NumberAnimation { target: root; property: "flashTint"; to: 1; duration: 150 }
            PauseAnimation { duration: 1800 }
            NumberAnimation { target: root; property: "flashTint"; to: 0; duration: 500 }
        }

        SequentialAnimation {
            PropertyAction { target: root; property: "flashScan"; value: 0 }
            SequentialAnimation {
                loops: 2
                NumberAnimation { target: root; property: "flashScan"; to: 1; duration: 450; easing.type: Easing.InOutSine }
                NumberAnimation { target: root; property: "flashScan"; to: 0; duration: 450; easing.type: Easing.InOutSine }
            }
        }

        SequentialAnimation {
            loops: 3
            NumberAnimation { target: root; property: "flashPop"; to: 1; duration: 200; easing.type: Easing.OutBack }
            NumberAnimation { target: root; property: "flashPop"; to: 0; duration: 400; easing.type: Easing.OutCubic }
        }
    }

    function toggleCollapsed() {
        if (!root.collapsible) return
        let list = Config.options.settings.collapsedSections.slice()
        const idx = list.indexOf(root.sectionId)
        if (idx === -1) list.push(root.sectionId)
        else list.splice(idx, 1)
        Config.options.settings.collapsedSections = list
    }

    function collapseAllSiblings() {
        if (!root.parent) return

        let siblingIds = []
        for (let i = 0; i < root.parent.children.length; i++) {
            let sibling = root.parent.children[i]
            if (sibling.sectionId !== undefined && sibling.collapsible) {
                siblingIds.push(sibling.sectionId)
            }
        }

        let current = Config.options.settings.collapsedSections.slice()
        let preserved = current.filter(id => !siblingIds.includes(id))
        let result = preserved.concat(siblingIds)

        Config.options.settings.collapsedSections = result
    }

    Layout.fillWidth: true
    spacing: 6

    Item {
        id: header
        Layout.fillWidth: true
        implicitHeight: headerRow.implicitHeight

        RowLayout {
            id: headerRow
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: 6

            MaterialShapeWrappedMaterialSymbol {
                text: root.icon
                iconSize: Appearance.font.pixelSize.large + 1
                wrappedShape: root.shape
                color: bgColor
                scale: 1 + 0.3 * root.flashPop
            }
            StyledText {
                text: root.title
                font.pixelSize: Appearance.font.pixelSize.larger
                font.weight: Font.Medium
                color: Qt.tint(Appearance.colors.colOnSecondaryContainer, Qt.rgba(Appearance.colors.colPrimary.r, Appearance.colors.colPrimary.g, Appearance.colors.colPrimary.b, root.flashTint))

                TitleScanLine {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: -3
                    width: parent.width
                    position: root.flashScan
                    opacity: root.flashTint
                }
            }

            MaterialSymbol {
                id: hintSymbol
                visible: root.hint.length > 0
                Layout.leftMargin: 2
                text: root.hintIcon
                iconSize: Appearance.font.pixelSize.larger
                color: Appearance.colors.colSubtext
                opacity: hintArea.containsMouse ? 1 : 0.55

                Behavior on opacity {
                    NumberAnimation { duration: 150 }
                }

                MouseArea {
                    id: hintArea
                    anchors.fill: parent
                    anchors.margins: -4
                    hoverEnabled: true
                    cursorShape: Qt.WhatsThisCursor
                }

                StyledToolTip {
                    extraVisibleCondition: hintArea.containsMouse
                    text: root.hint
                }
            }

            Item { Layout.fillWidth: true }

            MaterialSymbol {
                visible: root.collapsible
                text: root.collapsed ? "expand_more" : ""
                iconSize: Appearance.font.pixelSize.larger
                color: Appearance.colors.colOnSecondaryContainer
                opacity: 0.7
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: root.collapsible
            cursorShape: root.collapsible ? Qt.PointingHandCursor : Qt.ArrowCursor
            onClicked: clickTimer.restart()
            onDoubleClicked: {
                clickTimer.stop()
                root.collapseAllSiblings()
            }

            Timer {
                id: clickTimer
                interval: 250
                onTriggered: root.toggleCollapsed()
            }
        }
    }

    Item {
        Layout.fillWidth: true
        clip: true
        implicitHeight: root.collapsed ? 0 : sectionContent.implicitHeight
        visible: implicitHeight > 0

        Behavior on implicitHeight {
            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
        }

        ColumnLayout {
            id: sectionContent
            width: parent.width
            spacing: 4
        }
    }
}