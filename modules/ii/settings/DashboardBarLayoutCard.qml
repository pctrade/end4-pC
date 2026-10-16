import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets

DashboardCard {
    id: root

    property string title: ""
    property string icon: "view_week"
    property var tileShape: MaterialShape.Shape.Gem

    readonly property var barConfig: Config.options.bar
    readonly property bool vertical: barConfig.vertical
    readonly property var leftList: Array.from(barConfig.layouts.leftLayout)
    readonly property var middleList: Array.from(barConfig.layouts.middleLayout)
    readonly property var rightList: Array.from(barConfig.layouts.rightLayout)
    readonly property var usedIds: leftList.concat(middleList, rightList)

    readonly property var lanes: [
        { id: "left", title: vertical ? Translation.tr("Top") : Translation.tr("Left"), icon: vertical ? "align_vertical_top" : "align_horizontal_left", list: leftList },
        { id: "middle", title: Translation.tr("Center"), icon: vertical ? "align_vertical_center" : "align_horizontal_center", list: middleList },
        { id: "right", title: vertical ? Translation.tr("Bottom") : Translation.tr("Right"), icon: vertical ? "align_vertical_bottom" : "align_horizontal_right", list: rightList }
    ]

    readonly property var trayIds: widgets.all.filter(w => canExist(w.id)).map(w => w.id)

    property var drag: null
    property string hoverLane: ""
    property int hoverIndex: 0
    property real dragWidth: 90
    property real pointerX: 0
    property real pointerY: 0

    tint: Appearance.colors.colLayer1

    DashboardBarWidgets {
        id: widgets
    }

    readonly property var catalog: widgets

    ListModel { id: leftModel }
    ListModel { id: middleModel }
    ListModel { id: rightModel }

    function modelFor(laneId) {
        return laneId === "left" ? leftModel : laneId === "middle" ? middleModel : rightModel;
    }

    function baseItems(laneId) {
        const list = laneId === "left" ? leftList : laneId === "middle" ? middleList : rightList;
        const seen = {};
        return list.map((wid, i) => {
            seen[wid] = (seen[wid] ?? 0) + 1;
            return { key: wid + "#" + seen[wid], wid: wid, gap: false, realIndex: i };
        });
    }

    function desiredItems(laneId) {
        const items = baseItems(laneId);
        if (drag !== null && hoverLane === laneId) {
            let insertAt = items.length;
            let count = 0;
            for (let i = 0; i < items.length; i++) {
                if (drag.from === laneId && drag.fromIndex === items[i].realIndex) continue;
                if (count === hoverIndex) {
                    insertAt = i;
                    break;
                }
                count++;
            }
            items.splice(insertAt, 0, { key: "__gap__", wid: "", gap: true, realIndex: -1 });
        }
        return items;
    }

    function syncModel(model, target) {
        const wanted = new Set(target.map(t => t.key));
        for (let i = model.count - 1; i >= 0; i--) {
            if (!wanted.has(model.get(i).key)) model.remove(i);
        }
        for (let t = 0; t < target.length; t++) {
            const item = target[t];
            if (t < model.count && model.get(t).key === item.key) {
                const current = model.get(t);
                if (current.realIndex !== item.realIndex || current.gap !== item.gap) model.set(t, item);
                continue;
            }
            let found = -1;
            for (let j = t + 1; j < model.count; j++) {
                if (model.get(j).key === item.key) {
                    found = j;
                    break;
                }
            }
            if (found >= 0) {
                model.move(found, t, 1);
                model.set(t, item);
            } else {
                model.insert(t, item);
            }
        }
    }

    property var lastSynced: ({ left: "", middle: "", right: "" })

    function refreshLanes() {
        ["left", "middle", "right"].forEach(laneId => {
            const desired = desiredItems(laneId);
            const signature = JSON.stringify(desired);
            if (lastSynced[laneId] === signature) return;
            lastSynced[laneId] = signature;
            syncModel(modelFor(laneId), desired);
        });
    }

    onLeftListChanged: refreshLanes()
    onMiddleListChanged: refreshLanes()
    onRightListChanged: refreshLanes()
    onHoverLaneChanged: refreshLanes()
    onHoverIndexChanged: refreshLanes()
    onDragChanged: refreshLanes()
    Component.onCompleted: refreshLanes()

    function canExist(id) {
        if (id === "divisor" && barConfig.borderless !== "transparent") return false;
        if (id === "dynamicIsland" && barConfig.vertical) return false;
        return !usedIds.includes(id) || widgets.multipleAllowed.includes(id);
    }

    function canPlace(id, laneId) {
        if (id === "dynamicIsland" && laneId !== "middle") return false;
        if (laneId === "middle" && middleList.includes("dynamicIsland") && id !== "dynamicIsland") return false;
        return true;
    }

    function laneItem(laneId) {
        for (let i = 0; i < laneRepeater.count; i++) {
            const lane = laneRepeater.itemAt(i);
            if (lane && lane.laneId === laneId) return lane;
        }
        return null;
    }

    function containsPoint(item, x, y) {
        if (!item) return false;
        const p = root.mapFromItem(item, 0, 0);
        return x >= p.x && x <= p.x + item.width && y >= p.y && y <= p.y + item.height;
    }

    function insertIndex(lane, x, y) {
        let before = 0;
        for (let i = 0; i < lane.chipRepeater.count; i++) {
            const chip = lane.chipRepeater.itemAt(i);
            if (!chip || chip.isGap || chip.beingDragged) continue;
            const c = root.mapFromItem(chip, chip.width / 2, chip.height / 2);
            const half = chip.height / 2;
            if (c.y < y - half || (Math.abs(c.y - y) <= half && c.x < x)) before++;
        }
        return before;
    }

    function updateHover() {
        let found = "";
        for (let i = 0; i < laneRepeater.count; i++) {
            const lane = laneRepeater.itemAt(i);
            if (containsPoint(lane, pointerX, pointerY)) {
                found = lane.laneId;
                hoverIndex = insertIndex(lane, pointerX, pointerY);
                break;
            }
        }
        if (found === "" && containsPoint(trayArea, pointerX, pointerY)) found = "tray";
        hoverLane = found;
    }

    function beginDrag(widgetId, from, fromIndex, point, width) {
        dragWidth = width;
        drag = { id: widgetId, from: from, fromIndex: fromIndex };
        pointerX = point.x;
        pointerY = point.y;
        updateHover();
    }

    function moveDrag(point) {
        pointerX = point.x;
        pointerY = point.y;
        updateHover();
    }

    function finishDrag() {
        const info = drag;
        const target = hoverLane;
        const index = hoverIndex;
        drag = null;
        hoverLane = "";
        if (!info || target === "") return;

        const lists = { left: leftList.slice(), middle: middleList.slice(), right: rightList.slice() };
        if (target !== "tray" && !canPlace(info.id, target)) return;
        if (info.from !== "tray") lists[info.from].splice(info.fromIndex, 1);
        if (target !== "tray") lists[target].splice(index, 0, info.id);

        Qt.callLater(() => {
            const layouts = Config.options.bar.layouts;
            if (JSON.stringify(lists.left) !== JSON.stringify(leftList)) layouts.leftLayout = lists.left;
            if (JSON.stringify(lists.middle) !== JSON.stringify(middleList)) layouts.middleLayout = lists.middle;
            if (JSON.stringify(lists.right) !== JSON.stringify(rightList)) layouts.rightLayout = lists.right;
        });
    }

    property bool confirmClear: false

    Timer {
        id: confirmClearTimer
        interval: 2500
        onTriggered: root.confirmClear = false
    }

    function clearAll() {
        confirmClear = false;
        Qt.callLater(() => {
            const layouts = Config.options.bar.layouts;
            layouts.leftLayout = [];
            layouts.middleLayout = [];
            layouts.rightLayout = [];
        });
    }

    function removeWidget(laneId, index) {
        const lists = { left: leftList.slice(), middle: middleList.slice(), right: rightList.slice() };
        lists[laneId].splice(index, 1);
        Qt.callLater(() => {
            const layouts = Config.options.bar.layouts;
            if (laneId === "left") layouts.leftLayout = lists.left;
            else if (laneId === "middle") layouts.middleLayout = lists.middle;
            else layouts.rightLayout = lists.right;
        });
    }

    component Chip: Rectangle {
        id: chip
        property var card: null
        property string widgetId: ""
        property string lane: ""
        property int slot: 0
        property bool isGap: false
        readonly property var info: card.catalog.byId(widgetId)
        readonly property bool beingDragged: card.drag !== null && card.drag.id === widgetId && card.drag.from === lane && card.drag.fromIndex === slot

        implicitHeight: 34
        implicitWidth: isGap ? card.dragWidth : beingDragged ? 0 : chipRow.implicitWidth + 24
        radius: height / 2
        color: isGap ? "transparent" : lane === "tray" ? Qt.rgba(1, 1, 1, 0.1) : Appearance.colors.colSecondaryContainer
        border.width: isGap ? 2 : 0
        border.color: Appearance.colors.colPrimary
        opacity: beingDragged ? 0 : isGap ? 0.7 : 1
        clip: true

        Behavior on implicitWidth {
            NumberAnimation { duration: 160; easing.type: Easing.OutCubic }
        }

        RowLayout {
            id: chipRow
            anchors.centerIn: parent
            spacing: 6
            visible: !chip.isGap

            MaterialSymbol {
                text: chip.info.icon
                iconSize: 16
                color: Appearance.colors.colOnSecondaryContainer
            }
            StyledText {
                text: chip.info.name
                font.pixelSize: Appearance.font.pixelSize.small
                color: Appearance.colors.colOnSecondaryContainer
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: !chip.isGap
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
            preventStealing: true
            onPressed: mouse => {
                if (mouse.button === Qt.RightButton) {
                    if (chip.lane !== "tray") card.removeWidget(chip.lane, chip.slot);
                    return;
                }
                card.beginDrag(chip.widgetId, chip.lane, chip.slot, chip.mapToItem(card, mouse.x, mouse.y), chip.width);
            }
            onPositionChanged: mouse => {
                if (pressed && card.drag) card.moveDrag(chip.mapToItem(card, mouse.x, mouse.y));
            }
            onReleased: card.finishDrag()
            onCanceled: card.finishDrag()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            MaterialShapeWrappedMaterialSymbol {
                shape: root.tileShape
                text: root.icon
                iconSize: 24
                fill: 1
                padding: 10
                color: Appearance.colors.colPrimary
                colSymbol: Appearance.colors.colOnPrimary
            }

            ColumnLayout {
                spacing: 0

                StyledText {
                    text: root.title
                    font.pixelSize: Appearance.font.pixelSize.larger
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer1
                }
                StyledText {
                    text: Translation.tr("Drag widgets between zones · right-click to remove · drop on the tray to hide")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }
            }

            Item { Layout.fillWidth: true }

            RippleButton {
                Layout.alignment: Qt.AlignTop
                implicitHeight: 36
                horizontalPadding: 14
                buttonRadius: 18
                enabled: root.usedIds.length > 0
                colBackground: root.confirmClear ? Appearance.colors.colPrimary : Appearance.colors.colSecondaryContainer
                colBackgroundHover: root.confirmClear ? Appearance.colors.colPrimaryHover : Appearance.colors.colSecondaryContainerHover
                colRipple: root.confirmClear ? Appearance.colors.colPrimaryActive : Appearance.colors.colSecondaryContainerActive
                downAction: () => Qt.callLater(() => {
                    if (root.confirmClear) root.clearAll();
                    else {
                        root.confirmClear = true;
                        confirmClearTimer.restart();
                    }
                })
                contentItem: RowLayout {
                    spacing: 6
                    MaterialSymbol {
                        text: root.confirmClear ? "check" : "layers_clear"
                        iconSize: 18
                        color: root.confirmClear ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSecondaryContainer
                    }
                    StyledText {
                        text: root.confirmClear ? Translation.tr("Tap again to clear") : Translation.tr("Clear all")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: root.confirmClear ? Appearance.colors.colOnPrimary : Appearance.colors.colOnSecondaryContainer
                    }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            Repeater {
                id: laneRepeater
                model: root.lanes

                delegate: Rectangle {
                    id: laneBox
                    required property var modelData

                    readonly property string laneId: modelData.id
                    property alias chipRepeater: chips
                    readonly property bool hovered: root.drag !== null && root.hoverLane === laneBox.laneId

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.preferredWidth: 1
                    radius: 20
                    color: hovered ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.06)
                    border.width: hovered ? 2 : 0
                    border.color: Appearance.colors.colPrimary

                    Behavior on color {
                        ColorAnimation { duration: 150 }
                    }

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 12
                        spacing: 8

                        RowLayout {
                            spacing: 6

                            MaterialSymbol {
                                text: laneBox.modelData.icon
                                iconSize: 16
                                color: Appearance.colors.colSubtext
                            }
                            StyledText {
                                text: laneBox.modelData.title.toUpperCase()
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                font.weight: Font.Bold
                                font.letterSpacing: 1.2
                                color: Appearance.colors.colSubtext
                            }
                        }

                        Flickable {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            clip: true
                            contentWidth: width
                            contentHeight: flow.implicitHeight
                            boundsBehavior: Flickable.StopAtBounds

                            Flow {
                                id: flow
                                width: parent.width
                                spacing: 6

                                move: Transition {
                                    NumberAnimation { properties: "x,y"; duration: 200; easing.type: Easing.OutBack; easing.overshoot: 1.2 }
                                }

                                Repeater {
                                    id: chips
                                    model: root.modelFor(laneBox.laneId)

                                    delegate: Chip {
                                        required property string wid
                                        required property bool gap
                                        required property int realIndex

                                        card: root
                                        widgetId: wid
                                        isGap: gap
                                        lane: laneBox.laneId
                                        slot: realIndex
                                    }
                                }
                            }
                        }
                    }

                    StyledText {
                        anchors.centerIn: parent
                        visible: laneBox.modelData.list.length === 0 && !(root.drag !== null && root.hoverLane === laneBox.laneId)
                        text: Translation.tr("Drop here")
                        font.pixelSize: Appearance.font.pixelSize.small
                        color: Appearance.colors.colSubtext
                        opacity: 0.6
                    }
                }
            }
        }

        Rectangle {
            id: trayArea
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(trayFlow.implicitHeight + 48, 190)
            radius: 20
            color: root.drag !== null && root.hoverLane === "tray" ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.04)
            border.width: root.drag !== null && root.hoverLane === "tray" ? 2 : 1
            border.color: root.drag !== null && root.hoverLane === "tray" ? Appearance.colors.colError : Appearance.colors.colOutlineVariant

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 12
                spacing: 8

                StyledText {
                    text: Translation.tr("AVAILABLE")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.weight: Font.Bold
                    font.letterSpacing: 1.2
                    color: Appearance.colors.colSubtext
                }

                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentWidth: width
                    contentHeight: trayFlow.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds

                    Flow {
                        id: trayFlow
                        width: parent.width
                        spacing: 6

                        Repeater {
                            model: root.trayIds

                            delegate: Chip {
                                required property string modelData
                                required property int index

                                card: root
                                widgetId: modelData
                                lane: "tray"
                                slot: index
                            }
                        }
                    }
                }
            }
        }
    }

    Chip {
        id: ghost
        card: root
        visible: root.drag !== null
        widgetId: root.drag ? root.drag.id : ""
        lane: "ghost"
        z: 100
        x: root.pointerX - width / 2
        y: root.pointerY - height / 2
        opacity: 0.95
        scale: 1.06
        enabled: false
        border.width: 2
        border.color: Appearance.colors.colPrimary
    }
}
