import QtQuick
import QtQuick.Layouts
import QtQuick.Shapes
import qs.services
import qs.modules.common
import qs.modules.common.models.quickToggles
import qs.modules.common.functions
import qs.modules.common.widgets

GroupButton {
    id: root
    
    required property int buttonIndex
    required property var buttonData
    required property bool expandedSize
    required property real baseCellWidth
    required property real baseCellHeight
    required property real cellSpacing
    required property int cellSize
    property var dropIndicatorRef: null
    property bool isUnused: false 
    property var gridRef: null

    signal openMenu()

    property QuickToggleModel toggleModel
    property string name: toggleModel?.name ?? ""
    property string statusText: (toggleModel?.hasStatusText) ? (toggleModel?.statusText || (toggled ? Translation.tr("On") : Translation.tr("Off"))) : ""
    property string tooltipText: toggleModel?.tooltipText ?? ""
    property string buttonIcon: toggleModel?.icon ?? "close"
    property bool available: toggleModel?.available ?? true
    toggled: toggleModel?.toggled ?? false
    property var mainAction: toggleModel?.mainAction ?? null
    altAction: toggleModel?.hasMenu ? (() => root.openMenu()) : (toggleModel?.altAction ?? null)

    property bool editMode: false

    property real dragOffsetX: 0
    property real dragOffsetY: 0
    property bool settlePending: false
    property point settleScenePos: Qt.point(0, 0)

    transform: Translate { x: root.dragOffsetX; y: root.dragOffsetY }

    ParallelAnimation {
        id: settleAnim
        NumberAnimation { target: root; property: "dragOffsetX"; to: 0; duration: 220; easing.type: Easing.OutCubic }
        NumberAnimation { target: root; property: "dragOffsetY"; to: 0; duration: 220; easing.type: Easing.OutCubic }
        onFinished: root.setRowRaised(false)
    }

    function setRowRaised(raised) {
        const row = root.parent?.parent
        if (row) row.z = raised ? 100 : 0
    }

    function applySettle() {
        if (!root.settlePending) return
        root.settlePending = false
        const nowScene = root.mapToItem(null, 0, 0)
        const layoutX = nowScene.x - root.dragOffsetX
        const layoutY = nowScene.y - root.dragOffsetY
        root.dragOffsetX = root.settleScenePos.x - layoutX
        root.dragOffsetY = root.settleScenePos.y - layoutY
        settleAnim.restart()
    }

    onXChanged: root.applySettle()
    onYChanged: root.applySettle()

    baseWidth: root.baseCellWidth * cellSize + cellSpacing * (cellSize - 1)
    baseHeight: root.baseCellHeight
    enableImplicitWidthAnimation: !editMode && root.mouseArea.containsMouse
    enableImplicitHeightAnimation: !editMode && root.mouseArea.containsMouse
    Behavior on baseWidth {
        animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
    }
    Behavior on baseHeight {
        animation: Appearance.animation.elementMove.numberAnimation.createObject(this)
    }
    opacity: 0
    Component.onCompleted: { opacity = 1 }
    Behavior on opacity {
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }

    enabled: available || editMode
    padding: 6
    horizontalPadding: padding
    verticalPadding: padding

    colBackground: Appearance.colors.colLayer2
    colBackgroundToggled: (altAction && expandedSize) ? Appearance.colors.colLayer2 : Appearance.colors.colPrimary
    colBackgroundToggledHover: (altAction && expandedSize) ? Appearance.colors.colLayer2Hover : Appearance.colors.colPrimaryHover
    colBackgroundToggledActive: (altAction && expandedSize) ? Appearance.colors.colLayer2Active : Appearance.colors.colPrimaryActive
    buttonRadius: toggled ? Appearance.rounding.large : height / 2
    buttonRadiusPressed: Appearance.rounding.normal
    property color colText: (toggled && !(altAction && expandedSize) && enabled) ? Appearance.colors.colOnPrimary : ColorUtils.transparentize(Appearance.colors.colOnLayer2, enabled ? 0 : 0.7)
    property color colIcon: expandedSize ? ((root.toggled) ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer3) : colText

    onClicked: {
        if (root.expandedSize && root.altAction) root.altAction();
        else root.mainAction();
    }

    contentItem: RowLayout {
        spacing: 4
        anchors {
            centerIn: root.expandedSize ? undefined : parent
            fill: root.expandedSize ? parent : undefined
            leftMargin: root.horizontalPadding
            rightMargin: root.horizontalPadding
        }

        MouseArea {
            id: iconMouseArea
            hoverEnabled: true
            acceptedButtons: (root.expandedSize && root.altAction) ? Qt.LeftButton : Qt.NoButton
            Layout.alignment: Qt.AlignHCenter
            Layout.fillHeight: true
            Layout.topMargin: root.verticalPadding
            Layout.bottomMargin: root.verticalPadding
            implicitHeight: iconBackground.implicitHeight
            implicitWidth: iconBackground.implicitWidth
            cursorShape: Qt.PointingHandCursor
            onClicked: root.mainAction()

            Rectangle {
                id: iconBackground
                anchors.fill: parent
                implicitWidth: height
                radius: root.radius - root.verticalPadding
                color: {
                    const baseColor = root.toggled ? Appearance.colors.colPrimary : Appearance.colors.colLayer3
                    const transparentizeAmount = (root.altAction && root.expandedSize) ? 0 : 1
                    return ColorUtils.transparentize(baseColor, transparentizeAmount)
                }
                Behavior on radius { animation: Appearance.animation.elementMove.numberAnimation.createObject(this) }
                Behavior on color { animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }

                MaterialSymbol {
                    anchors.centerIn: parent
                    fill: root.toggled ? 1 : 0
                    iconSize: root.expandedSize ? 22 : 24
                    color: root.colIcon
                    text: root.buttonIcon
                }

                Loader {
                    anchors.fill: parent
                    active: (root.expandedSize && root.altAction)
                    sourceComponent: Rectangle {
                        radius: iconBackground.radius
                        color: ColorUtils.transparentize(root.colIcon, iconMouseArea.containsPress ? 0.88 : iconMouseArea.containsMouse ? 0.95 : 1)
                        Behavior on color { animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this) }
                    }
                }
            }
        }

        Loader {
            Layout.alignment: Qt.AlignVCenter
            Layout.fillWidth: true
            visible: root.expandedSize
            active: visible
            sourceComponent: Column {
                spacing: -2
                StyledText {
                    anchors { left: parent.left; right: parent.right }
                    font.pixelSize: Appearance.font.pixelSize.smallie
                    font.weight: 600
                    color: root.colText
                    elide: Text.ElideRight
                    text: root.name
                }
                StyledText {
                    visible: root.statusText
                    anchors { left: parent.left; right: parent.right }
                    font { pixelSize: Appearance.font.pixelSize.smaller; weight: 100 }
                    color: root.colText
                    elide: Text.ElideRight
                    text: root.statusText
                }
            }
        }
    }

    // Edit mode
    Item {
        id: editModeInteraction
        visible: root.editMode && !root.isUnused
        anchors.fill: parent

        property bool isDragging: false

        DragHandler {
            id: dragHandler
            target: null

            function getAllSiblings() {
                const siblings = [];
                if (!root.gridRef) return siblings;
                for (let r = 0; r < root.gridRef.children.length; r++) {
                    const row = root.gridRef.children[r];
                    if (!row || !row.visible) continue;
                    const rowLayout = row.children[0];
                    if (!rowLayout) continue;
                    for (let c = 0; c < rowLayout.children.length; c++) {
                        const sib = rowLayout.children[c];
                        if (!sib || !sib.visible || !sib.buttonData) continue;
                        siblings.push(sib);
                    }
                }
                return siblings;
            }

            function findNearest(sceneX, sceneY) {
                const siblings = getAllSiblings();
                let nearest = null;
                let minDist = Infinity;
                for (let i = 0; i < siblings.length; i++) {
                    const sib = siblings[i];
                    if (sib.buttonData.type === root.buttonData.type) continue;
                    const sibScene = sib.mapToItem(null, sib.width / 2, sib.height / 2);
                    const dx = sceneX - sibScene.x;
                    const dy = sceneY - sibScene.y;
                    const dist = Math.sqrt(dx * dx + dy * dy);
                    if (dist < minDist) {
                        minDist = dist;
                        nearest = sib;
                    }
                }
                return nearest;
            }

            onActiveChanged: {
                editModeInteraction.isDragging = active;

                if (active) {
                    settleAnim.stop();
                    root.settlePending = false;
                    root.setRowRaised(true);
                    return;
                }

                if (root.dropIndicatorRef) root.dropIndicatorRef.visible = false;
                const sceneX = centroid.scenePosition.x;
                const sceneY = centroid.scenePosition.y;
                const nearest = findNearest(sceneX, sceneY);
                root.settleScenePos = root.mapToItem(null, 0, 0);
                root.settlePending = true;
                if (nearest) {
                    const toggleList = Config.options.sidebar.quickToggles.android.toggles;
                    const myType = root.buttonData.type;
                    const sibType = nearest.buttonData.type;
                    const myIdx = toggleList.findIndex(t => t.type === myType);
                    const sibIdx = toggleList.findIndex(t => t.type === sibType);
                    if (myIdx !== -1 && sibIdx !== -1 && myIdx !== sibIdx) {
                        const temp = toggleList[myIdx];
                        toggleList[myIdx] = toggleList[sibIdx];
                        toggleList[sibIdx] = temp;
                    }
                }
                settleSettleTimer.restart();
            }

            onCentroidChanged: {
                if (!active) return;
                root.dragOffsetX = centroid.scenePosition.x - centroid.scenePressPosition.x;
                root.dragOffsetY = centroid.scenePosition.y - centroid.scenePressPosition.y;
                if (!root.dropIndicatorRef) return;
                const nearest = findNearest(centroid.scenePosition.x, centroid.scenePosition.y);
                if (nearest) {
                    const pos = nearest.mapToItem(root.dropIndicatorRef.parent, 0, 0);
                    root.dropIndicatorRef.x = pos.x;
                    root.dropIndicatorRef.y = pos.y;
                    root.dropIndicatorRef.width = nearest.width;
                    root.dropIndicatorRef.height = nearest.height;
                    root.dropIndicatorRef.radius = nearest.buttonRadius;
                    root.dropIndicatorRef.visible = true;
                } else {
                    root.dropIndicatorRef.visible = false;
                }
            }
        }

        Timer {
            id: settleSettleTimer
            interval: 60
            onTriggered: {
                if (root.settlePending) {
                    root.settlePending = false;
                    settleAnim.restart();
                }
            }
        }

        HoverHandler {
            cursorShape: editModeInteraction.isDragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        }
    }

    MouseArea {
        visible: root.editMode && root.isUnused
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            const toggleList = Config.options.sidebar.quickToggles.android.toggles;
            const buttonType = root.buttonData.type;
            if (!toggleList.find(t => t.type === buttonType))
                toggleList.push({ type: buttonType, size: 1 });
        }
    }

    Rectangle {
        visible: editModeInteraction.isDragging
        anchors.fill: parent
        anchors.margins: -3
        z: 5
        radius: root.buttonRadius + 3
        color: "transparent"
        border.width: 2
        border.color: Appearance.colors.colPrimary
    }

    // del
    Rectangle {
        id: deleteBtn
        visible: root.editMode && !root.isUnused
        z: 10
        width: 20
        height: 20
        radius: 10
        color: deleteHover.containsMouse ? Appearance.colors.colError : ColorUtils.transparentize(Appearance.colors.colError, 0.15)
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.topMargin: -6
        anchors.leftMargin: -6

        Behavior on color {
            animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
        }

        MaterialSymbol {
            anchors.centerIn: parent
            text: "close"
            iconSize: 13
            color: Appearance.colors.colOnError 
            Behavior on color {
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }
        }

        MouseArea {
            id: deleteHover
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                const toggleList = Config.options.sidebar.quickToggles.android.toggles;
                const buttonType = root.buttonData.type;
                const idx = toggleList.findIndex(t => t.type === buttonType);
                if (idx !== -1) toggleList.splice(idx, 1);
            }
        }
    }

    // resize
    Item {
        id: resizeBtn
        visible: root.editMode && !root.isUnused
        z: 10
        width: 32
        height: 32

        readonly property real cornerR: Math.max(8, Math.min(root.buttonRadius, root.height / 2, root.width / 2))
        readonly property real arcR: cornerR + 4
        x: root.width - cornerR + arcR * 0.7071 - width / 2
        y: root.height - cornerR + arcR * 0.7071 - height / 2

        Shape {
            anchors.fill: parent
            layer.enabled: true
            layer.samples: 4

            ShapePath {
                strokeWidth: 4
                strokeColor: resizeHover.pressed || resizeHover.containsMouse
                    ? Appearance.colors.colPrimary
                    : ColorUtils.transparentize(Appearance.colors.colOnLayer2, 0.2)
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap

                Behavior on strokeColor {
                    animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
                }

                PathAngleArc {
                    centerX: resizeBtn.width / 2 - resizeBtn.arcR * 0.7071
                    centerY: resizeBtn.height / 2 - resizeBtn.arcR * 0.7071
                    radiusX: resizeBtn.arcR
                    radiusY: resizeBtn.arcR
                    startAngle: 20
                    sweepAngle: 50
                }
            }
        }

        MouseArea {
            id: resizeHover
            anchors.fill: parent
            anchors.margins: -4
            hoverEnabled: true
            cursorShape: Qt.SizeFDiagCursor
            preventStealing: true

            property real pressSceneX: 0
            property real pressSize: 1

            onPressed: event => {
                const scene = resizeBtn.mapToItem(null, event.x, event.y);
                pressSceneX = scene.x;
                pressSize = root.cellSize;
            }
            onPositionChanged: event => {
                if (!pressed) return;
                const scene = resizeBtn.mapToItem(null, event.x, event.y);
                const dx = scene.x - pressSceneX;
                const steps = Math.round(dx / root.baseCellWidth);
                const newSize = Math.max(1, Math.min(3, pressSize + steps));
                if (newSize !== root.cellSize) {
                    const toggleList = Config.options.sidebar.quickToggles.android.toggles;
                    const buttonType = root.buttonData.type;
                    const idx = toggleList.findIndex(t => t.type === buttonType);
                    if (idx !== -1) toggleList[idx].size = newSize;
                }
            }
        }
    }

    StyledToolTip {
        extraVisibleCondition: root.tooltipText !== ""
        text: root.tooltipText
    }
}