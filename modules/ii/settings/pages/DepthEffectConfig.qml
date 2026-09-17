import qs
import QtQuick
import QtQuick.Layouts
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import Quickshell
import Quickshell.Io

ContentPage {
    id: page
    forceWidth: true
    property string applyError: ""
    property bool applyBusy: false
    property bool applyDone: false

    Timer {
        id: applyFeedbackResetTimer
        interval: 2500
        repeat: false
        onTriggered: applyDone = false
    }

    Connections {
        target: GlobalStates
        function onDepthWallpaperApplyStateChanged() {
            page.applyBusy = GlobalStates.depthWallpaperApplyState === "applying"
            page.applyDone = GlobalStates.depthWallpaperApplyState === "done"
            if (GlobalStates.depthWallpaperApplyState === "done") {
                page.applyError = ""
                applyFeedbackResetTimer.restart()
            } else if (GlobalStates.depthWallpaperApplyState === "error") {
                page.applyError = GlobalStates.depthWallpaperApplyErrorText || Translation.tr("Failed to compose the layers into a wallpaper.")
            }
        }
    }

    function applyWallpaper() {
        page.applyError = ""
        const layers = page.getSortedLayers()

        const missingImages = layers.filter(l => !l.image || !String(l.image).trim().length);

        if (layers.length === 0 || missingImages.length > 0) {
            page.applyError = Translation.tr("Add an image to every layer or remove empty layers.")
            errorShake.restart()
            return
        }
        page.applyBusy = true
        page.applyDone = false
        GlobalStates.applyDepthWallpaperRequested = true
    }

    function browseImage(layerName) {
        const startDir = Quickshell.env("XDG_PICTURES_DIR") || Quickshell.env("HOME") + "/Pictures"
        layerImagePicker.targetLayerName = layerName
        layerImagePicker.command = ["bash", "-c",
            `start="${startDir}"; [ -d "$start" ] || start="$HOME"; \
            if command -v kdialog >/dev/null 2>&1; then \
                kdialog --getopenfilename "$start" "image/png image/jpg image/jpeg image/webp image/bmp image/svg+xml"; \
            elif command -v zenity >/dev/null 2>&1; then \
                zenity --file-selection --file-filter='Images | *.png *.jpg *.jpeg *.webp *.bmp *.svg' --title='Choose layer image' --filename="$start/"; \
            else \
                exit 1; \
            fi`
        ]
        layerImagePicker.running = true
    }

    Process {
        id: layerImagePicker
        property string targetLayerName: ""
        stdout: StdioCollector { id: layerImagePickerOutput }
        onExited: (code) => {
            let path = layerImagePickerOutput.text.trim().split("\n")[0].trim()
            if (code === 0 && path.length > 0 && layerImagePicker.targetLayerName !== "") {
                page.updateLayer(layerImagePicker.targetLayerName, "image", path)
            }
            layerImagePicker.targetLayerName = ""
        }
    }

    function goTo(term) {
        const t = term.toLowerCase().trim()
        function findTarget(rootItem) {
            for (let i = 0; i < rootItem.children.length; i++) {
                let child = rootItem.children[i]
                if (child.title && child.title.toLowerCase().includes(t)) return child
            }
            for (let i = 0; i < rootItem.children.length; i++) {
                let found = findTarget(rootItem.children[i])
                if (found) return found
            }
            return null
        }
        let target = findTarget(mainLayout)
        if (target) {
            let pos = target.mapToItem(mainLayout, 0, 0)
            page.contentY = Math.max(0, pos.y - 0)
        }
    }

    function getSortedLayers() {
        const layers = Config.options.background.depthEffect.layers || [];
        return layers.slice().sort((a, b) => {
            const ai = a.name === "background" ? 0 : (parseInt(a.name.replace("layer", "")) || 1);
            const bi = b.name === "background" ? 0 : (parseInt(b.name.replace("layer", "")) || 1);
            return ai - bi;
        });
    }

    function getNextLayerName() {
        const sorted = getSortedLayers();
        let maxIndex = 0;
        for (const layer of sorted) {
            if (layer.name === "background") continue;
            const idx = parseInt(layer.name.replace("layer", ""));
            if (!isNaN(idx) && idx > maxIndex) maxIndex = idx;
        }
        return "layer" + (maxIndex + 1);
    }

    function addLayer() {
        const layers = Config.options.background.depthEffect.layers.slice();
        layers.push({
            name: getNextLayerName(),
            image: "",
            scale: 150,
            autoScale: false,
            bound: true,
            parallaxSensitivity: 1,
            workspaceParallax: true,
            workspaceParallaxSensitivity: 1,
            mouseParallax: true,
            reverseParallax: false,
            manualPositioning: false,
            positionX: 0,
            positionY: 0
        });
        Config.options.background.depthEffect.layers = layers;
    }

    function removeLayer(layerName) {
        const layers = Config.options.background.depthEffect.layers.slice();
        const idx = layers.findIndex(l => l.name === layerName);
        if (idx >= 0) {
            layers.splice(idx, 1);
            Config.options.background.depthEffect.layers = layers;
        }
    }

    function updateLayer(layerName, key, value) {
        const layers = Config.options.background.depthEffect.layers.slice();
        const idx = layers.findIndex(l => l.name === layerName);
        if (idx >= 0) {
            layers[idx][key] = value;
            Config.options.background.depthEffect.layers = layers;
        }
    }

    ColumnLayout {
        id: mainLayout
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 20

        ContentSection {
            icon: "depth"
            shape: MaterialShape.Shape.Circle
            title: Translation.tr("Depth Effect")
            GroupedList {
                ConfigSwitch {
                    Layout.fillWidth: true
                    buttonIcon: "auto_awesome"
                    text: Translation.tr("Enable depth effect")
                    checked: Config.options.background.depthEffect.enable
                    onCheckedChanged: {
                        Config.options.background.depthEffect.enable = checked
                        // Explicitly request depth apply/restore when the
                        // toggle is clicked, bypassing any potential timing
                        // issue with the BackgroundLayers Connections handler.
                        // ON → compose layers + re-theme from depth composite.
                        // OFF → restore the normal wallpaper + re-theme.
                        if (checked) {
                            GlobalStates.applyDepthWallpaperRequested = true
                        } else {
                            GlobalStates.restoreDepthWallpaperRequested = true
                        }
                    }
                }

                RippleButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 44
                    enabled: Config.options.background.depthEffect.enable
                    onClicked: page.addLayer();
                    contentItem: RowLayout {
                        spacing: 12
                        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                        MaterialSymbol {
                            text: "add_circle"
                            iconSize: Appearance.font.pixelSize.larger
                            color: parent.enabled ? Appearance.colors.colOnSecondaryContainerHover : Appearance.colors.colOnSecondaryContainer
                        }
                        StyledText {
                            text: Translation.tr("Add layer")
                            font.pixelSize: Appearance.font.pixelSize.normal
                            color: parent.enabled ? Appearance.colors.colOnSecondaryContainerHover : Appearance.colors.colOnSecondaryContainer
                        }
                    }
                }
            }
        }

        ContentSection {
            visible: Config.options.background.depthEffect.enable && page.getSortedLayers().length > 0
            icon: "layers"
            shape: MaterialShape.Shape.Pill
            title: Translation.tr("Layers")
            GroupedList {
                Layout.bottomMargin: 10
                Column {
                    Layout.fillWidth: true
                    spacing: 8
                    Repeater {
                        id: layerRepeater
                        model: page.getSortedLayers()
                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            width: parent ? parent.width : 0
                            implicitHeight: layerContent.implicitHeight + 24
                            color: Appearance.colors.colLayer1
                            radius: Appearance.rounding.normal

                            ColumnLayout {
                                id: layerContent
                                anchors { fill: parent; margins: 12 }
                                spacing: 8

                                RowLayout {
                                    spacing: 8
                                    MaterialSymbol {
                                        text: modelData.name === "background" ? "wallpaper" : "layers"
                                        iconSize: Appearance.font.pixelSize.larger
                                        color: Appearance.colors.colPrimary
                                    }
                                    StyledText {
                                        text: modelData.name === "background" ? Translation.tr("Background layer") : modelData.name
                                        font.pixelSize: Appearance.font.pixelSize.normal
                                        font.weight: Font.Medium
                                        color: Appearance.colors.colOnLayer1
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }
                                    Item { Layout.fillWidth: true; Layout.fillHeight: true }
                                    RippleButton {
                                        Layout.fillWidth: false
                                        visible: modelData.name !== "background"
                                        onClicked: page.removeLayer(modelData.name)
                                        contentItem: RowLayout {
                                            spacing: 6
                                            MaterialSymbol { text: "delete"; iconSize: Appearance.font.pixelSize.small; color: Appearance.colors.colOnErrorContainer }
                                            StyledText { text: Translation.tr("Remove"); font.pixelSize: Appearance.font.pixelSize.small; color: Appearance.colors.colOnErrorContainer }
                                        }
                                        background: Rectangle { color: Appearance.colors.colErrorContainer; radius: Appearance.rounding.normal }
                                    }
                                }

                                ConfigTextArea {
                                        id: layerNameField
                                        Layout.fillWidth: true
                                        buttonIcon: "label"
                                        fieldWidth: 250
                                        fieldHeight: 40
                                        text: Translation.tr("Layer name")
                                        placeholderText: Translation.tr("Layer name")
                                        value: modelData.name
                                        visible: modelData.name !== "background"
                                        Timer {
                                            id: layerNameDebounce
                                            interval: 500
                                            repeat: false
                                            onTriggered: page.updateLayer(modelData.name, "name", layerNameField.value);
                                        }
                                        onValueChanged: layerNameDebounce.restart()
                                    }

                                RowLayout {
                                    spacing: 8
                                    ConfigTextArea {
                                        id: imagePathField
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 40
                                        buttonIcon: "image"
                                        fieldWidth: 250
                                        fieldHeight: 40
                                        text: Translation.tr("Image path")
                                        placeholderText: Translation.tr("Image path")
                                        value: modelData.image
                                        Timer {
                                            id: imagePathDebounce
                                            interval: 500
                                            repeat: false
                                            onTriggered: page.updateLayer(modelData.name, "image", imagePathField.value);
                                        }
                                        onValueChanged: imagePathDebounce.restart()
                                    }
                                    RippleButton {
                                        Layout.fillWidth: false
                                        Layout.preferredHeight: 40
                                        enabled: Config.options.background.depthEffect.enable
                                        onClicked: page.browseImage(modelData.name)
                                        contentItem: MaterialSymbol { text: "folder_open"; iconSize: Appearance.font.pixelSize.normal; color: Appearance.colors.colOnSecondaryContainer }
                                    }
                                }

                                Item {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: modelData.image !== "" ? 120 : 0
                                    visible: modelData.image !== ""
                                    Rectangle {
                                        anchors.fill: parent
                                        anchors.margins: 4
                                        color: Appearance.colors.colLayer2
                                        radius: Appearance.rounding.normal
                                        border.width: 1
                                        border.color: Appearance.colors.colOutlineVariant
                                        Image {
                                            anchors.fill: parent
                                            anchors.margins: 2
                                            source: modelData.image.startsWith("file://") ? modelData.image : (modelData.image !== "" ? "file://" + modelData.image : "")
                                            fillMode: Image.PreserveAspectCrop
                                            cache: true
                                            smooth: true
                                            mipmap: true
                                            opacity: status === Image.Ready ? 1 : 0
                                        }
                                    }
                                }

                                // ✅ Auto Scale: when ON the image is auto-sized to accommodate the
                                // parallax range so it always covers the screen.
                                // When OFF the exact manual scale below is kept.
                                ConfigSwitch {
                                    Layout.fillWidth: true
                                    buttonIcon: "auto_awesome"
                                    text: Translation.tr("Auto scale (Recommended)")
                                    checked: modelData.autoScale ?? false
                                    onCheckedChanged: page.updateLayer(modelData.name, "autoScale", checked);
                                    StyledToolTip { text: Translation.tr("Auto-scales the image to the parallax range so it always fully covers the screen. When OFF, your exact manual scale below is preserved.") }
                                }

                                ConfigSlider {
                                    Layout.fillWidth: true
                                    text: Translation.tr("Manual scale")
                                    value: modelData.scale
                                    from: 100
                                    to: 200
                                    usePercentTooltip: true
                                    showValue: true
                                    animateValue: false
                                    liveUpdate: false
                                    // ✅ Slider disabled while auto-scale is on
                                    enabled: !(modelData.autoScale ?? false)
                                    onCommitted: (v) => page.updateLayer(modelData.name, "scale", v);
                                }

                                ConfigSwitch {
                                    Layout.fillWidth: true
                                    buttonIcon: "crop_free"
                                    text: Translation.tr("Bound to screen edges")
                                    checked: modelData.bound ?? false
                                    onCheckedChanged: page.updateLayer(modelData.name, "bound", checked);
                                    StyledToolTip { text: Translation.tr("Does NOT change your scale. It clamps X and Y movement independently to the image's own coverage on each axis, so the underlying background is never exposed. OFF = unrestricted movement (overflow allowed).") }
                                }

                                ConfigSwitch {
                                    Layout.fillWidth: true
                                    buttonIcon: "mouse"
                                    text: Translation.tr("Mouse parallax")
                                    checked: modelData.mouseParallax
                                    onCheckedChanged: page.updateLayer(modelData.name, "mouseParallax", checked);
                                }

                                // ✅ NEW: Reverse Parallax Toggle
                                ConfigSwitch {
                                    Layout.fillWidth: true
                                    buttonIcon: "flip"
                                    text: Translation.tr("Reverse parallax")
                                    checked: modelData.reverseParallax ?? false
                                    onCheckedChanged: page.updateLayer(modelData.name, "reverseParallax", checked);
                                    StyledToolTip { text: Translation.tr("Image moves in the SAME direction as the mouse") }
                                }

                                ConfigSlider {
                                    Layout.fillWidth: true
                                    text: Translation.tr("Parallax sensitivity")
                                    value: modelData.parallaxSensitivity
                                    from: 0
                                    to: 1
                                    usePercentTooltip: true
                                    showValue: true
                                    animateValue: false
                                    liveUpdate: false
                                    onCommitted: (v) => page.updateLayer(modelData.name, "parallaxSensitivity", v);
                                }

                                ConfigSwitch {
                                    Layout.fillWidth: true
                                    buttonIcon: "open_in_full"
                                    text: Translation.tr("Workspace parallax")
                                    checked: modelData.workspaceParallax
                                    onCheckedChanged: page.updateLayer(modelData.name, "workspaceParallax", checked);
                                }

                                ConfigSlider {
                                    Layout.fillWidth: true
                                    text: Translation.tr("Workspace parallax sensitivity")
                                    value: modelData.workspaceParallaxSensitivity ?? 1
                                    from: 0
                                    to: 1
                                    usePercentTooltip: true
                                    showValue: true
                                    animateValue: false
                                    liveUpdate: false
                                    enabled: modelData.workspaceParallax
                                    onCommitted: (v) => page.updateLayer(modelData.name, "workspaceParallaxSensitivity", v);
                                }

                                ConfigSlider {
                                    Layout.fillWidth: true
                                    text: Translation.tr("Workspace support number")
                                    value: Config.options.background.depthEffect.workspaceParallaxSupportNumber || 5
                                    from: 2
                                    to: 20
                                    stepSize: 1
                                    showValue: true
                                    animateValue: false
                                    liveUpdate: false
                                    usePercentTooltip: false
                                    onCommitted: (v) => Config.options.background.depthEffect.workspaceParallaxSupportNumber = Math.round(v);
                                }

                                // ✅ Manual positioning: OFF keeps the image centered / filling the
                                // screen exactly like before. ON places the image's top-left corner
                                // at (X, Y) pixels from the screen's top-left corner — negatives move
                                // it off-screen. Parallax keeps working on top of this placement.
                                ConfigSwitch {
                                    Layout.fillWidth: true
                                    buttonIcon: "center_focus_weak"
                                    text: Translation.tr("Positioning")
                                    checked: modelData.manualPositioning ?? false
                                    onCheckedChanged: page.updateLayer(modelData.name, "manualPositioning", checked);
                                    StyledToolTip { text: Translation.tr("OFF: image centered, unchanged. ON: place the image by pixels — its top-left corner sits at (X, Y), with (0,0) the screen's top-left corner. Negative X/Y move it off-screen. Parallax still applies on top.") }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    visible: modelData.manualPositioning ?? false
                                    spacing: 8
                                    ConfigTextArea {
                                        id: positionXField
                                        Layout.fillWidth: true
                                        buttonIcon: "swap_horiz"
                                        fieldWidth: 120
                                        fieldHeight: 40
                                        text: Translation.tr("X (px)")
                                        placeholderText: "0"
                                        value: String(modelData.positionX ?? 0)
                                        Timer {
                                            id: positionXDebounce
                                            interval: 400
                                            repeat: false
                                            onTriggered: {
                                                const v = Number(positionXField.value);
                                                if (!isNaN(v)) page.updateLayer(modelData.name, "positionX", v);
                                                else positionXField.value = String(modelData.positionX ?? 0);
                                            }
                                        }
                                        onValueChanged: positionXDebounce.restart()
                                    }
                                    ConfigTextArea {
                                        id: positionYField
                                        Layout.fillWidth: true
                                        buttonIcon: "swap_vert"
                                        fieldWidth: 120
                                        fieldHeight: 40
                                        text: Translation.tr("Y (px)")
                                        placeholderText: "0"
                                        value: String(modelData.positionY ?? 0)
                                        Timer {
                                            id: positionYDebounce
                                            interval: 400
                                            repeat: false
                                            onTriggered: {
                                                const v = Number(positionYField.value);
                                                if (!isNaN(v)) page.updateLayer(modelData.name, "positionY", v);
                                                else positionYField.value = String(modelData.positionY ?? 0);
                                            }
                                        }
                                        onValueChanged: positionYDebounce.restart()
                                    }
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colSubtext
                                    text: Translation.tr("Top-left of the image = (X, Y). (0,0) is the screen's top-left corner; positive X moves right, positive Y moves down. Positioning never scales the image.")
                                    wrapMode: Text.WordWrap
                                    visible: modelData.manualPositioning ?? false
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colErrorContainer
                                    text: Translation.tr("With Bound ON, each axis's movement is clamped to the image's own margin. At 100% the image barely covers the screen (vertical room ≈ 0), so raise the Manual scale — or enable Auto Scale — for more parallax range.")
                                    wrapMode: Text.WordWrap
                                    visible: !(modelData.autoScale ?? false) && (modelData.scale ?? 100) <= 100
                                        && (modelData.mouseParallax || modelData.workspaceParallax)
                                }
                            }
                        }
                    }
                }
            }
        }

        Rectangle {
            id: applyErrorBox
            Layout.fillWidth: true
            visible: page.applyError !== ""
            opacity: page.applyError !== "" ? 1 : 0
            color: Appearance.colors.colErrorContainer
            radius: Appearance.rounding.normal
            implicitHeight: 44
            RowLayout {
                anchors { fill: parent; margins: 12 }
                spacing: 10
                MaterialSymbol {
                    text: "error"
                    iconSize: Appearance.font.pixelSize.normal
                    color: Appearance.colors.colOnErrorContainer
                    RotationAnimator on rotation {
                        id: errorShake
                        from: -8
                        to: 8
                        duration: 70
                        loops: 4
                        running: false
                    }
                }
                StyledText {
                    Layout.fillWidth: true
                    text: page.applyError
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: Appearance.colors.colOnErrorContainer
                    wrapMode: Text.WordWrap
                }
            }
            Behavior on opacity { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
        }

        RippleButton {
            Layout.fillWidth: true
            Layout.preferredHeight: 48
            Layout.bottomMargin: 8
            visible: Config.options.background.depthEffect.enable
            enabled: !page.applyBusy
            onClicked: page.applyWallpaper()
            background: Rectangle {
                color: page.applyDone ? Appearance.colors.colTertiaryContainer : Appearance.colors.colPrimary
                radius: Appearance.rounding.normal
                Behavior on color { ColorAnimation { duration: 200 } }
            }
            contentItem: RowLayout {
                spacing: 12
                anchors { fill: parent; leftMargin: 16; rightMargin: 16 }
                MaterialSymbol {
                    text: page.applyBusy ? "progress_activity" : page.applyDone ? "check_circle" : "wallpaper"
                    iconSize: Appearance.font.pixelSize.larger
                    color: page.applyDone ? Appearance.colors.colOnTertiaryContainer : Appearance.colors.colOnPrimary
                    RotationAnimator on rotation {
                        running: page.applyBusy
                        from: 0
                        to: 360
                        duration: 1100
                        loops: Animation.Infinite
                    }
                }
                StyledText {
                    text: page.applyBusy ? Translation.tr("Compositing…") : page.applyDone ? Translation.tr("Applied to wallpaper") : Translation.tr("Apply wallpaper")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.Medium
                    color: page.applyDone ? Appearance.colors.colOnTertiaryContainer : Appearance.colors.colOnPrimary
                }
                Item { Layout.fillWidth: true }
                StyledText {
                    text: page.applyDone ? Translation.tr("Layers baked in") : Translation.tr("Composes all layers into the wallpaper")
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: ColorUtils.transparentize(page.applyDone ? Appearance.colors.colOnTertiaryContainer : Appearance.colors.colOnPrimary, 0.2)
                }
            }
        }
    }
}
