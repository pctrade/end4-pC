pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import qs.modules.ii.background.widgets.customtext

/**
 * Settings card group for fully independent custom text widgets.
 *
 * Lives inside the Desktop settings right under the Clock section. Every
 * custom widget is an entry in `widgets.customWidgets`; all writes go through
 * CustomWidgets.save() (whole-list reassignment) so config persists and the
 * running widgets update live.
 */
ContentSection {
    id: root
    icon: "edit_note"
    shape: MaterialShape.Shape.Pill
    title: Translation.tr("Custom Widgets")

    readonly property var helper: CustomWidgets {}
    property bool ready: false
    readonly property var ids: Config.options.background.widgets.customWidgetIds ?? []

    readonly property real screenW: Quickshell.screens.length > 0 ? Quickshell.screens[0].width : 1920
    readonly property real screenH: Quickshell.screens.length > 0 ? Quickshell.screens[0].height : 1080

    property var pendingFontWidget: ""
    property var fontStatusMap: ({})

    function entry(id) {
        return root.helper.find(id)
    }

    // Qt.fontFamilies() returns a list of font family names. In some Qt/Quickshell
    // builds the elements may arrive as QJSValue/V4ReferenceObject wrappers, so we
    // normalise each entry to a plain string here.
    function fontFamilyName(f) {
        if (f == null) return ""
        if (typeof f === "string") return f.trim()
        if (typeof f === "object") {
            const s = (typeof f.toString === "function") ? f.toString().trim() : ""
            if (s && s !== "[object Object]" && s !== "[Object V4ReferenceObject]") return s
            const direct = f.family ?? f.fontFamily ?? f.familyName ?? f.name
            if (typeof direct === "string" && direct.trim()) return direct.trim()
            const viaText = f.text
            if (typeof viaText === "string" && viaText.trim()) return viaText.trim()
            const viaValueOf = (typeof f.valueOf === "function") ? f.valueOf() : null
            if (typeof viaValueOf === "string" && viaValueOf.trim()) return viaValueOf.trim()
        }
        const s = String(f).trim()
        return (s === "[object Object]" || s === "[Object V4ReferenceObject]") ? "" : s
    }

    function fontFamilies() {
        const raw = Qt.fontFamilies() ?? []
        const out = []
        const n = raw.length ?? 0
        for (let i = 0; i < n; ++i) {
            const name = root.fontFamilyName(raw[i])
            if (name) out.push(name)
        }
        return [...new Set(out)]
    }


    function setField(id, key, value) {
        root.setFields(id, { [key]: value })
    }

    function setFields(id, changes) {
        if (!root.ready) return
        const e = root.helper.find(id)
        if (!e) return
        for (const key of Object.keys(changes)) e[key] = changes[key]
        root.helper.save(e)
    }

    // Signals fire while the settings page is being built (control bindings
    // evaluate their initial values), and must not be written back to config.
    Component.onCompleted: {
        root.ready = true
    }

    function addWidget() {
        root.helper.addDefaults(root.screenW, root.screenH)
    }

    function removeWidget(id) {
        root.helper.remove(id)
    }

    function duplicateWidget(id) {
        root.helper.duplicate(id)
    }

    function posDisplay(id, key, unit) {
        const e = root.entry(id)
        if (!e) return ""
        const val = e[key] ?? 0
        const ref = key === "x" ? root.screenW : root.screenH
        if (unit === "%") return String(Math.round(val / ref * 100))
        return String(Math.round(val))
    }

    function posCommit(id, key, unit, raw) {
        if (!root.ready) return
        const v = parseFloat(raw)
        if (isNaN(v)) return
        // Skip commit when the field still holds exactly the representation
        // of the stored value (initialization round-trip must not rewrite,
        // or rounding would make the position drift on every page build).
        if (root.posDisplay(id, key, unit) === String(v)) return
        const ref = key === "x" ? root.screenW : root.screenH
        root.setField(id, key, unit === "%" ? Math.round(ref * v / 100) : Math.round(v))
    }

    function insertToken(field, token) {
        if (!field?.textArea) return
        field.textArea.insert(field.textArea.cursorPosition, token)
        field.textArea.forceActiveFocus()
    }

    function applyGoogleFont(id, family) {
        const name = String(family ?? "").trim()
        const wasBusy = GoogleFonts.loading
        root.setFontStatus(id, Translation.tr("Downloading \"%1\"…").arg(name))
        if (wasBusy) {
            // apply() early-returns while another download is running, so the
            // pending click must never look like a silent no-op.
            root.setFontStatus(id, Translation.tr("Busy with another font download — try again in a moment."))
            return
        }
        root.pendingFontWidget = id
        GoogleFonts.errorMessage = ""
        GoogleFonts.apply(family)
    }

    function setFontStatus(id, text) {
        const m = {}
        for (const k of Object.keys(root.fontStatusMap)) m[k] = root.fontStatusMap[k]
        m[id] = text
        root.fontStatusMap = m
    }

    function onGoogleFontApplied(id, family) {
        root.setFields(id, {
            fontSource: "google",
            fontFamily: family,
            appliedFont: family
        })
        root.setFontStatus(id, Translation.tr("Applied: %1").arg(family))
    }

    Connections {
        target: GoogleFonts
        function onApplied(family) {
            const id = root.pendingFontWidget
            root.pendingFontWidget = ""
            if (id !== "") root.onGoogleFontApplied(id, family)
        }
        function onFailed(message) {
            const id = root.pendingFontWidget
            root.pendingFontWidget = ""
            if (id !== "") root.setFontStatus(id, message)
        }
    }

    GroupedList {
        Layout.bottomMargin: 10
        ColumnLayout {
            id: groupColumn
            Layout.fillWidth: true
            spacing: 8

            RippleButton {
                Layout.fillWidth: true
                Layout.preferredHeight: 44
                onClicked: root.addWidget()
                contentItem: RowLayout {
                    spacing: 12
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
                    MaterialSymbol {
                        text: "add_circle"
                        iconSize: Appearance.font.pixelSize.larger
                        color: Appearance.colors.colSecondaryContainerHover
                    }
                    StyledText {
                        text: Translation.tr("Add widget")
                        font.pixelSize: Appearance.font.pixelSize.normal
                        color: Appearance.colors.colSecondaryContainerHover
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                visible: root.ids.length === 0
                Layout.preferredHeight: visible ? implicitHeight : 0
                text: Translation.tr("No custom widgets yet. Add one above — position is anchored to the widget center, and date/time tokens (like HH:mm) update live.")
                wrapMode: Text.Wrap
                color: Appearance.colors.colSubtext
            }

            Repeater {
                model: root.ids
                delegate: Rectangle {
                    id: card
                    required property string modelData
                    property var e: root.entry(card.modelData) ?? null
                    property bool expanded: true
                    property string pendingPadKey: ""
                    property string pendingRadiusKey: ""

                    // The card is a direct ColumnLayout child (the Repeater
                    // parents delegates to groupColumn); let the layout stretch
                    // it, and derive its height from the inner ColumnLayout's
                    // own measurement so expanding/collapsing the body (outline,
                    // badge, radius/padding rows) always propagates correctly
                    // instead of relying on a hand-summed implicitHeight.
                    Layout.fillWidth: true
                    Layout.preferredHeight: cardColumn.implicitHeight + 16
                    color: Appearance.colors.colLayer1
                    radius: Appearance.rounding.normal


                    ColumnLayout {
                        id: cardColumn
                        anchors { fill: parent; topMargin: 8; bottomMargin: 8; leftMargin: 12; rightMargin: 12 }
                        spacing: 6

                        RowLayout {
                            id: cardHeader
                            Layout.fillWidth: true
                            spacing: 8

                            MaterialSymbol {
                                text: "text_fields"
                                iconSize: Appearance.font.pixelSize.larger
                                color: Appearance.colors.colPrimary
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: card.e ? (card.e.text ?? "") : ""
                                elide: Text.ElideRight
                                font.pixelSize: Appearance.font.pixelSize.normal
                                color: Appearance.colors.colOnLayer1
                            }

                            ConfigSwitch {
                                Layout.fillWidth: false
                                text: ""
                                checked: card.e?.enable ?? false
                                onCheckedChanged: {
                                    root.setField(card.modelData, "enable", checked)
                                    if (checked) root.setField(card.modelData, "depthLayerPosition", -1)
                                }
                            }

                            RippleButton {
                                Layout.fillWidth: false
                                Layout.preferredHeight: 32
                                onClicked: root.duplicateWidget(card.modelData)
                                contentItem: MaterialSymbol {
                                    text: "content_copy"
                                    iconSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colOnSecondaryContainer
                                }
                                background: Rectangle {
                                    color: Appearance.colors.colLayer2
                                    radius: Appearance.rounding.small
                                }
                            }

                            RippleButton {
                                Layout.fillWidth: false
                                Layout.preferredHeight: 32
                                onClicked: root.removeWidget(card.modelData)
                                contentItem: MaterialSymbol {
                                    text: "delete"
                                    iconSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colOnErrorContainer
                                }
                                background: Rectangle {
                                    color: Appearance.colors.colErrorContainer
                                    radius: Appearance.rounding.small
                                }
                            }

                            RippleButton {
                                Layout.fillWidth: false
                                Layout.preferredHeight: 32
                                onClicked: card.expanded = !card.expanded
                                contentItem: MaterialSymbol {
                                    text: card.expanded ? "expand_less" : "expand_more"
                                    iconSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colOnLayer1
                                }
                                background: Rectangle {
                                    color: Appearance.colors.colLayer2
                                    radius: Appearance.rounding.small
                                }
                            }
                        }

                        ColumnLayout {
                            id: cardBody
                            Layout.fillWidth: true
                            visible: card.expanded
                            Layout.preferredHeight: visible ? implicitHeight : 0
                            spacing: 8

                            // ── Content ───────────────────────────────
                            ConfigTextArea {
                                id: textField
                                Layout.fillWidth: true
                                fieldWidth: 300
                                fieldHeight: 64
                                buttonIcon: "text_fields"
                                text: Translation.tr("Text")
                                placeholderText: Translation.tr("Hello World · EEEE, dd MMMM yyyy · HH:mm")
                                modelSync: true
                                modelValue: card.e?.text ?? ""
                                Timer {
                                    id: textDebounce
                                    interval: 600
                                    repeat: false
                                    onTriggered: root.setField(card.modelData, "text", textField.value)
                                }
                                onValueChanged: if (!textField.applyingModel) textDebounce.restart()
                            }

                            Flow {
                                Layout.fillWidth: true
                                spacing: 4
                                Repeater {
                                    model: ["EEEE", "ddd", "dd", "MMMM", "yyyy", "HH:mm", "hh:mm a", "h:mm a", "s"]
                                    delegate: RippleButton {
                                        required property string modelData
                                        implicitHeight: 26
                                        onClicked: root.insertToken(textField, modelData)
                                        contentItem: StyledText {
                                            text: modelData
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            color: Appearance.colors.colOnSecondaryContainer
                                        }
                                        background: Rectangle {
                                            color: Appearance.colors.colSecondaryContainer
                                            radius: Appearance.rounding.small
                                        }
                                    }
                                }
                            }

                            ConfigSelectionArray {
                                text: Translation.tr("Alignment")
                                icon: "format_align_center"
                                currentValue: card.e?.textAlignment ?? "center"
                                onSelected: v => root.setField(card.modelData, "textAlignment", v)
                                options: [
                                    { displayName: "Left", icon: "format_align_left", value: "left" },
                                    { displayName: "Center", icon: "format_align_center", value: "center" },
                                    { displayName: "Right", icon: "format_align_right", value: "right" },
                                ]
                            }

                            // ── Typography ────────────────────────────
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                ConfigSpinBox {
                                    id: fontSizeSpin
                                    Layout.fillWidth: true
                                    icon: "format_size"
                                    text: Translation.tr("Font size")
                                    value: card.e?.fontSize ?? 48
                                    from: 8
                                    to: 400
                                    stepSize: 1
                                    onValueChanged: fontSizeTimer.restart()
                                }
                                ConfigSelectionArray {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: ""
                                    icon: "straighten"
                                    currentValue: card.e?.fontSizeUnit ?? "px"
                                    onSelected: v => root.setField(card.modelData, "fontSizeUnit", v)
                                    options: [
                                        { displayName: "px", icon: "straighten", value: "px" },
                                        { displayName: "%", icon: "percent", value: "%" },
                                    ]
                                }
                                Timer {
                                    id: fontSizeTimer
                                    interval: 300
                                    repeat: false
                                    onTriggered: root.setField(card.modelData, "fontSize", fontSizeSpin.value)
                                }
                            }

                            ConfigSlider {
                                id: weightSlider
                                text: Translation.tr("Weight")
                                buttonIcon: "format_bold"
                                from: 100
                                to: 900
                                stepSize: 100
                                usePercentTooltip: false
                                value: card.e?.fontWeight ?? 400
                                onValueChanged: weightTimer.restart()
                                Timer {
                                    id: weightTimer
                                    interval: 200
                                    repeat: false
                                    onTriggered: root.setField(card.modelData, "fontWeight", Math.round(weightSlider.value))
                                }
                            }

                            ConfigSwitch {
                                buttonIcon: "format_italic"
                                text: Translation.tr("Italic")
                                checked: card.e?.fontItalic ?? false
                                onCheckedChanged: root.setField(card.modelData, "fontItalic", checked)
                            }

                            ConfigSelectionArray {
                                text: Translation.tr("Text style")
                                icon: "format_color_text"
                                currentValue: card.e?.fontSolid === false ? "outlined" : "solid"
                                onSelected: v => root.setField(card.modelData, "fontSolid", v === "solid")
                                options: [
                                    { displayName: "Solid", icon: "format_color_fill", value: "solid" },
                                    { displayName: "Outlined", icon: "format_color_reset", value: "outlined" },
                                ]
                            }

                            ColorSelectionArray {
                                text: Translation.tr("Text color")
                                icon: "palette"
                                currentValue: card.e?.textColor ?? ""
                                onSelected: v => root.setField(card.modelData, "textColor", v)
                            }

                            ConfigTextArea {
                                id: textColorField
                                Layout.fillWidth: true
                                fieldWidth: 200
                                fieldHeight: 40
                                buttonIcon: "colorize"
                                text: Translation.tr("Text color hex")
                                placeholderText: Translation.tr("#RRGGBBAA or theme role")
                                modelSync: true
                                modelValue: card.e?.textColor ?? ""
                                onValueChanged: if (!textColorField.applyingModel) textColorDebounce.restart()
                                Timer {
                                    id: textColorDebounce
                                    interval: 600
                                    repeat: false
                                    onTriggered: root.setField(card.modelData, "textColor", textColorField.value.trim())
                                }
                            }

                            ColumnLayout {
                                id: outlineSection
                                Layout.fillWidth: true
                                visible: card.e?.fontSolid === false
                                Layout.preferredHeight: visible ? implicitHeight : 0
                                spacing: 6
                                ColorSelectionArray {
                                    Layout.fillWidth: true
                                    text: Translation.tr("Outline color")
                                    icon: "border_color"
                                    currentValue: card.e?.outlineColor ?? ""
                                    onSelected: v => root.setField(card.modelData, "outlineColor", v)
                                }
                                ConfigTextArea {
                                    id: outlineColorField
                                    Layout.fillWidth: true
                                    fieldWidth: 200
                                    fieldHeight: 40
                                    buttonIcon: "colorize"
                                    text: Translation.tr("Outline color hex")
                                    placeholderText: Translation.tr("#RRGGBBAA or theme role")
                                    modelSync: true
                                    modelValue: card.e?.outlineColor ?? ""
                                    onValueChanged: if (!outlineColorField.applyingModel) outlineColorDebounce.restart()
                                    Timer {
                                        id: outlineColorDebounce
                                        interval: 600
                                        repeat: false
                                        onTriggered: root.setField(card.modelData, "outlineColor", outlineColorField.value.trim())
                                    }
                                }
                                ConfigSlider {
                                    id: outlineSlider
                                    Layout.fillWidth: true
                                    text: Translation.tr("Outline width")
                                    buttonIcon: "border_all"
                                    from: 0
                                    to: 8
                                    stepSize: 1
                                    usePercentTooltip: false
                                    value: card.e?.outlineWidth ?? 2
                                    onValueChanged: outlineTimer.restart()
                                    Timer {
                                        id: outlineTimer
                                        interval: 200
                                        repeat: false
                                        onTriggered: root.setField(card.modelData, "outlineWidth", Math.round(outlineSlider.value))
                                    }
                                }
                            }

                            // ── Fonts ─────────────────────────────────
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                StyledComboBoxSearch {
                                    id: systemFontBox
                                    Layout.fillWidth: true
                                    textRole: "text"
                                    model: root.fontFamilies().sort().map(f => ({ text: f }))
                                    currentIndex: {
                                        const fam = card.e?.appliedFont ?? ""
                                        const names = root.fontFamilies().sort()
                                        const idx = names.indexOf(fam)
                                        return idx >= 0 ? idx : -1
                                    }
                                }
                                RippleButton {
                                    Layout.fillWidth: false
                                    Layout.preferredHeight: 40
                                    enabled: systemFontBox.currentIndex >= 0
                                    onClicked: {
                                        const fam = systemFontBox.currentText
                                        if (fam) {
                                            root.setField(card.modelData, "fontSource", "system")
                                            root.setField(card.modelData, "appliedFont", fam)
                                        }
                                    }
                                    contentItem: StyledText {
                                        text: Translation.tr("Apply")
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        color: Appearance.colors.colOnSecondaryContainer
                                    }
                                    background: Rectangle {
                                        color: Appearance.colors.colSecondaryContainer
                                        radius: Appearance.rounding.small
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                ConfigTextArea {
                                    id: googleFontField
                                    Layout.fillWidth: true
                                    fieldWidth: 220
                                    fieldHeight: 40
                                    buttonIcon: "font_download"
                                    text: Translation.tr("Google Font")
                                    placeholderText: Translation.tr("e.g. Roboto Mono, Space Grotesk")
                                    modelSync: true
                                    modelValue: card.e?.fontFamily ?? ""
                                    onValueChanged: if (!googleFontField.applyingModel) googleFontDebounce.restart()
                                    Timer {
                                        id: googleFontDebounce
                                        interval: 600
                                        repeat: false
                                        onTriggered: root.setField(card.modelData, "fontFamily", googleFontField.value)
                                    }
                                }
                                RippleButton {
                                    Layout.fillWidth: false
                                    Layout.preferredHeight: 40
                                    enabled: !GoogleFonts.loading && googleFontField.value.trim().length > 0
                                    onClicked: root.applyGoogleFont(card.modelData, googleFontField.value)
                                    contentItem: StyledText {
                                        text: GoogleFonts.loading && root.pendingFontWidget === card.modelData
                                            ? Translation.tr("Downloading…")
                                            : Translation.tr("Apply")
                                        font.pixelSize: Appearance.font.pixelSize.small
                                        color: Appearance.colors.colOnSecondaryContainer
                                    }
                                    background: Rectangle {
                                        color: Appearance.colors.colSecondaryContainer
                                        radius: Appearance.rounding.small
                                    }
                                }
                            }

                            StyledText {
                                Layout.fillWidth: true
                                visible: (root.fontStatusMap[card.modelData] ?? "").length > 0
                                Layout.preferredHeight: visible ? implicitHeight : 0
                                text: root.fontStatusMap[card.modelData] ?? ""
                                wrapMode: Text.Wrap
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: Appearance.colors.colSubtext
                            }

                            // ── Position ──────────────────────────────
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                ConfigTextArea {
                                    id: xField
                                    Layout.fillWidth: true
                                    fieldWidth: 100
                                    fieldHeight: 40
                                    buttonIcon: "swap_horiz"
                                    text: Translation.tr("X (center)")
                                    modelSync: true
                                    modelValue: root.posDisplay(card.modelData, "x", card.e?.xUnit ?? "px")
                                    onValueChanged: if (!xField.applyingModel) xDebounce.restart()
                                    Timer {
                                        id: xDebounce
                                        interval: 600
                                        repeat: false
                                        onTriggered: root.posCommit(card.modelData, "x", card.e?.xUnit ?? "px", xField.value)
                                    }
                                }
                                ConfigSelectionArray {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: ""
                                    icon: "straighten"
                                    currentValue: card.e?.xUnit ?? "px"
                                    onSelected: v => root.setField(card.modelData, "xUnit", v)
                                    options: [
                                        { displayName: "px", icon: "straighten", value: "px" },
                                        { displayName: "%", icon: "percent", value: "%" },
                                    ]
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                ConfigTextArea {
                                    id: yField
                                    Layout.fillWidth: true
                                    fieldWidth: 100
                                    fieldHeight: 40
                                    buttonIcon: "swap_vert"
                                    text: Translation.tr("Y (center)")
                                    modelSync: true
                                    modelValue: root.posDisplay(card.modelData, "y", card.e?.yUnit ?? "px")
                                    onValueChanged: if (!yField.applyingModel) yDebounce.restart()
                                    Timer {
                                        id: yDebounce
                                        interval: 600
                                        repeat: false
                                        onTriggered: root.posCommit(card.modelData, "y", card.e?.yUnit ?? "px", yField.value)
                                    }
                                }
                                ConfigSelectionArray {
                                    Layout.alignment: Qt.AlignVCenter
                                    text: ""
                                    icon: "straighten"
                                    currentValue: card.e?.yUnit ?? "px"
                                    onSelected: v => root.setField(card.modelData, "yUnit", v)
                                    options: [
                                        { displayName: "px", icon: "straighten", value: "px" },
                                        { displayName: "%", icon: "percent", value: "%" },
                                    ]
                                }
                            }

                            // ── Badge ─────────────────────────────────
                            ConfigSwitch {
                                buttonIcon: "drag_indicator"
                                text: Translation.tr("Draggable on the desktop")
                                checked: card.e?.draggable ?? true
                                // Per-widget preference: always interactive so the value can be
                                // set even while the global "Lock widget positions" is on.
                                // The global lock is enforced at the widget (drag.target),
                                // not by disabling this control.
                                enabled: true
                                opacity: 1
                                onCheckedChanged: root.setField(card.modelData, "draggable", checked)
                            }

                            ConfigSwitch {
                                buttonIcon: "monitor_heart"
                                text: Translation.tr("Badge")
                                checked: card.e?.badge ?? false
                                onCheckedChanged: root.setField(card.modelData, "badge", checked)
                            }

                            ColumnLayout {
                                id: badgeSection
                                Layout.fillWidth: true
                                visible: card.e?.badge === true
                                Layout.preferredHeight: visible ? implicitHeight : 0
                                spacing: 6

                                ConfigSelectionArray {
                                    Layout.fillWidth: true
                                    text: Translation.tr("Badge style")
                                    icon: "format_color_fill"
                                    currentValue: card.e?.badgeSolid === false ? "outlined" : "solid"
                                    onSelected: v => root.setField(card.modelData, "badgeSolid", v === "solid")
                                    options: [
                                        { displayName: "Solid", icon: "format_color_fill", value: "solid" },
                                        { displayName: "Outlined", icon: "border_color", value: "outlined" },
                                    ]
                                }

                                ColorSelectionArray {
                                    Layout.fillWidth: true
                                    text: Translation.tr("Badge color")
                                    icon: "palette"
                                    currentValue: card.e?.badgeColor ?? ""
                                    onSelected: v => root.setField(card.modelData, "badgeColor", v)
                                }

                                ConfigTextArea {
                                    id: badgeColorField
                                    Layout.fillWidth: true
                                    fieldWidth: 200
                                    fieldHeight: 40
                                    buttonIcon: "colorize"
                                    text: Translation.tr("Badge color hex")
                                    placeholderText: Translation.tr("#RRGGBBAA or theme role")
                                    modelSync: true
                                    modelValue: card.e?.badgeColor ?? ""
                                    onValueChanged: if (!badgeColorField.applyingModel) badgeColorDebounce.restart()
                                    Timer {
                                        id: badgeColorDebounce
                                        interval: 600
                                        repeat: false
                                        onTriggered: root.setField(card.modelData, "badgeColor", badgeColorField.value.trim())
                                    }
                                }

                                ConfigSlider {
                                    id: blurSlider
                                    Layout.fillWidth: true
                                    text: Translation.tr("Badge blur")
                                    buttonIcon: "blur_on"
                                    from: 0
                                    to: 40
                                    stepSize: 1
                                    usePercentTooltip: false
                                    value: card.e?.badgeBlur ?? 0
                                    onValueChanged: blurTimer.restart()
                                    Timer {
                                        id: blurTimer
                                        interval: 200
                                        repeat: false
                                        onTriggered: root.setField(card.modelData, "badgeBlur", Math.round(blurSlider.value))
                                    }
                                }

                                ColorSelectionArray {
                                    Layout.fillWidth: true
                                    text: Translation.tr("Badge outline color")
                                    icon: "border_color"
                                    currentValue: card.e?.badgeOutlineColor ?? ""
                                    onSelected: v => root.setField(card.modelData, "badgeOutlineColor", v)
                                }

                                ConfigTextArea {
                                    id: badgeOutlineColorField
                                    Layout.fillWidth: true
                                    fieldWidth: 200
                                    fieldHeight: 40
                                    buttonIcon: "colorize"
                                    text: Translation.tr("Badge outline color hex")
                                    placeholderText: Translation.tr("#RRGGBBAA or theme role")
                                    modelSync: true
                                    modelValue: card.e?.badgeOutlineColor ?? ""
                                    onValueChanged: if (!badgeOutlineColorField.applyingModel) badgeOutlineColorDebounce.restart()
                                    Timer {
                                        id: badgeOutlineColorDebounce
                                        interval: 600
                                        repeat: false
                                        onTriggered: root.setField(card.modelData, "badgeOutlineColor", badgeOutlineColorField.value.trim())
                                    }
                                }

                                ConfigSlider {
                                    id: badgeOutlineWidthSlider
                                    Layout.fillWidth: true
                                    text: Translation.tr("Badge outline width")
                                    buttonIcon: "border_outer"
                                    from: 0
                                    to: 10
                                    stepSize: 1
                                    value: card.e?.badgeOutlineWidth ?? 2
                                    onValueChanged: badgeOutlineWidthTimer.restart()
                                    Timer {
                                        id: badgeOutlineWidthTimer
                                        interval: 200
                                        repeat: false
                                        onTriggered: root.setField(card.modelData, "badgeOutlineWidth", Math.round(badgeOutlineWidthSlider.value))
                                    }
                                }

                                ConfigSwitch {
                                    buttonIcon: "crop_square"
                                    text: Translation.tr("Same radius for all corners")
                                    checked: card.e?.badgeSameRadius ?? true
                                    onCheckedChanged: {
                                        const r = card.e?.badgeRadiusTL ?? 16
                                        if (checked) {
                                            root.setFields(card.modelData, {
                                                badgeSameRadius: checked,
                                                badgeRadiusTR: r,
                                                badgeRadiusBR: r,
                                                badgeRadiusBL: r
                                            })
                                        } else {
                                            root.setField(card.modelData, "badgeSameRadius", checked)
                                        }
                                    }
                                }

                                ConfigSpinBox {
                                    id: radiusSettingSlider
                                    Layout.fillWidth: true
                                    visible: card.e?.badgeSameRadius ?? true
                                    Layout.preferredHeight: visible ? implicitHeight : 0
                                    icon: "radio_button_checked"
                                    text: Translation.tr("Corner radius")
                                    value: card.e?.badgeRadiusTL ?? 16
                                    from: 0
                                    to: 200
                                    stepSize: 1
                                    onValueChanged: {
                                        card.pendingRadiusKey = "badgeRadiusTL"
                                        radiusTimer.restart()
                                    }
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    visible: !(card.e?.badgeSameRadius ?? true)
                                    Layout.preferredHeight: visible ? implicitHeight : 0
                                    spacing: 8
                                    ConfigSpinBox {
                                        id: radiusTL
                                        Layout.fillWidth: true
                                        icon: "crop_5_4"
                                        text: Translation.tr("Top-left")
                                        value: card.e?.badgeRadiusTL ?? 16
                                        from: 0
                                        to: 200
                                        stepSize: 1
                                        onValueChanged: {
                                            card.pendingRadiusKey = "badgeRadiusTL"
                                            radiusTimer.restart()
                                        }
                                    }
                                    ConfigSpinBox {
                                        id: radiusTR
                                        Layout.fillWidth: true
                                        icon: "crop_16_9"
                                        text: Translation.tr("Top-right")
                                        value: card.e?.badgeRadiusTR ?? 16
                                        from: 0
                                        to: 200
                                        stepSize: 1
                                        onValueChanged: {
                                            card.pendingRadiusKey = "badgeRadiusTR"
                                            radiusTimer.restart()
                                        }
                                    }
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    visible: !(card.e?.badgeSameRadius ?? true)
                                    Layout.preferredHeight: visible ? implicitHeight : 0
                                    spacing: 8
                                    ConfigSpinBox {
                                        id: radiusBL
                                        Layout.fillWidth: true
                                        icon: "crop_5_4"
                                        text: Translation.tr("Bottom-left")
                                        value: card.e?.badgeRadiusBL ?? 16
                                        from: 0
                                        to: 200
                                        stepSize: 1
                                        onValueChanged: {
                                            card.pendingRadiusKey = "badgeRadiusBL"
                                            radiusTimer.restart()
                                        }
                                    }
                                    ConfigSpinBox {
                                        id: radiusBR
                                        Layout.fillWidth: true
                                        icon: "crop_16_9"
                                        text: Translation.tr("Bottom-right")
                                        value: card.e?.badgeRadiusBR ?? 16
                                        from: 0
                                        to: 200
                                        stepSize: 1
                                        onValueChanged: {
                                            card.pendingRadiusKey = "badgeRadiusBR"
                                            radiusTimer.restart()
                                        }
                                    }
                                }

                                Timer {
                                    id: radiusTimer
                                    interval: 300
                                    repeat: false
                                    // When "same radius" is ON the single Corner radius
                                    // field IS the value for every corner, so the
                                    // commit must write all four corners together.
                                    onTriggered: {
                                        const key = card.pendingRadiusKey || "badgeRadiusTL"
                                        const spin = key === "badgeRadiusTL" ? radiusSettingSlider
                                            : key === "badgeRadiusTR" ? radiusTR
                                            : key === "badgeRadiusBL" ? radiusBL : radiusBR
                                        const v = spin.value
                                        if (card.e?.badgeSameRadius ?? true) {
                                            root.setFields(card.modelData, {
                                                badgeRadiusTL: v,
                                                badgeRadiusTR: v,
                                                badgeRadiusBR: v,
                                                badgeRadiusBL: v
                                            })
                                        } else {
                                            root.setField(card.modelData, key, v)
                                        }
                                    }
                                }

                                ConfigSwitch {
                                    buttonIcon: "padding"
                                    text: Translation.tr("Same padding on all sides")
                                    checked: card.e?.badgeSamePadding ?? true
                                    onCheckedChanged: {
                                        const p = card.e?.badgePaddingTop ?? 8
                                        if (checked) {
                                            root.setFields(card.modelData, {
                                                badgeSamePadding: checked,
                                                badgePaddingRight: p,
                                                badgePaddingBottom: p,
                                                badgePaddingLeft: p
                                            })
                                        } else {
                                            root.setField(card.modelData, "badgeSamePadding", checked)
                                        }
                                    }
                                }

                                ConfigSpinBox {
                                    id: paddingSettingSpin
                                    Layout.fillWidth: true
                                    visible: card.e?.badgeSamePadding ?? true
                                    Layout.preferredHeight: visible ? implicitHeight : 0
                                    icon: "padding"
                                    text: Translation.tr("Padding")
                                    value: card.e?.badgePaddingTop ?? 8
                                    from: 0
                                    to: 100
                                    stepSize: 1
                                    onValueChanged: {
                                        card.pendingPadKey = "badgePaddingTop"
                                        paddingTimer.restart()
                                    }
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    visible: !(card.e?.badgeSamePadding ?? true)
                                    Layout.preferredHeight: visible ? implicitHeight : 0
                                    spacing: 8
                                    ConfigSpinBox {
                                        id: padTop
                                        Layout.fillWidth: true
                                        icon: "arrow_upward"
                                        text: Translation.tr("Top")
                                        value: card.e?.badgePaddingTop ?? 8
                                        from: 0
                                        to: 100
                                        stepSize: 1
                                        onValueChanged: {
                                            card.pendingPadKey = "badgePaddingTop"
                                            paddingTimer.restart()
                                        }
                                    }
                                    ConfigSpinBox {
                                        id: padRight
                                        Layout.fillWidth: true
                                        icon: "arrow_forward"
                                        text: Translation.tr("Right")
                                        value: card.e?.badgePaddingRight ?? 12
                                        from: 0
                                        to: 100
                                        stepSize: 1
                                        onValueChanged: {
                                            card.pendingPadKey = "badgePaddingRight"
                                            paddingTimer.restart()
                                        }
                                    }
                                }
                                RowLayout {
                                    Layout.fillWidth: true
                                    visible: !(card.e?.badgeSamePadding ?? true)
                                    Layout.preferredHeight: visible ? implicitHeight : 0
                                    spacing: 8
                                    ConfigSpinBox {
                                        id: padBottom
                                        Layout.fillWidth: true
                                        icon: "arrow_downward"
                                        text: Translation.tr("Bottom")
                                        value: card.e?.badgePaddingBottom ?? 8
                                        from: 0
                                        to: 100
                                        stepSize: 1
                                        onValueChanged: {
                                            card.pendingPadKey = "badgePaddingBottom"
                                            paddingTimer.restart()
                                        }
                                    }
                                    ConfigSpinBox {
                                        id: padLeft
                                        Layout.fillWidth: true
                                        icon: "arrow_back"
                                        text: Translation.tr("Left")
                                        value: card.e?.badgePaddingLeft ?? 12
                                        from: 0
                                        to: 100
                                        stepSize: 1
                                        onValueChanged: {
                                            card.pendingPadKey = "badgePaddingLeft"
                                            paddingTimer.restart()
                                        }
                                    }
                                }

                                Timer {
                                    id: paddingTimer
                                    interval: 300
                                    repeat: false
                                    onTriggered: {
                                        const key = card.pendingPadKey || "badgePaddingTop"
                                        const spin = key === "badgePaddingTop" ? paddingSettingSpin
                                            : key === "badgePaddingRight" ? padRight
                                            : key === "badgePaddingBottom" ? padBottom : padLeft
                                        const v = spin.value
                                        if (card.e?.badgeSamePadding ?? true) {
                                            root.setFields(card.modelData, {
                                                badgePaddingTop: v,
                                                badgePaddingRight: v,
                                                badgePaddingBottom: v,
                                                badgePaddingLeft: v
                                            })
                                        } else {
                                            root.setField(card.modelData, key, v)
                                        }
                                    }
                                }
                            }

                            // ── Advanced ──────────────────────────────
            ConfigSlider {
                id: textOpacitySlider
                text: Translation.tr("Text opacity")
                buttonIcon: "opacity"
                from: 0.0
                to: 1.0
                stepSize: 0.05
                value: card.e?.opacity ?? 1.0
                onValueChanged: textOpacityTimer.restart()
                Timer {
                    id: textOpacityTimer
                    interval: 200
                    repeat: false
                    onTriggered: root.setField(card.modelData, "opacity", Math.round(textOpacitySlider.value * 100) / 100)
                }
            }

            ConfigSlider {
                id: badgeBgOpacitySlider
                text: Translation.tr("Badge background opacity")
                buttonIcon: "opacity"
                from: 0.0
                to: 1.0
                stepSize: 0.05
                value: card.e?.badgeBackgroundOpacity ?? 1.0
                onValueChanged: badgeBgOpacityTimer.restart()
                Timer {
                    id: badgeBgOpacityTimer
                    interval: 200
                    repeat: false
                    onTriggered: root.setField(card.modelData, "badgeBackgroundOpacity", Math.round(badgeBgOpacitySlider.value * 100) / 100)
                }
            }

            ConfigSwitch {
                buttonIcon: "blur_on"
                text: Translation.tr("Backdrop filter")
                checked: card.e?.badgeBackdropEnabled ?? false
                onCheckedChanged: root.setField(card.modelData, "badgeBackdropEnabled", checked)
            }

            ConfigSlider {
                id: badgeBackdropBlurSlider
                text: Translation.tr("Backdrop blur")
                buttonIcon: "blur_on"
                from: 0
                to: 40
                stepSize: 1
                usePercentTooltip: false
                value: card.e?.badgeBackdropBlur ?? 0
                onValueChanged: badgeBackdropBlurTimer.restart()
                Timer {
                    id: badgeBackdropBlurTimer
                    interval: 200
                    repeat: false
                    onTriggered: root.setField(card.modelData, "badgeBackdropBlur", Math.round(badgeBackdropBlurSlider.value))
                }
            }

            ConfigSlider {
                id: badgeBackdropTintSlider
                text: Translation.tr("Backdrop tint")
                buttonIcon: "opacity"
                from: 0.0
                to: 1.0
                stepSize: 0.05
                value: card.e?.badgeBackdropTint ?? 0.55
                onValueChanged: badgeBackdropTintTimer.restart()
                Timer {
                    id: badgeBackdropTintTimer
                    interval: 200
                    repeat: false
                    onTriggered: root.setField(card.modelData, "badgeBackdropTint", Math.round(badgeBackdropTintSlider.value * 100) / 100)
                }
            }

            ConfigSlider {
                                id: lineHeightSlider
                                text: Translation.tr("Line height")
                                buttonIcon: "format_line_spacing"
                                from: 0.5
                                to: 3.0
                                stepSize: 0.05
                                value: card.e?.lineHeight ?? 1.0
                                onValueChanged: lineHeightTimer.restart()
                                Timer {
                                    id: lineHeightTimer
                                    interval: 200
                                    repeat: false
                                    onTriggered: root.setField(card.modelData, "lineHeight", Math.round(lineHeightSlider.value * 100) / 100)
                                }
                            }

                            ConfigSlider {
                                id: rotationSlider
                                text: Translation.tr("Rotation")
                                buttonIcon: "rotate_right"
                                from: -180
                                to: 180
                                stepSize: 1
                                usePercentTooltip: false
                                value: card.e?.rotation ?? 0
                                onValueChanged: rotationTimer.restart()
                                Timer {
                                    id: rotationTimer
                                    interval: 200
                                    repeat: false
                                    onTriggered: root.setField(card.modelData, "rotation", Math.round(rotationSlider.value))
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}