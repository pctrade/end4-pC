import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.services
import qs.modules.ii.sidebarLeft.pinboard
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root

    Component.onCompleted: {
        Pinboard.refresh();
    }

    // Pending draft properties
    property string pendingImagePath: ""
    property bool isPasting: false

    // Helpers to determine item-by-item navigation states
    property int totalPins: Pinboard.list.length
    property int currentVisibleIndex: {
        if (pinListView.count === 0) return 0;
        const idx = pinListView.indexAt(10, pinListView.contentY + pinListView.spacing + 4);
        return idx >= 0 ? idx : 0;
    }
    readonly property bool canScrollUp: pinListView.contentY > 4
    readonly property bool canScrollDown: pinListView.contentY < Math.max(0, pinListView.contentHeight - pinListView.height - 4)

    function addCurrentPin() {
        const text = noteInputArea.text.trim();
        const image = root.pendingImagePath.trim();
        if (text.length === 0 && image.length === 0) return;

        const _newId = Pinboard.addPin(text, image);
        noteInputArea.text = "";
        root.pendingImagePath = "";
        scrollToItem(0);
    }

    function scrollToItem(index: int) {
        if (index < 0 || index >= pinListView.count) return;
        pinListView.currentIndex = index;
        const item = pinListView.itemAtIndex(index);
        const maxY = Math.max(0, pinListView.contentHeight - pinListView.height);
        if (item) {
            const targetY = Math.max(0, Math.min(item.y, maxY));
            scrollAnimation.stop();
            scrollAnimation.to = targetY;
            scrollAnimation.restart();
        } else {
            pinListView.positionViewAtIndex(index, ListView.Beginning);
        }
    }

    function scrollNextItem() {
        if (pinListView.count === 0) return;
        const cur = root.currentVisibleIndex;
        const next = Math.min(pinListView.count - 1, cur + 1);
        scrollToItem(next);
    }

    function scrollPrevItem() {
        if (pinListView.count === 0) return;
        const cur = root.currentVisibleIndex;
        const curItem = pinListView.itemAtIndex(cur);
        let prev = cur - 1;
        if (curItem && pinListView.contentY > curItem.y + 4) {
            prev = cur;
        }
        prev = Math.max(0, prev);
        scrollToItem(prev);
    }

    // Keyboard navigation
    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Down || event.key === Qt.Key_PageDown) {
            scrollNextItem();
            event.accepted = true;
        } else if (event.key === Qt.Key_Up || event.key === Qt.Key_PageUp) {
            scrollPrevItem();
            event.accepted = true;
        }
    }

    // Smooth scroll animation
    NumberAnimation {
        id: scrollAnimation
        target: pinListView
        property: "contentY"
        duration: Appearance.animation.elementMove.duration
        easing.type: Appearance.animation.elementMove.type
        easing.bezierCurve: Appearance.animation.elementMove.bezierCurve
    }

    // File picker process for images
    Process {
        id: pickImageProc
        command: ["bash", "-c", `
            if command -v zenity > /dev/null 2>&1; then
                zenity --file-selection --title="Select Image to Pin" --file-filter="Images | *.png *.jpg *.jpeg *.webp *.gif *.bmp *.svg *.avif" 2>/dev/null
            elif command -v kdialog > /dev/null 2>&1; then
                kdialog --getopenfilename "$HOME" "Images (*.png *.jpg *.jpeg *.webp *.gif *.bmp *.svg *.avif)" 2>/dev/null
            fi
        `]
        property string buffer: ""
        stdout: SplitParser {
            onRead: (data) => {
                pickImageProc.buffer += data;
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                const chosenPath = pickImageProc.buffer.trim();
                if (chosenPath.length > 0) {
                    root.pendingImagePath = chosenPath;
                }
            }
            pickImageProc.buffer = "";
        }
    }

    // Clipboard paste process
    Process {
        id: pasteProc
        property string buffer: ""
        command: ["bash", "-c", `
            PIN_DIR="${Directories.pinboardImages}"
            mkdir -p "$PIN_DIR"
            if wl-paste --list-types 2>/dev/null | grep -qE '^image/'; then
                TARGET="$PIN_DIR/pin_clip_$(date +%s%N).png"
                if wl-paste -t image/png > "$TARGET" 2>/dev/null; then
                    echo "IMAGE:$TARGET"
                    exit 0
                fi
            fi
            TEXT="$(wl-paste --no-newline 2>/dev/null)"
            if [ -n "$TEXT" ]; then
                CLEAN="\${TEXT#file://}"
                if [ -f "$CLEAN" ]; then
                    EXT="\${CLEAN##*.}"
                    case "\${EXT,,}" in
                        png|jpg|jpeg|webp|gif|bmp|svg|avif)
                            echo "IMAGE:$CLEAN"
                            exit 0
                            ;;
                    esac
                fi
                echo "TEXT:$TEXT"
                exit 0
            fi
            exit 1
        `]
        stdout: SplitParser {
            onRead: (data) => {
                pasteProc.buffer += data;
            }
        }
        onExited: (exitCode, exitStatus) => {
            root.isPasting = false;
            if (exitCode === 0) {
                const res = pasteProc.buffer.trim();
                if (res.startsWith("IMAGE:")) {
                    const img = res.slice(6).trim();
                    root.pendingImagePath = img;
                } else if (res.startsWith("TEXT:")) {
                    const txt = res.slice(5);
                    if (noteInputArea.text.length > 0) {
                        noteInputArea.text += "\n" + txt;
                    } else {
                        noteInputArea.text = txt;
                    }
                }
            }
            pasteProc.buffer = "";
        }
    }

    function triggerPaste() {
        if (pasteProc.running) return;
        root.isPasting = true;
        pasteProc.buffer = "";
        pasteProc.running = true;
    }

    // Main layout
    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        // Top: Navigation header for item-by-item browsing (when items exist)
        RowLayout {
            Layout.fillWidth: true
            visible: Pinboard.list.length > 0
            spacing: 6

            MaterialSymbol {
                text: "view_agenda"
                iconSize: 15
                color: Appearance.colors.colSubtext
            }

            StyledText {
                text: Translation.tr("Pin %1 of %2").arg(root.currentVisibleIndex + 1).arg(Pinboard.list.length)
                font.pixelSize: Appearance.font.pixelSize.smaller
                color: Appearance.colors.colSubtext
            }

            Item { Layout.fillWidth: true }

            // Scroll Up / Previous Item
            RippleButton {
                id: prevItemBtn
                implicitWidth: 28
                implicitHeight: 28
                buttonRadius: Appearance.rounding.full
                enabled: root.canScrollUp
                opacity: enabled ? 1 : 0.3
                colBackground: Appearance.colors.colLayer2
                colBackgroundHover: Appearance.colors.colLayer2Hover

                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "keyboard_arrow_up"
                    iconSize: 18
                    color: Appearance.colors.colOnLayer2
                    horizontalAlignment: Text.AlignHCenter
                }

                StyledToolTip {
                    extraVisibleCondition: prevItemBtn.hovered
                    text: Translation.tr("Previous item (Wheel Up)")
                }

                onClicked: root.scrollPrevItem()
            }

            // Scroll Down / Next Item
            RippleButton {
                id: nextItemBtn
                implicitWidth: 28
                implicitHeight: 28
                buttonRadius: Appearance.rounding.full
                enabled: root.canScrollDown
                opacity: enabled ? 1 : 0.3
                colBackground: Appearance.colors.colLayer2
                colBackgroundHover: Appearance.colors.colLayer2Hover

                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    text: "keyboard_arrow_down"
                    iconSize: 18
                    color: Appearance.colors.colOnLayer2
                    horizontalAlignment: Text.AlignHCenter
                }

                StyledToolTip {
                    extraVisibleCondition: nextItemBtn.hovered
                    text: Translation.tr("Next item (Wheel Down)")
                }

                onClicked: root.scrollNextItem()
            }
        }

        // Scrollable Pins View (fills remaining space)
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            // Empty state placeholder
            PagePlaceholder {
                shown: Pinboard.list.length === 0
                icon: "push_pin"
                title: Translation.tr("No pins yet")
                description: Translation.tr("Add notes, attach images, paste from clipboard, or drop files here.")
                shape: MaterialShape.Shape.Ghostish
            }

            // Item-by-item scrollable list view
            ListView {
                id: pinListView
                anchors.fill: parent
                visible: Pinboard.list.length > 0
                spacing: 10
                clip: true
                cacheBuffer: 1500

                property int draggingIndex: -1
                property int targetIndex: -1
                property real dragYOffset: 0
                property real dragItemHeight: 0
                property real dragStartContentMouseY: 0
                property real dragCurrentViewportY: -1
                readonly property bool isDragging: draggingIndex !== -1

                // Snapping disabled during drag to prevent snap fighting
                snapMode: isDragging ? ListView.NoSnap : ListView.SnapToItem
                boundsBehavior: Flickable.StopAtBounds
                interactive: !isDragging

                ScrollBar.vertical: StyledScrollBar {}

                model: ScriptModel {
                    values: Pinboard.list
                }

                function updateDragPosition(currentViewportY: real) {
                    if (!isDragging) return;
                    dragCurrentViewportY = currentViewportY;

                    const currentContentMouseY = contentY + currentViewportY;
                    const delta = currentContentMouseY - dragStartContentMouseY;
                    dragYOffset = delta;

                    // Determine target index based on center of dragged item in content coordinates
                    const curItem = itemAtIndex(draggingIndex);
                    const baseItemY = curItem ? curItem.y : 0;
                    const draggedCenterY = baseItemY + dragYOffset + (dragItemHeight / 2);
                    const clampedY = Math.max(5, Math.min(contentHeight - 5, draggedCenterY));

                    let hitIndex = indexAt(width / 2, clampedY);
                    if (hitIndex === -1) {
                        if (draggedCenterY <= 10) hitIndex = 0;
                        else if (draggedCenterY >= contentHeight - 10) hitIndex = count - 1;
                    }
                    if (hitIndex !== -1 && hitIndex >= 0 && hitIndex < count) {
                        targetIndex = hitIndex;
                    }
                }

                Timer {
                    id: autoScrollTimer
                    interval: 16
                    repeat: true
                    running: pinListView.isDragging
                    onTriggered: {
                        if (!pinListView.isDragging || pinListView.dragCurrentViewportY < -100) return;

                        const topEdge = 45;
                        const bottomEdge = pinListView.height - 45;
                        const vy = pinListView.dragCurrentViewportY;
                        const maxScroll = Math.max(0, pinListView.contentHeight - pinListView.height);

                        if (vy < topEdge && pinListView.contentY > 0) {
                            const speed = Math.max(3, Math.min(16, (topEdge - vy) * 0.4));
                            pinListView.contentY = Math.max(0, pinListView.contentY - speed);
                            pinListView.updateDragPosition(pinListView.dragCurrentViewportY);
                        } else if (vy > bottomEdge && pinListView.contentY < maxScroll) {
                            const speed = Math.max(3, Math.min(16, (vy - bottomEdge) * 0.4));
                            pinListView.contentY = Math.min(maxScroll, pinListView.contentY + speed);
                            pinListView.updateDragPosition(pinListView.dragCurrentViewportY);
                        }
                    }
                }

                delegate: Item {
                    id: dragDelegate
                    required property var modelData
                    required property int index

                    width: pinListView.width
                    height: pinItem.implicitHeight

                    readonly property bool isThisItemDragging: pinListView.draggingIndex === dragDelegate.index

                    // Calculate shift for items when another item is being dragged
                    readonly property real shiftY: {
                        if (pinListView.draggingIndex === -1 || isThisItemDragging) return 0;
                        const from = pinListView.draggingIndex;
                        const to = pinListView.targetIndex;
                        if (from < to) {
                            // Dragging downwards: items between from+1 and to shift UP
                            if (dragDelegate.index > from && dragDelegate.index <= to) {
                                return -pinListView.dragItemHeight - pinListView.spacing;
                            }
                        } else if (from > to) {
                            // Dragging upwards: items between to and from-1 shift DOWN
                            if (dragDelegate.index >= to && dragDelegate.index < from) {
                                return pinListView.dragItemHeight + pinListView.spacing;
                            }
                        }
                        return 0;
                    }

                    // Lift dragged card above others
                    z: isThisItemDragging ? 100 : 1

                    // The visual card
                    PinboardItem {
                        id: pinItem
                        width: dragDelegate.width
                        pinData: dragDelegate.modelData
                        pinIndex: dragDelegate.index
                        isDragging: dragDelegate.isThisItemDragging

                        // When dragging, follow mouse offset directly
                        y: dragDelegate.isThisItemDragging ? pinListView.dragYOffset : 0

                        // Apply shift when other items are being dragged
                        transform: Translate {
                            y: dragDelegate.shiftY
                            Behavior on y {
                                NumberAnimation {
                                    duration: Appearance.animation.elementMoveFast.duration
                                    easing.type: Easing.OutCubic
                                }
                            }
                        }
                    }

                    // Drag handle MouseArea covering the full height of the dedicated left strip
                    MouseArea {
                        id: dragHandleArea
                        anchors {
                            top: parent.top
                            bottom: parent.bottom
                            left: parent.left
                        }
                        width: 36
                        preventStealing: true
                        hoverEnabled: true
                        cursorShape: (pinListView.draggingIndex === dragDelegate.index) ? Qt.ClosedHandCursor : Qt.OpenHandCursor

                        onEntered: pinItem.isHandleHovered = true
                        onExited: {
                            if (pinListView.draggingIndex !== dragDelegate.index) {
                                pinItem.isHandleHovered = false;
                            }
                        }

                        onPressed: (mouse) => {
                            pinItem.isHandleHovered = true;
                            const viewPoint = dragHandleArea.mapToItem(pinListView, mouse.x, mouse.y);
                            pinListView.dragCurrentViewportY = viewPoint.y;
                            pinListView.dragStartContentMouseY = pinListView.contentY + viewPoint.y;
                            pinListView.dragItemHeight = dragDelegate.height;
                            pinListView.draggingIndex = dragDelegate.index;
                            pinListView.targetIndex = dragDelegate.index;
                            pinListView.dragYOffset = 0;
                        }

                        onPositionChanged: (mouse) => {
                            if (pinListView.draggingIndex !== dragDelegate.index) return;
                            const viewPoint = dragHandleArea.mapToItem(pinListView, mouse.x, mouse.y);
                            pinListView.updateDragPosition(viewPoint.y);
                        }

                        onReleased: {
                            pinItem.isHandleHovered = false;
                            pinListView.dragCurrentViewportY = -1;
                            if (pinListView.draggingIndex === dragDelegate.index) {
                                const from = pinListView.draggingIndex;
                                const to = pinListView.targetIndex;
                                pinListView.draggingIndex = -1;
                                pinListView.targetIndex = -1;
                                pinListView.dragYOffset = 0;
                                if (from !== -1 && to !== -1 && from !== to) {
                                    Pinboard.movePin(from, to);
                                }
                            }
                        }

                        onCanceled: {
                            pinItem.isHandleHovered = false;
                            pinListView.dragCurrentViewportY = -1;
                            pinListView.draggingIndex = -1;
                            pinListView.targetIndex = -1;
                            pinListView.dragYOffset = 0;
                        }

                        StyledToolTip {
                            extraVisibleCondition: dragHandleArea.containsMouse && !pinListView.isDragging
                            text: Translation.tr("Drag to rearrange")
                        }
                    }
                }

                // Wheel handler — disabled while dragging
                WheelHandler {
                    id: pinWheelHandler
                    target: pinListView
                    enabled: !pinListView.isDragging
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: (event) => {
                        if (event.angleDelta.y < 0) {
                            root.scrollNextItem();
                        } else if (event.angleDelta.y > 0) {
                            root.scrollPrevItem();
                        }
                        event.accepted = true;
                    }
                }
            }
        }

        // Middle bar: item count + Clear All
        Rectangle {
            id: bottomBar
            Layout.fillWidth: true
            implicitHeight: 44
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer2
            border.width: 1
            border.color: ColorUtils.transparentize(Appearance.colors.colOutlineVariant, 0.7)

            RowLayout {
                anchors { fill: parent; leftMargin: 12; rightMargin: 8 }
                spacing: 8

                MaterialSymbol {
                    text: "push_pin"
                    iconSize: 16
                    color: Appearance.colors.colSubtext
                }

                StyledText {
                    Layout.fillWidth: true
                    text: Pinboard.list.length === 1
                        ? Translation.tr("1 item pinned")
                        : Translation.tr("%1 items pinned").arg(Pinboard.list.length)
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colSubtext
                }

                RippleButton {
                    id: clearAllButton
                    enabled: Pinboard.list.length > 0
                    opacity: enabled ? 1 : 0.4
                    implicitHeight: 32
                    horizontalPadding: 12
                    buttonRadius: Appearance.rounding.full
                    colBackground: ColorUtils.transparentize(Appearance.colors.colErrorContainer, 0.4)
                    colBackgroundHover: Appearance.colors.colErrorContainer
                    colRipple: Appearance.colors.colError

                    contentItem: RowLayout {
                        spacing: 6
                        MaterialSymbol {
                            text: "delete_sweep"
                            iconSize: 16
                            color: clearAllButton.enabled ? Appearance.colors.colOnErrorContainer : Appearance.colors.colSubtext
                        }
                        StyledText {
                            text: Translation.tr("Clear all")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            font.weight: Font.Medium
                            color: clearAllButton.enabled ? Appearance.colors.colOnErrorContainer : Appearance.colors.colSubtext
                        }
                    }

                    StyledToolTip {
                        extraVisibleCondition: clearAllButton.hovered
                        text: Translation.tr("Clear all pinned items")
                    }

                    onClicked: Pinboard.clearAll()
                }
            }
        }

        // Very Bottom: Input & Compose Card
        Rectangle {
            id: composeCard
            Layout.fillWidth: true
            implicitHeight: composeLayout.implicitHeight + 16
            radius: Appearance.rounding.normal
            color: Appearance.colors.colLayer2
            border.width: 1
            border.color: ColorUtils.transparentize(Appearance.colors.colOutlineVariant, 0.7)

            ColumnLayout {
                id: composeLayout
                anchors { top: parent.top; left: parent.left; right: parent.right; margins: 8 }
                spacing: 8

                // Text Input Area
                ScrollView {
                    Layout.fillWidth: true
                    implicitHeight: Math.min(90, Math.max(45, noteInputArea.contentHeight + 16))
                    clip: true
                    ScrollBar.vertical.policy: ScrollBar.AsNeeded

                    StyledTextArea {
                        id: noteInputArea
                        anchors.fill: parent
                        wrapMode: TextArea.Wrap
                        placeholderText: Translation.tr("Write a note or paste image/text...")
                        color: activeFocus ? Appearance.m3colors.m3onSurface : Appearance.m3colors.m3onSurfaceVariant
                        background: null

                        Keys.onReturnPressed: (event) => {
                            if (event.modifiers === Qt.ControlModifier) {
                                root.addCurrentPin();
                                event.accepted = true;
                            } else {
                                event.accepted = false;
                            }
                        }

                        Keys.onPressed: (event) => {
                            if (event.modifiers === Qt.ControlModifier && event.key === Qt.Key_V) {
                                root.triggerPaste();
                                event.accepted = true;
                            }
                        }
                    }
                }

                // Attached image chip preview
                Rectangle {
                    id: attachedImageChip
                    visible: root.pendingImagePath.length > 0
                    Layout.fillWidth: true
                    implicitHeight: 44
                    radius: Appearance.rounding.small
                    color: Appearance.colors.colLayer1
                    border.width: 1
                    border.color: ColorUtils.transparentize(Appearance.colors.colOutlineVariant, 0.6)

                    RowLayout {
                        anchors { fill: parent; margins: 4 }
                        spacing: 8

                        Rectangle {
                            implicitWidth: 36
                            implicitHeight: 36
                            radius: Appearance.rounding.verysmall
                            color: "transparent"
                            clip: true

                            StyledImage {
                                anchors.fill: parent
                                source: root.pendingImagePath ? ("file://" + FileUtils.trimFileProtocol(root.pendingImagePath)) : ""
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                            }
                        }

                        StyledText {
                            Layout.fillWidth: true
                            text: FileUtils.fileNameForPath(root.pendingImagePath)
                            elide: Text.ElideMiddle
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnLayer1
                        }

                        RippleButton {
                            implicitWidth: 28
                            implicitHeight: 28
                            buttonRadius: Appearance.rounding.full
                            colBackground: "transparent"
                            colBackgroundHover: Appearance.colors.colErrorContainer

                            contentItem: MaterialSymbol {
                                anchors.centerIn: parent
                                text: "close"
                                iconSize: 14
                                color: Appearance.colors.colSubtext
                                horizontalAlignment: Text.AlignHCenter
                            }

                            StyledToolTip { text: Translation.tr("Remove attachment") }
                            onClicked: root.pendingImagePath = ""
                        }
                    }
                }

                // Action buttons toolbar
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    RippleButton {
                        id: attachImageBtn
                        implicitHeight: 34
                        horizontalPadding: 10
                        buttonRadius: Appearance.rounding.small
                        colBackground: Appearance.colors.colLayer1
                        colBackgroundHover: Appearance.colors.colLayer1Hover

                        contentItem: RowLayout {
                            spacing: 6
                            MaterialSymbol { text: "add_photo_alternate"; iconSize: 16; color: Appearance.colors.colOnLayer1 }
                            StyledText { text: Translation.tr("Image"); font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colOnLayer1 }
                        }

                        StyledToolTip {
                            extraVisibleCondition: attachImageBtn.hovered
                            text: Translation.tr("Attach an image file")
                        }

                        onClicked: {
                            pickImageProc.running = false;
                            pickImageProc.buffer = "";
                            pickImageProc.running = true;
                        }
                    }

                    RippleButton {
                        id: pasteBtn
                        implicitHeight: 34
                        horizontalPadding: 10
                        buttonRadius: Appearance.rounding.small
                        colBackground: Appearance.colors.colLayer1
                        colBackgroundHover: Appearance.colors.colLayer1Hover

                        contentItem: RowLayout {
                            spacing: 6
                            MaterialSymbol { text: root.isPasting ? "hourglass_empty" : "content_paste"; iconSize: 16; color: Appearance.colors.colOnLayer1 }
                            StyledText { text: Translation.tr("Paste"); font.pixelSize: Appearance.font.pixelSize.smaller; color: Appearance.colors.colOnLayer1 }
                        }

                        StyledToolTip {
                            extraVisibleCondition: pasteBtn.hovered
                            text: Translation.tr("Paste image or text from clipboard")
                        }

                        onClicked: root.triggerPaste()
                    }

                    Item { Layout.fillWidth: true }

                    RippleButton {
                        id: pinSubmitBtn
                        implicitHeight: 34
                        horizontalPadding: 14
                        buttonRadius: Appearance.rounding.small
                        enabled: noteInputArea.text.trim().length > 0 || root.pendingImagePath.length > 0
                        opacity: enabled ? 1 : 0.4
                        colBackground: pinSubmitBtn.enabled ? Appearance.colors.colPrimary : Appearance.colors.colLayer1
                        colBackgroundHover: Appearance.colors.colPrimaryHover
                        colRipple: Appearance.colors.colPrimaryActive

                        contentItem: RowLayout {
                            spacing: 6
                            MaterialSymbol {
                                text: "push_pin"
                                iconSize: 16
                                color: pinSubmitBtn.enabled ? Appearance.colors.colOnPrimary : Appearance.colors.colSubtext
                            }
                            StyledText {
                                text: Translation.tr("Pin")
                                font.weight: Font.Medium
                                font.pixelSize: Appearance.font.pixelSize.small
                                color: pinSubmitBtn.enabled ? Appearance.colors.colOnPrimary : Appearance.colors.colSubtext
                            }
                        }

                        StyledToolTip {
                            extraVisibleCondition: pinSubmitBtn.hovered
                            text: Translation.tr("Add pin (Ctrl+Enter)")
                        }

                        onClicked: root.addCurrentPin()
                    }
                }
            }
        }
    }

    // Drag and Drop Area covering the pinboard
    DropArea {
        id: dropArea
        anchors.fill: parent
        keys: ["text/uri-list", "text/plain"]
        onEntered: (drag) => { drag.accept(Qt.CopyAction); }
        onDropped: (drop) => {
            if (drop.hasUrls && drop.urls.length > 0) {
                for (let i = 0; i < drop.urls.length; i++) {
                    const clean = FileUtils.trimFileProtocol(drop.urls[i].toString());
                    const ext = clean.split(".").pop().toLowerCase();
                    const imageExts = ["png", "jpg", "jpeg", "webp", "gif", "bmp", "svg", "avif"];
                    if (imageExts.indexOf(ext) !== -1) {
                        Pinboard.addPin("", clean);
                    } else {
                        Pinboard.addPin(clean, "");
                    }
                }
                root.scrollToItem(0);
            } else if (drop.hasText && drop.text.length > 0) {
                Pinboard.addPin(drop.text, "");
                root.scrollToItem(0);
            }
        }
    }

    // Visual drop overlay indicator
    Rectangle {
        anchors.fill: parent
        visible: dropArea.containsDrag
        color: ColorUtils.transparentize(Appearance.colors.colPrimaryContainer, 0.2)
        radius: Appearance.rounding.normal
        border.width: 2
        border.color: Appearance.colors.colPrimary
        z: 999

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 8

            MaterialSymbol {
                Layout.alignment: Qt.AlignHCenter
                text: "file_download"
                iconSize: 48
                color: Appearance.colors.colOnPrimaryContainer
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: Translation.tr("Drop image or text to pin")
                font.pixelSize: Appearance.font.pixelSize.normal
                font.weight: Font.Medium
                color: Appearance.colors.colOnPrimaryContainer
            }
        }
    }
}
