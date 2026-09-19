pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Qt5Compat.GraphicalEffects

// A 10-band live equalizer. Talks to EasyEffects through scripts/eq/equalizer.sh
// (all of that plumbing - refresh/setBand/saveChanges/applyPreset/eqGetProc -
// is unchanged from before, only the UI built on top of it is new).
//
// The layout is split the way a lot of Material 3 Expressive surfaces are:
// a ratio-sized rail on the left carrying the "who/what" (now playing +
// presets, ~34% of the body width), and an open area on the right - roughly
// two thirds of the popup - that is the actual instrument: 10 horizontal
// StyledSliders in a 2-column stack. Both sides sit in matched Panel
// containers (see the Panel component below) so they read as one
// consistent pair of cards rather than a bordered rail beside bare content.
//
// Each band is a real StyledSlider (the same slider component the seek bar
// below uses, and the one the old vertical version rotated -90deg to stand
// upright) - kept flat/horizontal here instead, since that's the layout
// that's staying. Frequency label on the left, live dB readout on the
// right, native slider fill/handle/tooltip in between. Color is put to
// work too: each slider's hue drifts from the tinted primary (bass) to the
// tinted secondary (treble) so the whole cluster reads as one continuous
// gradient instead of ten identical bars.
Item {
    id: root

    // Passed in by EqualizerPopup.qml - a scheme tinted off the currently
    // playing track's art (or plain Appearance.colors as a standalone fallback).
    property QtObject blendedColors: Appearance.colors
    // Optional - only present when something is actually playing. Everything
    // below reads through "?." so a null player just hides the transport row.
    property MprisPlayer player: null
    property string displayedArtFilePath: ""
    signal closeRequested()

    // b1..b10 gains in dB, mirrors eq_state.json written by equalizer.sh
    property var bands: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    property string presetName: "Flat"
    // Which named custom preset (if any) the CURRENT editing session
    // started from - separate from presetName, which flips to generic
    // "Custom" the instant you touch a slider (see setBand()). Lets the
    // Save rail offer a one-tap "Update '<name>'" that writes back into
    // that same custom-preset entry, instead of only ever being able to
    // commit into whichever EasyEffects preset happens to be active. Set
    // in applyCustomPreset(), cleared in applyPreset() (switching to a
    // built-in curve), and naturally resets to "" on next popup open
    // either way since this whole Item gets recreated then.
    property string editingCustomPresetName: ""
    property bool pending: false
    readonly property var bandLabels: ["32", "63", "125", "250", "500", "1k", "2k", "4k", "8k", "16k"]
    readonly property real bandRange: 12 // -12dB .. +12dB, matches equalizer.sh clamp expectations
    // Master gain on top of the 10 bands (maps to the equalizer block's
    // own output-gain) - independent of preset/curve, so it survives
    // switching presets rather than resetting with them.
    property real preamp: 0
    readonly property real preampRange: 12

    // Dims the blurred album-art background behind the popup (see the
    // scrim Rectangle in EqualizerPopup.qml) - bright/high-contrast covers
    // can otherwise flash-bang the user when the popup opens. Persisted to
    // eq_state.json via set_dim, same as preamp, but never sets
    // root.pending - it's a UI/background setting, not something
    // EasyEffects needs to apply.
    property real dimAmount: 0.3
    readonly property real dimAmountMax: 0.85
    // Collapsed to just the icon until tapped, so it doesn't permanently
    // eat header space for a control most sessions won't touch.
    property bool dimExpanded: false

    // Three-tier spacing system shared across the whole popup, so every
    // panel reads as one consistent layout instead of each picking its own
    // one-off numbers. itemSpacing is the tight gap between repeated
    // same-kind controls (slider rows, preset chips); sectionSpacing is the
    // looser gap between distinct groups within a panel (Now Playing vs
    // Presets vs Custom, or the band grid vs the preamp row); pageSpacing
    // (below) is looser still, for the gaps between top-level regions.
    readonly property int itemSpacing: 6
    readonly property int sectionSpacing: 10
    // Loosest tier of the spacing system - between top-level regions
    // (header, hint banners, the panel row) rather than between groups
    // within a single panel. Named so the header/body rhythm and the
    // in-panel rhythm can be tuned independently instead of sharing one
    // magic number.
    readonly property int pageSpacing: 16

    // Shared container system for every major panel (the rail, the band
    // cluster) - same radius, same padding, same surface tint - so the
    // popup reads as one consistent set of cards instead of each side
    // picking its own numbers. Anything wrapped in the Panel component
    // below automatically follows this.
    readonly property int panelRadius: Appearance.rounding.normal
    readonly property int panelPadding: 16
    readonly property color panelColor: ColorUtils.transparentize(root.blendedColors.colLayer1, 0.55)
    readonly property color panelBorderColor: ColorUtils.transparentize(root.blendedColors.colSubtext, 0.88)

    // Mirrors equalizer.sh's save_preset() calls exactly, so tapping a
    // preset chip moves the blobs immediately instead of waiting on a
    // shell round-trip to read the state file back.
    readonly property var presetValues: ({
        "Flat":    [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        "Bass":    [5, 7, 5, 2, 1, 0, 0, 0, 1, 2],
        "Treble":  [-2, -1, 0, 1, 2, 3, 4, 5, 6, 6],
        "Vocal":   [-2, -1, 1, 3, 5, 5, 4, 2, 1, 0],
        "Pop":     [2, 4, 2, 0, 1, 2, 4, 2, 1, 2],
        "Rock":    [5, 4, 2, -1, -2, -1, 2, 4, 5, 6],
        "Jazz":    [3, 3, 1, 1, 1, 1, 2, 1, 2, 3],
        "Classic": [0, 1, 2, 2, 2, 2, 1, 2, 3, 4]
    })
    readonly property var presetIcons: ({
        "Flat": "horizontal_rule", "Bass": "graphic_eq", "Treble": "trending_up",
        "Vocal": "mic", "Pop": "star", "Rock": "bolt", "Jazz": "piano", "Classic": "music_note"
    })

    // Auto EQ (genre-follow) now lives in EqualizerAutoService so it keeps
    // running whether or not this view/popup is open - see that file for
    // why. root.autoEnabled below just mirrors the service's state for
    // display; toggleAuto()/maybeLookupGenre() below delegate to it too.
    readonly property bool autoEnabled: EqualizerAutoService.autoEnabled

    // Mirrors equalizer.sh's custom preset store (get_custom/save_custom/
    // delete_custom) - already implemented backend-side, just not exposed
    // in the UI before.
    property string lastfmKey: ""
    property bool showLastfmKeyDialog: false
    property bool lastfmKeyRevealed: false
    // Set when equalizer.sh refused to touch a preset that's never been
    // explicitly saved in EasyEffects (see get_needs_save) - applying an
    // EQ change in that state would otherwise silently wipe any live,
    // unsaved effects (Crystalizer, compressor, etc.) you have running.
    property bool needsManualSave: false
    // name -> [b1..b10], kept in sync with custom_presets.json
    property var customPresets: ({})
    property bool showSaveDialog: false
    // Set right when the "+" reveals the save row, and cleared once
    // railFlick.contentHeight actually changes as a result (handled where
    // contentHeight is bound, below - see the comment there for why this
    // can't just be a Qt.callLater() guess).
    property bool pendingSaveRowScroll: false
    onShowSaveDialogChanged: {
        if (root.showSaveDialog) {
            newPresetNameField.text = ""
            newPresetNameField.forceActiveFocus()
            // Tapping "+" can happen while scrolled up toward Now Playing/
            // EasyEffects preset, which would otherwise leave the newly
            // revealed name field below the fold. Jump railFlick down to
            // the Custom section instead of expecting a manual scroll.
            // Just arm the flag here - the actual scroll happens in
            // railFlick's onContentHeightChanged once the save row's
            // reveal has actually resized railColumn (see there for why a
            // Qt.callLater guess here is the wrong tool: if there's
            // already overflow from existing custom presets,
            // contentHeight is already bigger than height *before* the
            // row appears, so an immediate check here would scroll to the
            // stale bottom and clear the flag before the real resize from
            // the new row ever happens).
            root.pendingSaveRowScroll = true
        } else {
            newPresetNameField.focus = false
            root.pendingSaveRowScroll = false
        }
    }
    // Toggles preset chips between "tap to apply" and "tap to delete".
    property bool customEditMode: false

    // Which EasyEffects preset (i.e. effect chain - compressor, limiter,
    // deesser, etc) the equalizer curve gets merged into. Was previously
    // hardcoded to a guess ("output") with no way to change it from here -
    // see equalizer.sh's ACTIVE_PRESET_FILE comment for why that guess is
    // very likely wrong for any given user.
    property string activePreset: "output"
    property var availablePresets: []
    property bool showActivePresetDialog: false
    // Set instead of switching immediately when the typed/tapped name
    // isn't one of availablePresets - creating a brand-new preset force-
    // switches EasyEffects, discarding whatever's currently live and
    // unsaved, so that needs an explicit confirm rather than happening
    // the moment you finish typing.
    property string pendingNewPresetName: ""
    // Toggles the existing-presets list below between "tap to switch" and
    // "tap to delete" - same pattern as customEditMode above, just scoped
    // to real EasyEffects preset files instead of this script's own
    // custom-preset store.
    property bool activePresetEditMode: false
    // Set instead of deleting immediately when a chip is tapped in edit
    // mode - unlike the custom-preset rail (a curve you typed numbers
    // into, trivial to redo), this deletes a real EasyEffects preset file
    // that may hold hand-tuned effects with no equalizer.sh backup, so it
    // gets the same explicit-confirm treatment as pendingNewPresetName
    // above rather than deleting on the first tap.
    property string pendingDeletePresetName: ""
    onShowActivePresetDialogChanged: {
        if (root.showActivePresetDialog) {
            activePresetField.text = root.activePreset
            activePresetField.forceActiveFocus()
            root.refreshAvailablePresets()
        } else {
            activePresetField.focus = false
            root.pendingNewPresetName = ""
            root.activePresetEditMode = false
            root.pendingDeletePresetName = ""
        }
    }

    // Low bands lean tinted-primary, high bands lean tinted-secondary - a
    // cheap continuous gradient across the cluster instead of one flat color.
    function bandAccentColor(index) {
        const t = root.bandLabels.length > 1 ? index / (root.bandLabels.length - 1) : 0
        return ColorUtils.mix(root.blendedColors.colPrimary, root.blendedColors.colSecondary, t)
    }

    function refresh() {
        eqGetProc.running = false
        eqGetProc.running = true
    }

    function setBand(index, value) {
        root.bands[index] = value
        root.bandsChanged()
        root.presetName = "Custom"
        // Keep EqualizerAutoService's mirror of the active preset in sync -
        // otherwise a later genre lookup that resolves back to whatever
        // preset was active before this edit sees no change and skips
        // re-applying it, even though the real active preset is now Custom.
        EqualizerAutoService.currentPresetName = "Custom"
        root.pending = true
        Quickshell.execDetached(["bash", Directories.eqScriptPath, Directories.eqStateDir, "set_band", String(index + 1), String(Math.round(value))])
        liveApplyTimer.restart()
    }

    // Doesn't touch presetName - preamp is a master gain layered on top
    // of whichever curve is active, not part of the curve's identity, so
    // adjusting it shouldn't make the preset display flip to "Custom".
    function setPreamp(value) {
        root.preamp = value
        root.pending = true
        Quickshell.execDetached(["bash", Directories.eqScriptPath, Directories.eqStateDir, "set_preamp", String(Math.round(value))])
        liveApplyTimer.restart()
    }

    // Unlike setPreamp/setBand, doesn't touch root.pending - dim is a
    // display-only setting with nothing for EasyEffects to apply, so
    // there's no "Apply" prompt to trigger here.
    function setDim(value) {
        root.dimAmount = value
        Quickshell.execDetached(["bash", Directories.eqScriptPath, Directories.eqStateDir, "set_dim", String(value)])
    }

    // The real commit - writes into the actual active preset's own file
    // and clears the unsaved indicator. Only ever called by the user
    // explicitly hitting Save now (see the pill below) - dragging a
    // slider no longer reaches this function at all.
    function saveChanges() {
        Quickshell.execDetached(["bash", Directories.eqScriptPath, Directories.eqStateDir, "save"])
        root.pending = false
        needsSaveRecheckTimer.restart()
    }

    // Debounced live-audio preview while dragging - merges the current
    // slider state into a scratch preset and reloads THAT, so you hear
    // the change immediately without touching the real active preset's
    // file. root.pending deliberately stays true after this: it's audible
    // now, but still unsaved, and the Save pill should keep reflecting that
    // until you actually hit it.
    function previewChanges() {
        Quickshell.execDetached(["bash", Directories.eqScriptPath, Directories.eqStateDir, "preview"])
    }

    // Fires shortly after band/preamp sliders go quiet, so you hear the
    // result without needing to hit Save yourself. Restarted (not just
    // started) on every onMoved, so continuous dragging doesn't spam
    // reloads - it only actually previews once you settle on a value.
    // Deliberately not fired on every single onMoved tick: apply_eq()
    // reloads the whole EasyEffects pipeline each time, which can pop/glitch
    // audio if done many times a second while actively dragging.
    Timer {
        id: liveApplyTimer
        interval: 120
        repeat: false
        onTriggered: root.previewChanges()
    }

    function applyPreset(name) {
        // Update the blobs instantly from the known preset values...
        const vals = root.presetValues[name]
        if (vals) root.bands = vals.slice()
        root.presetName = name
        // A built-in curve, not a named custom preset - nothing for the
        // "Update" shortcut to write back into.
        root.editingCustomPresetName = ""
        // See setBand() above - keeps Auto's stale-preset check honest.
        EqualizerAutoService.currentPresetName = name
        root.pending = false
        // ...while the backend writes + loads the matching EasyEffects preset.
        Quickshell.execDetached(["bash", Directories.eqScriptPath, Directories.eqStateDir, "preset", name])
        needsSaveRecheckTimer.restart()
    }

    function refreshNeedsSave() {
        eqGetNeedsSaveProc.running = false
        eqGetNeedsSaveProc.running = true
    }

    function refreshLastfmKey() {
        eqGetLastfmKeyProc.running = false
        eqGetLastfmKeyProc.running = true
    }

    function saveLastfmKey(key) {
        const trimmed = key.trim()
        root.lastfmKey = trimmed
        Quickshell.execDetached(["bash", Directories.eqScriptPath, Directories.eqStateDir, "set_lastfm_key", trimmed])
        root.showLastfmKeyDialog = false
        // A key just got set (or cleared) - re-run the current song's
        // lookup instead of waiting for the next track change.
        EqualizerAutoService.lastLookupKey = ""
        EqualizerAutoService.maybeLookupGenre()
    }

    function toggleAuto() {
        const goingOn = !EqualizerAutoService.autoEnabled
        EqualizerAutoService.toggleAuto()
        // Auto can't do anything without a key to look genres up with -
        // open the paste field right away instead of letting it silently
        // no-op every track change.
        if (goingOn && root.lastfmKey.length === 0) root.showLastfmKeyDialog = true
    }

    function refreshCustomPresets() {
        eqGetCustomProc.running = false
        eqGetCustomProc.running = true
    }

    // Same instant-update-then-backend-catches-up pattern as applyPreset(),
    // just routed at "preset" NAME, which equalizer.sh falls through to
    // apply_custom_preset() for anything that isn't one of the 8 built-ins.
    function applyCustomPreset(name) {
        const vals = root.customPresets[name]
        if (vals) root.bands = vals.slice()
        root.presetName = name
        // This IS a named custom preset - remember it so the Save rail can
        // offer "Update '<name>'" if you go on to edit it.
        root.editingCustomPresetName = name
        // See setBand() above - keeps Auto's stale-preset check honest.
        EqualizerAutoService.currentPresetName = name
        root.pending = false
        Quickshell.execDetached(["bash", Directories.eqScriptPath, Directories.eqStateDir, "preset", name])
        needsSaveRecheckTimer.restart()
    }

    function saveCustomPreset(name) {
        const trimmed = name.trim()
        if (!trimmed) return
        const args = ["bash", Directories.eqScriptPath, Directories.eqStateDir, "save_custom", trimmed]
        for (const v of root.bands) args.push(String(Math.round(v)))
        Quickshell.execDetached(args)
        const updated = Object.assign({}, root.customPresets)
        updated[trimmed] = root.bands.slice()
        root.customPresets = updated
        root.presetName = trimmed
        // Whether this came from the "Update '<name>'" shortcut or typing
        // a fresh name into "save as", that name is now what you're
        // editing - and save_custom already committed everything (state
        // file + the real active EasyEffects preset) via apply_eq on the
        // backend side, so there's nothing left unsaved.
        root.editingCustomPresetName = trimmed
        root.pending = false
        // See setBand() above - keeps Auto's stale-preset check honest.
        EqualizerAutoService.currentPresetName = trimmed
        root.showSaveDialog = false
        needsSaveRecheckTimer.restart()
    }

    function deleteCustomPreset(name) {
        Quickshell.execDetached(["bash", Directories.eqScriptPath, Directories.eqStateDir, "delete_custom", name])
        const updated = Object.assign({}, root.customPresets)
        delete updated[name]
        root.customPresets = updated
        if (root.presetName === name) {
            root.presetName = "Custom"
            root.editingCustomPresetName = ""
            // See setBand() above - keeps Auto's stale-preset check honest.
            EqualizerAutoService.currentPresetName = "Custom"
        }
    }

    function refreshActivePreset() {
        eqGetActivePresetProc.running = false
        eqGetActivePresetProc.running = true
    }

    function refreshAvailablePresets() {
        eqListPresetsProc.running = false
        eqListPresetsProc.running = true
    }

    function setActivePreset(name) {
        const trimmed = name.trim()
        if (!trimmed) return
        if (root.availablePresets.indexOf(trimmed) === -1) {
            // Not a preset that exists yet - creating one force-switches
            // EasyEffects and would discard whatever's currently live and
            // unsaved, so confirm first instead of just doing it.
            root.pendingNewPresetName = trimmed
            return
        }
        root.activePreset = trimmed
        root.showActivePresetDialog = false
        root.pendingNewPresetName = ""
        // The backend re-runs apply_eq() itself as part of set_active_preset
        // (see equalizer.sh), which may find this preset was never manually
        // saved in EasyEffects either - recheck rather than assume it's fine.
        Quickshell.execDetached(["bash", Directories.eqScriptPath, Directories.eqStateDir, "set_active_preset", trimmed])
        needsSaveRecheckTimer.restart()
        root.refreshAvailablePresets()
    }

    function createActivePreset(name) {
        const trimmed = name.trim()
        if (!trimmed) return
        root.activePreset = trimmed
        root.showActivePresetDialog = false
        root.pendingNewPresetName = ""
        Quickshell.execDetached(["bash", Directories.eqScriptPath, Directories.eqStateDir, "create_preset", trimmed])
        needsSaveRecheckTimer.restart()
        root.refreshAvailablePresets()
    }

    // First tap on a chip in edit mode - arms the confirm banner below
    // instead of deleting right away. See pendingDeletePresetName above
    // for why this needs an explicit second step.
    function requestDeleteEasyEffectsPreset(name) {
        if (name === root.activePreset) return
        root.pendingDeletePresetName = name
    }

    // The actual delete, only ever reached via the confirm banner's own
    // "Delete" button. Distinct from deleteCustomPreset above, which only
    // ever touches this script's own saved-curve store, never a real
    // EasyEffects preset file on disk.
    function deleteEasyEffectsPreset(name) {
        if (name === root.activePreset) return
        Quickshell.execDetached(["bash", Directories.eqScriptPath, Directories.eqStateDir, "delete_preset", name])
        root.availablePresets = root.availablePresets.filter(p => p !== name)
        root.pendingDeletePresetName = ""
    }

    // A short one-shot delay before polling get_needs_save after any
    // action that runs apply_eq() on the backend (execDetached is
    // fire-and-forget, so there's no direct completion signal to hook -
    // this just gives the detached bash process a moment to finish its
    // file write before we ask about the result).
    Timer {
        id: needsSaveRecheckTimer
        interval: 350
        onTriggered: root.refreshNeedsSave()
    }

    // EqualizerAutoService runs in the background independent of this view,
    // so a genre-triggered preset switch can happen while the popup is
    // already open (or was open before the track changed). Without this,
    // the sliders/preset chip only ever reflected whatever was on disk at
    // Component.onCompleted - i.e. Auto looked like it "worked" only if you
    // closed and reopened the popup. Mirror the service's applied preset
    // straight into the view's own display, the same way applyPreset()
    // already does for a manual tap - all of Auto's targets (Rock, Classic,
    // Jazz, Bass, Vocal, Pop) are built-ins with known values, so no disk
    // read (and no race with the backend's own async write) is needed.
    Connections {
        target: EqualizerAutoService
        function onCurrentPresetNameChanged() {
            const name = EqualizerAutoService.currentPresetName
            const vals = root.presetValues[name]
            if (vals) {
                root.bands = vals.slice()
                root.presetName = name
                root.pending = false
                needsSaveRecheckTimer.restart()
            }
        }
    }

    Component.onCompleted: {
        root.refresh()
        root.refreshLastfmKey()
        root.refreshCustomPresets()
        root.refreshNeedsSave()
        root.refreshActivePreset()
        // Needed up front (not just when the picker's opened) so the
        // needsManualSave banner below can tell "you have presets, just
        // pick one" apart from "you don't have any yet, make one."
        root.refreshAvailablePresets()
    }

    // MPRIS doesn't push continuous position updates on its own - most
    // players only actually notify every few seconds. Forcing
    // positionChanged() on a fast cadence while playing re-evaluates the
    // seek slider's value binding often enough for it to crawl smoothly
    // instead of jumping every few seconds.
    Timer {
        running: root.player?.playbackState == MprisPlaybackState.Playing
        interval: Config.options.resources.updateInterval
        repeat: true
        onTriggered: root.player.positionChanged()
    }

    // Collapses the dim slider back to its icon whenever the popup closes -
    // whether via the header close button or the click-outside/Escape
    // dismiss path in EqualizerPopup.qml, which only ever flips
    // GlobalStates.equalizerOpen and never calls closeRequested. Watching
    // the shared state here is what catches that second path too.
    Connections {
        target: GlobalStates
        function onEqualizerOpenChanged() {
            if (!GlobalStates.equalizerOpen) {
                root.dimExpanded = false
                // Closing without an explicit Save should discard whatever's
                // been previewing, not commit it - that's the whole point of
                // splitting preview from Save (see setBand/setPreamp above).
                // Stop any debounce still waiting to fire (no point previewing
                // a value we're about to throw away) and tell the backend to
                // revert: pulls the sliders' next-open values back out of the
                // real saved preset and reloads that live, discarding the
                // scratch preview - see revert_preview() in equalizer.sh.
                if (root.pending) {
                    liveApplyTimer.stop()
                    Quickshell.execDetached(["bash", Directories.eqScriptPath, Directories.eqStateDir, "revert_preview"])
                }
            }
        }
    }

    Process {
        id: eqGetProc
        command: ["bash", Directories.eqScriptPath, Directories.eqStateDir, "get"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text)
                    root.bands = [
                    Number(data.b1), Number(data.b2), Number(data.b3), Number(data.b4), Number(data.b5),
                    Number(data.b6), Number(data.b7), Number(data.b8), Number(data.b9), Number(data.b10)
                    ]
                    root.presetName = data.preset ?? "Custom"
                    // Reopening the popup recreates this whole Item, so
                    // editingCustomPresetName always starts blank - if the
                    // preset that was active when you last closed happens
                    // to be one of your named custom presets, restore the
                    // tracking so "Update '<name>'" can show without you
                    // having to re-click it in the list first. customPresets
                    // may not have loaded yet (separate async request) -
                    // the matching check in eqGetCustomProc below covers
                    // that ordering too.
                    if (Object.prototype.hasOwnProperty.call(root.customPresets, root.presetName))
                        root.editingCustomPresetName = root.presetName
                    // Safety net alongside the explicit syncs in setBand()/
                    // applyPreset()/etc. - if anything else ever writes the
                    // state file, Auto's mirror still gets corrected here.
                    EqualizerAutoService.currentPresetName = root.presetName
                    root.pending = !!data.pending
                    root.preamp = Number(data.preamp) || 0
                    // Only pick up a value once it's actually a number - an
                    // absent/null .dim (e.g. an eq_state.json from before
                    // this feature existed) should keep whatever's already
                    // showing rather than snapping to a false "0" dim.
                    if (data.dim !== undefined && data.dim !== null && !isNaN(Number(data.dim)))
                        root.dimAmount = Number(data.dim)
                } catch (e) {
                    // Leave previous values if the state file isn't ready yet
                }
            }
        }
    }

    Process {
        id: eqGetLastfmKeyProc
        command: ["bash", Directories.eqScriptPath, Directories.eqStateDir, "get_lastfm_key"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.lastfmKey = text.trim()
            }
        }
    }

    Process {
        id: eqGetNeedsSaveProc
        command: ["bash", Directories.eqScriptPath, Directories.eqStateDir, "get_needs_save"]
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim()
                root.needsManualSave = (t === "true" || t === "1")
            }
        }
    }

    Process {
        id: eqGetCustomProc
        command: ["bash", Directories.eqScriptPath, Directories.eqStateDir, "get_custom"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(text)
                    const parsed = {}
                    for (const name in data) {
                        const b = data[name]
                        parsed[name] = [b.b1, b.b2, b.b3, b.b4, b.b5, b.b6, b.b7, b.b8, b.b9, b.b10].map(Number)
                    }
                    root.customPresets = parsed
                    // See the matching comment in eqGetProc above - covers
                    // the case where this request finishes AFTER the state
                    // load already set presetName.
                    if (Object.prototype.hasOwnProperty.call(parsed, root.presetName))
                        root.editingCustomPresetName = root.presetName
                } catch (e) {
                    // Leave previous values if custom_presets.json isn't ready yet
                }
            }
        }
    }

    Process {
        id: eqGetActivePresetProc
        command: ["bash", Directories.eqScriptPath, Directories.eqStateDir, "get_active_preset"]
        stdout: StdioCollector {
            onStreamFinished: {
                const trimmed = text.trim()
                root.activePreset = trimmed.length > 0 ? trimmed : "output"
            }
        }
    }

    Process {
        id: eqListPresetsProc
        command: ["bash", Directories.eqScriptPath, Directories.eqStateDir, "list_presets"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.availablePresets = JSON.parse(text)
                } catch (e) {
                    root.availablePresets = []
                }
            }
        }
    }

    // A fully-rounded, translucent chip - used for the header's icon
    // buttons and the rail's preset list. colLayer1Hover/Active aren't part
    // of the blended (art-tinted) color set, so the hover/active tones are
    // derived locally the same way Appearance.colors itself derives them.
    component PillChip: RippleButton {
        id: chip
        property bool chipToggled: false
        buttonRadius: Appearance.rounding.full
        colBackground: ColorUtils.transparentize(root.blendedColors.colLayer1, chipToggled ? 1 : 0.35)
        colBackgroundHover: ColorUtils.mix(root.blendedColors.colLayer1, root.blendedColors.colOnLayer1, 0.92)
        colBackgroundToggled: root.blendedColors.colPrimary
        colBackgroundToggledHover: root.blendedColors.colPrimaryHover
        colRipple: ColorUtils.mix(root.blendedColors.colLayer1, root.blendedColors.colOnLayer1, 0.85)
        colRippleToggled: root.blendedColors.colPrimaryActive
        toggled: chipToggled
    }

    // Compact transport icon button for the rail's prev/next controls.
    component TransportButton: RippleButton {
        implicitWidth: 24
        implicitHeight: 24
        property var iconName
        colBackground: ColorUtils.transparentize(root.blendedColors.colSecondaryContainer, 1)
        colBackgroundHover: root.blendedColors.colSecondaryContainerHover
        colRipple: root.blendedColors.colSecondaryContainerActive
        contentItem: MaterialSymbol {
            iconSize: Appearance.font.pixelSize.huge
            fill: 1
            horizontalAlignment: Text.AlignHCenter
            color: root.blendedColors.colOnSecondaryContainer
            text: iconName
            Behavior on color {
                animation: Appearance.animation.elementMoveFast.colorAnimation.createObject(this)
            }
        }
    }

    // The one container every major panel is built from - same radius,
    // padding, tint and border everywhere (see panelRadius/panelPadding/
    // panelColor/panelBorderColor above) so the rail and the band cluster
    // read as the same kind of surface instead of two one-off rectangles.
    // Fixed-size by design: panels get their height from the layout around
    // them (Layout.fillHeight in bodyRow), never from their own content, so
    // opening a dialog or saving a tenth custom preset scrolls inside the
    // panel instead of resizing it.
    component Panel: Rectangle {
        radius: root.panelRadius
        color: root.panelColor
        border.width: 1
        border.color: root.panelBorderColor

        // root.panelColor/panelBorderColor derive from root.blendedColors,
        // which settles onto new album art in place rather than ever being
        // swapped for a new object - see the curve graph's colorSignature
        // fix. Both panels retint here too, so they ease into it right
        // along with the graph instead of hard-cutting.
        Behavior on color {
            ColorAnimation { duration: 420; easing.type: Easing.OutCubic }
        }
        Behavior on border.color {
            ColorAnimation { duration: 420; easing.type: Easing.OutCubic }
        }
    }

    // A section label in the same style everywhere it's used ("Presets",
    // "Custom", "Bands") - one place to keep those consistent instead of
    // re-typing the font size/weight/color on every StyledText.
    component PanelHeader: StyledText {
        Layout.fillWidth: true
        font.pixelSize: Appearance.font.pixelSize.small
        font.bold: true
        color: root.blendedColors.colSubtext
    }

    // One band, built on the shell's own StyledSlider - the same real
    // slider component the old vertical version used (there just rotated
    // -90deg to stand upright). Kept flat/horizontal here since that's the
    // layout that's staying: frequency label on the left, the slider filling
    // the middle, live dB readout on the right.
    component BandCell: RowLayout {
        id: cell
        required property int index
        spacing: root.itemSpacing

        readonly property color accent: root.bandAccentColor(cell.index)

        StyledText {
            Layout.preferredWidth: 26
            font.pixelSize: Appearance.font.pixelSize.smallest
            font.features: { "tnum": 1 }
            color: root.blendedColors.colSubtext
            text: root.bandLabels[cell.index]
        }

        StyledSlider {
            id: bandSlider
            Layout.fillWidth: true
            Layout.fillHeight: true
            configuration: StyledSlider.Configuration.M
            from: -root.bandRange
            to: root.bandRange
            value: root.bands[cell.index] ?? 0
            highlightColor: cell.accent
            trackColor: ColorUtils.transparentize(cell.accent, 0.85)
            handleColor: cell.accent
            // The built-in stop-indicator dot (see StyledSlider's TrackDot)
            // defaults to marking value=1 - meaningful on a normal 0..1
            // slider, but this one's range is -bandRange..+bandRange, so
            // that default landed at a near-but-not-quite-center spot with
            // no relation to 0dB, and never moved when you dragged (it's a
            // fixed reference mark, not the handle). 0 is the actual center
            // of this range, i.e. true 0dB - and default dotColor/
            // dotColorHighlighted are also bumped for contrast, since the
            // 3px dot was easy to lose against these tinted fills.
            stopIndicatorValues: [0]
            dotColor: root.blendedColors.colOnLayer1
            dotColorHighlighted: root.blendedColors.colOnPrimary
            usePercentTooltip: false
            tooltipContent: `${Math.round(value) > 0 ? "+" : ""}${Math.round(value)} dB`
            onMoved: root.setBand(cell.index, value)

            Behavior on value {
                enabled: !bandSlider.pressed
                NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
            }
        }

        StyledText {
            Layout.preferredWidth: 28
            horizontalAlignment: Text.AlignRight
            font.pixelSize: Appearance.font.pixelSize.smallest
            font.features: { "tnum": 1 }
            color: cell.accent
            text: `${Math.round(root.bands[cell.index] ?? 0) > 0 ? "+" : ""}${Math.round(root.bands[cell.index] ?? 0)}`
        }
    }

    // Root layout for the whole popup. Fixed to the popup's own size (no
    // outer Flickable any more) - the header and hint banners take their
    // natural height, and the panel row below fills whatever's left. Each
    // panel then handles its own overflow internally (see Panel/railFlick
    // below) instead of the entire page growing and scrolling as one.
    ColumnLayout {
        id: mainColumn
        anchors.fill: parent
        anchors.margins: 22
        spacing: root.pageSpacing

        // Header - icon, title/preset, reset, close. Kept compact and
        // secondary to the panels below - this is a status/actions strip,
        // not the visual focus - so the two panels get as much height as
        // possible.
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            MaterialShapeWrappedMaterialSymbol {
                wrappedShape: MaterialShape.Shape.Cookie6Sided
                text: "equalizer"
                fill: 1
                iconSize: Appearance.font.pixelSize.large
                padding: 9
                color: ColorUtils.transparentize(root.blendedColors.colPrimary, 0.85)
                colSymbol: root.blendedColors.colPrimary
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                StyledText {
                    Layout.fillWidth: true
                    font.pixelSize: Appearance.font.pixelSize.large
                    font.bold: true
                    color: root.blendedColors.colOnLayer0
                    elide: Text.ElideRight
                    text: Translation.tr("Equalizer")
                }
                StyledText {
                    Layout.fillWidth: true
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: root.blendedColors.colSubtext
                    elide: Text.ElideRight
                    text: `${Translation.tr("Preset")}: ${root.presetName}`
                }
            }

            // Dims the blurred-art background behind the popup - bright
            // covers can otherwise flash-bang the user. Collapsed to a
            // single icon by default; tapping it expands a slider inline
            // (see dimSliderWrap below) rather than permanently taking up
            // header space.
            PillChip {
                id: dimChip
                implicitWidth: 34
                implicitHeight: 34
                chipToggled: root.dimExpanded
                downAction: () => root.dimExpanded = !root.dimExpanded
                contentItem: Item {
                    anchors.fill: parent
                    MaterialSymbol {
                        anchors.centerIn: parent
                        iconSize: Appearance.font.pixelSize.large
                        fill: root.dimExpanded ? 1 : 0
                        horizontalAlignment: Text.AlignHCenter
                        color: root.dimExpanded ? root.blendedColors.colOnPrimary : root.blendedColors.colOnLayer1
                        text: "contrast"
                    }
                }
            }

            // Expands/retracts alongside dimChip above instead of always
            // reserving space - width and opacity both animate so it reads
            // as sliding out from under the icon, not popping in.
            Item {
                id: dimSliderWrap
                Layout.preferredWidth: root.dimExpanded ? 110 : 0
                Layout.preferredHeight: 34
                clip: true
                opacity: root.dimExpanded ? 1 : 0

                Behavior on Layout.preferredWidth {
                    NumberAnimation { duration: 240; easing.type: Easing.OutCubic }
                }
                Behavior on opacity {
                    NumberAnimation { duration: root.dimExpanded ? 220 : 120; easing.type: Easing.OutCubic }
                }

                StyledSlider {
                    id: dimSlider
                    anchors.verticalCenter: parent.verticalCenter
                    width: 110
                    configuration: StyledSlider.Configuration.M
                    from: 0
                    to: root.dimAmountMax
                    value: root.dimAmount
                    highlightColor: root.blendedColors.colPrimary
                    trackColor: ColorUtils.transparentize(root.blendedColors.colPrimary, 0.85)
                    // Default stop-indicator value 1 is outside this
                    // slider's 0..dimAmountMax range entirely (harmless,
                    // just pointless) - clearing it rather than leaving an
                    // unused Repeater iteration around.
                    stopIndicatorValues: []
                    handleColor: root.blendedColors.colPrimary
                    usePercentTooltip: true
                    onMoved: root.setDim(value)

                    Behavior on value {
                        enabled: !dimSlider.pressed
                        NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
                    }
                }
            }

            PillChip {
                implicitHeight: 34
                Layout.preferredWidth: autoLabel.implicitWidth + 40
                chipToggled: root.autoEnabled
                downAction: () => root.toggleAuto()
                contentItem: Item {
                    anchors.fill: parent
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 4
                        MaterialSymbol {
                            iconSize: Appearance.font.pixelSize.smaller
                            fill: root.autoEnabled ? 1 : 0
                            text: "auto_awesome"
                            color: root.autoEnabled ? root.blendedColors.colOnPrimary : root.blendedColors.colOnLayer1
                        }
                        StyledText {
                            id: autoLabel
                            font.pixelSize: Appearance.font.pixelSize.smallest
                            text: Translation.tr("Auto")
                            color: root.autoEnabled ? root.blendedColors.colOnPrimary : root.blendedColors.colOnLayer1
                        }
                    }
                }
            }

            PillChip {
                implicitWidth: 34
                implicitHeight: 34
                chipToggled: root.showLastfmKeyDialog
                downAction: () => root.showLastfmKeyDialog = !root.showLastfmKeyDialog
                contentItem: Item {
                    anchors.fill: parent
                    MaterialSymbol {
                        anchors.centerIn: parent
                        iconSize: Appearance.font.pixelSize.large
                        // Filled key = a key is already saved; outline = not set up yet.
                        fill: root.lastfmKey.length > 0 ? 1 : 0
                        horizontalAlignment: Text.AlignHCenter
                        color: root.showLastfmKeyDialog ? root.blendedColors.colOnPrimary : root.blendedColors.colOnLayer1
                        text: "key"
                    }
                }
            }

            PillChip {
                implicitWidth: 34
                implicitHeight: 34
                downAction: () => root.applyPreset("Flat")
                contentItem: MaterialSymbol {
                    iconSize: Appearance.font.pixelSize.large
                    fill: 0
                    horizontalAlignment: Text.AlignHCenter
                    color: root.blendedColors.colOnLayer1
                    text: "refresh"
                }
            }

            PillChip {
                implicitWidth: 34
                implicitHeight: 34
                downAction: () => root.closeRequested()
                contentItem: MaterialSymbol {
                    iconSize: Appearance.font.pixelSize.large
                    fill: 1
                    horizontalAlignment: Text.AlignHCenter
                    color: root.blendedColors.colOnLayer1
                    text: "close"
                }
            }
        }
        // Nudges toward setting a key whenever Auto is on but there's
        // nothing for genre_tags to look up with - stays visible (not just
        // a one-off toast) since the underlying problem persists until a
        // key is actually saved.
        Rectangle {
            Layout.fillWidth: false
            visible: root.autoEnabled && root.lastfmKey.length === 0
            implicitWidth: lastfmHintRow.implicitWidth + 16
            implicitHeight: lastfmHintRow.implicitHeight + 16
            radius: Appearance.rounding.normal
            color: ColorUtils.transparentize(root.blendedColors.colPrimary, 0.85)

            RowLayout {
                id: lastfmHintRow
                anchors.centerIn: parent
                spacing: 6

                MaterialSymbol {
                    Layout.alignment: Qt.AlignVCenter
                    iconSize: Appearance.font.pixelSize.normal
                    fill: 0
                    text: "info"
                    color: root.blendedColors.colPrimary
                }
                StyledText {
                    id: lastfmHintText
                    Layout.alignment: Qt.AlignVCenter
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    color: root.blendedColors.colOnLayer1
                    text: Translation.tr("Auto needs a Last.fm API key to look up genres. Get one free and paste it in the key field above.")
                }
            }

            MouseArea {
                anchors.fill: parent
                onClicked: root.showLastfmKeyDialog = true
            }
        }
        // Inline "paste your Last.fm API key" row, toggled by the key chip
        // above. Pre-filled with whatever's already saved so it doubles as
        // an editor, not just a first-time setup field. Never shipped with
        // a real key baked in - each user drops their own free key
        // (https://www.last.fm/api/account/create) in here once.
        RowLayout {
            Layout.fillWidth: true
            visible: root.showLastfmKeyDialog
            spacing: 6

            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 32
                radius: Appearance.rounding.normal
                color: ColorUtils.transparentize(root.blendedColors.colLayer1, 0.35)
                border.width: lastfmKeyField.activeFocus ? 1 : 0
                border.color: root.blendedColors.colPrimary

                TextInput {
                    id: lastfmKeyField
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 34
                    verticalAlignment: TextInput.AlignVCenter
                    color: root.blendedColors.colOnLayer1
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    clip: true
                    echoMode: root.lastfmKeyRevealed ? TextInput.Normal : TextInput.Password
                    text: root.lastfmKey
                    onAccepted: root.saveLastfmKey(text)
                    Keys.onEscapePressed: { root.showLastfmKeyDialog = false }

                    StyledText {
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        visible: lastfmKeyField.text.length === 0
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        color: root.blendedColors.colSubtext
                        text: Translation.tr("Paste Last.fm API key\u2026")
                    }
                }

                MaterialSymbol {
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    iconSize: Appearance.font.pixelSize.normal
                    fill: root.lastfmKeyRevealed ? 1 : 0
                    text: root.lastfmKeyRevealed ? "visibility_off" : "visibility"
                    color: root.blendedColors.colSubtext

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.lastfmKeyRevealed = !root.lastfmKeyRevealed
                    }
                }
            }
            PillChip {
                implicitWidth: 32
                implicitHeight: 32
                chipToggled: true
                downAction: () => root.saveLastfmKey(lastfmKeyField.text)
                contentItem: MaterialSymbol {
                    iconSize: Appearance.font.pixelSize.normal
                    fill: 1
                    horizontalAlignment: Text.AlignHCenter
                    text: "check"
                    color: root.blendedColors.colOnPrimary
                }
            }
            PillChip {
                implicitWidth: 32
                implicitHeight: 32
                visible: root.lastfmKey.length > 0
                downAction: () => { lastfmKeyField.text = ""; root.saveLastfmKey("") }
                contentItem: MaterialSymbol {
                    iconSize: Appearance.font.pixelSize.normal
                    fill: 0
                    horizontalAlignment: Text.AlignHCenter
                    text: "delete"
                    color: root.blendedColors.colOnLayer1
                }
            }
        }
        // Body - a rail (now playing + presets) beside the open band
        // cluster, both built from the same Panel container so they read
        // as one consistent pair of cards. The rail is sized as a ratio of
        // the body's width rather than a fixed pixel count, so it keeps to
        // roughly a third of the popup and leaves the remaining ~65-70%
        // for the band sliders; both panels then share bodyRow's full
        // height via Layout.fillHeight, so neither one grows or shrinks
        // on its own as content changes.
        RowLayout {
            id: bodyRow
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: root.sectionSpacing

            Panel {
                id: railPanel
                Layout.fillWidth: false
                Layout.preferredWidth: Math.round(bodyRow.width * 0.34)
                Layout.fillHeight: true

                ColumnLayout {
                    id: railPanelColumn
                    anchors.fill: parent
                    anchors.margins: root.panelPadding
                    spacing: root.sectionSpacing

                    // Now playing + presets, scrolled independently of the
                    // rest of the popup - a long custom-preset list grows
                    // this list, not the panel around it (see railFlick's
                    // contentHeight below).
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Flickable {
                            id: railFlick
                            anchors.fill: parent
                            // Leaves a dedicated gutter for the scroll
                            // indicator below, so it floats in empty space
                            // instead of overlapping the rightmost few
                            // pixels of every row's content.
                            anchors.rightMargin: 10
                            clip: true
                            contentWidth: width
                            contentHeight: railColumn.implicitHeight
                            boundsBehavior: Flickable.StopAtBounds

                            // Fires every time contentHeight actually
                            // changes - including the moment the "+"
                            // button's save row finishes resizing
                            // railColumn (see pendingSaveRowScroll above).
                            // Reacting to the real change instead of
                            // guessing how many event-loop turns a
                            // Qt.callLater() needs is what makes this
                            // reliable: a fixed-delay guess can fire before
                            // the resize lands, or - if the rail was
                            // already scrollable from existing custom
                            // presets - fire "successfully" against the
                            // stale, pre-resize height and never retry.
                            onContentHeightChanged: {
                                if (!root.pendingSaveRowScroll) return
                                if (railFlick.contentHeight > railFlick.height) {
                                    railFlick.contentY = railFlick.contentHeight - railFlick.height
                                    root.pendingSaveRowScroll = false
                                }
                            }

                            ColumnLayout {
                                id: railColumn
                                width: railFlick.width
                                spacing: root.sectionSpacing

                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: root.sectionSpacing
                                    visible: root.player !== null

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 10

                                        Rectangle {
                                            id: nowPlayingArt
                                            Layout.preferredWidth: 46
                                            Layout.preferredHeight: 46
                                            color: ColorUtils.transparentize(root.blendedColors.colLayer1, 0.5)

                                            layer.enabled: true
                                            layer.effect: OpacityMask {
                                                maskSource: MaterialShape {
                                                    shape: MaterialShape.Shape.Bun
                                                    implicitSize: nowPlayingArt.width
                                                }
                                            }

                                            StyledImage {
                                                anchors.fill: parent
                                                source: root.displayedArtFilePath
                                                sourceSize.width: nowPlayingArt.width * 2
                                                sourceSize.height: nowPlayingArt.height * 2
                                                fillMode: Image.PreserveAspectCrop
                                                cache: false
                                                antialiasing: true
                                                visible: root.displayedArtFilePath.length > 0
                                            }
                                            MaterialSymbol {
                                                anchors.centerIn: parent
                                                iconSize: Appearance.font.pixelSize.huge
                                                fill: 1
                                                text: "music_note"
                                                color: root.blendedColors.colOnLayer1
                                                visible: root.displayedArtFilePath.length === 0
                                            }
                                        }

                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 2
                                            StyledText {
                                                Layout.fillWidth: true
                                                font.pixelSize: Appearance.font.pixelSize.small
                                                font.bold: true
                                                color: root.blendedColors.colOnLayer0
                                                elide: Text.ElideRight
                                                text: StringUtils.cleanMusicTitle(root.player?.trackTitle) || Translation.tr("Untitled")
                                            }
                                            StyledText {
                                                Layout.fillWidth: true
                                                font.pixelSize: Appearance.font.pixelSize.smallest
                                                color: root.blendedColors.colSubtext
                                                elide: Text.ElideRight
                                                text: root.player?.trackArtist ?? ""
                                            }
                                        }
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 4

                                        TransportButton {
                                            iconName: "skip_previous"
                                            downAction: () => root.player?.previous()
                                        }

                                        RippleButton {
                                            id: playPauseButton
                                            Layout.fillWidth: true
                                            implicitHeight: 32
                                            downAction: () => root.player?.togglePlaying()
                                            buttonRadius: (root.player?.isPlaying ?? false) ? Appearance.rounding.normal : Appearance.rounding.full
                                            colBackground: (root.player?.isPlaying ?? false) ? root.blendedColors.colPrimary : root.blendedColors.colSecondaryContainer
                                            colBackgroundHover: (root.player?.isPlaying ?? false) ? root.blendedColors.colPrimaryHover : root.blendedColors.colSecondaryContainerHover
                                            colRipple: (root.player?.isPlaying ?? false) ? root.blendedColors.colPrimaryActive : root.blendedColors.colSecondaryContainerActive
                                            contentItem: MaterialSymbol {
                                                iconSize: Appearance.font.pixelSize.large
                                                fill: 1
                                                horizontalAlignment: Text.AlignHCenter
                                                color: (root.player?.isPlaying ?? false) ? root.blendedColors.colOnPrimary : root.blendedColors.colOnSecondaryContainer
                                                text: (root.player?.isPlaying ?? false) ? "pause" : "play_arrow"
                                            }
                                        }

                                        TransportButton {
                                            iconName: "skip_next"
                                            downAction: () => root.player?.next()
                                        }
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                        implicitHeight: 16

                                        Loader {
                                            anchors.fill: parent
                                            active: root.player?.canSeek ?? false
                                            sourceComponent: StyledSlider {
                                                configuration: StyledSlider.Configuration.Wavy
                                                highlightColor: root.blendedColors.colPrimary
                                                trackColor: root.blendedColors.colSecondaryContainer
                                                handleColor: root.blendedColors.colPrimary
                                                value: (root.player?.length > 0) ? root.player.position / root.player.length : 0
                                                onPressedChanged: if (!pressed) root.player.position = value * root.player.length
                                            }
                                        }
                                        Loader {
                                            anchors.fill: parent
                                            active: !(root.player?.canSeek ?? false)
                                            sourceComponent: StyledProgressBar {
                                                wavy: root.player?.isPlaying ?? false
                                                highlightColor: root.blendedColors.colPrimary
                                                trackColor: root.blendedColors.colSecondaryContainer
                                                value: (root.player?.length > 0) ? root.player.position / root.player.length : 0
                                            }
                                        }
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        horizontalAlignment: Text.AlignRight
                                        font.pixelSize: Appearance.font.pixelSize.smallest
                                        font.features: { "tnum": 1 }
                                        color: root.blendedColors.colSubtext
                                        text: `${StringUtils.friendlyTimeForSeconds(root.player?.position)} / ${StringUtils.friendlyTimeForSeconds(root.player?.length)}`
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.topMargin: 2
                                    implicitHeight: 1
                                    color: ColorUtils.transparentize(root.blendedColors.colSubtext, 0.85)
                                }

                                // Shown when equalizer.sh detects it's never been saved to
                                // this EasyEffects preset before - applying an EQ change
                                // right now would replace your entire live pipeline with
                                // an equalizer-only one, silently dropping any other
                                // effects (Crystalizer, compressor, etc.) you've set up
                                // but not yet saved. The backend already refused to touch
                                // anything; this just tells you why nothing happened.
                                Rectangle {
                                    Layout.fillWidth: true
                                    visible: root.needsManualSave
                                    Layout.minimumHeight: implicitHeight
                                    radius: Appearance.rounding.normal
                                    color: ColorUtils.transparentize(root.blendedColors.colPrimary, 0.85)
                                    implicitHeight: warningText.implicitHeight + 16

                                    // Pops/fades in rather than snapping into
                                    // existence the instant equalizer.sh
                                    // reports needsManualSave - this can
                                    // appear right as someone's mid-drag on a
                                    // band, so a hard cut reads as a glitch.
                                    opacity: root.needsManualSave ? 1 : 0
                                    scale: root.needsManualSave ? 1 : 0.94
                                    transformOrigin: Item.Top
                                    Behavior on opacity {
                                        NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                                    }
                                    Behavior on scale {
                                        NumberAnimation { duration: 200; easing.type: Easing.OutBack }
                                    }

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.margins: 8
                                        spacing: 6

                                        MaterialSymbol {
                                            Layout.alignment: Qt.AlignTop
                                            iconSize: Appearance.font.pixelSize.normal
                                            fill: 0
                                            text: "info"
                                            color: root.blendedColors.colPrimary
                                        }
                                        StyledText {
                                            id: warningText
                                            Layout.fillWidth: true
                                            wrapMode: Text.WordWrap
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            color: root.blendedColors.colOnLayer1
                                            // Two different situations share this banner:
                                            // someone with zero EasyEffects presets at all
                                            // (a genuine first run) needs to be told to make
                                            // one, not to go "save their setup" when there's
                                            // nothing there to save yet. Someone who already
                                            // has presets just needs to pick the right one.
                                            text: root.availablePresets.length === 0
                                                ? Translation.tr("You don't have an EasyEffects preset yet. Make one below to start using this equalizer.")
                                                : Translation.tr("Pick one of your existing EasyEffects presets below, or save your current setup first (Presets tab \u2192 Save).")
                                        }
                                        PillChip {
                                            Layout.alignment: Qt.AlignVCenter
                                            implicitHeight: 26
                                            implicitWidth: choosePresetLabel.implicitWidth + 20
                                            chipToggled: true
                                            downAction: () => root.showActivePresetDialog = true
                                            contentItem: StyledText {
                                                id: choosePresetLabel
                                                horizontalAlignment: Text.AlignHCenter
                                                font.pixelSize: Appearance.font.pixelSize.smallest
                                                color: root.blendedColors.colOnPrimary
                                                text: root.availablePresets.length === 0 ? Translation.tr("Create") : Translation.tr("Choose")
                                            }
                                        }
                                    }
                                }

                                PanelHeader {
                                    text: Translation.tr("Presets")
                                }

                                // 2 columns x 4 rows so all 8 presets sit beside each other
                                // without needing to scroll (5 already fit in one column;
                                // this just gives the other 3 a partner column instead of
                                // hiding them below a Flickable).
                                GridLayout {
                                    Layout.fillWidth: true
                                    // Without this, adding custom presets grows the content
                                    // below and the ColumnLayout compresses ALL children
                                    // (including this grid) to make it fit, since nothing
                                    // was pinned to a floor size - that's what was squishing
                                    // Flat/Bass/etc. Pinning this to its own natural height
                                    // means the custom section (which already scrolls) is
                                    // the one that gives up space instead.
                                    Layout.minimumHeight: implicitHeight
                                    columns: 2
                                    columnSpacing: root.itemSpacing
                                    rowSpacing: root.itemSpacing

                                    Repeater {
                                        model: Object.keys(root.presetValues)

                                        delegate: PillChip {
                                            id: presetBtn
                                            required property string modelData
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            Layout.preferredWidth: 0
                                            chipToggled: root.presetName === modelData
                                            downAction: () => root.applyPreset(modelData)
                                            contentItem: RowLayout {
                                                spacing: 4
                                                Item { implicitWidth: 4 }
                                                MaterialSymbol {
                                                    iconSize: Appearance.font.pixelSize.normal
                                                    fill: 0
                                                    text: root.presetIcons[presetBtn.modelData] ?? "tune"
                                                    color: presetBtn.chipToggled ? root.blendedColors.colOnPrimary : root.blendedColors.colOnLayer1
                                                }
                                                StyledText {
                                                    Layout.fillWidth: true
                                                    horizontalAlignment: Text.AlignHCenter
                                                    elide: Text.ElideRight
                                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                                    text: Translation.tr(presetBtn.modelData)
                                                    color: presetBtn.chipToggled ? root.blendedColors.colOnPrimary : root.blendedColors.colOnLayer1
                                                }
                                            }
                                        }
                                    }
                                }

                                // Custom presets - save the current 10-band curve under a
                                // name via save_custom, list/apply saved ones via
                                // get_custom, remove via delete_custom. All three already
                                // existed in equalizer.sh; this is the first UI for them.
                                RowLayout {
                                    Layout.fillWidth: true
                                    Layout.minimumHeight: implicitHeight
                                    PanelHeader {
                                        text: Translation.tr("Custom")
                                    }
                                    PillChip {
                                        implicitWidth: 26
                                        implicitHeight: 26
                                        visible: Object.keys(root.customPresets).length > 0
                                        chipToggled: root.customEditMode
                                        downAction: () => root.customEditMode = !root.customEditMode
                                        contentItem: MaterialSymbol {
                                            iconSize: Appearance.font.pixelSize.normal
                                            fill: 0
                                            horizontalAlignment: Text.AlignHCenter
                                            text: root.customEditMode ? "check" : "edit"
                                            color: root.customEditMode ? root.blendedColors.colOnPrimary : root.blendedColors.colOnLayer1
                                        }
                                    }
                                    PillChip {
                                        implicitWidth: 26
                                        implicitHeight: 26
                                        downAction: () => root.showSaveDialog = !root.showSaveDialog
                                        contentItem: MaterialSymbol {
                                            iconSize: Appearance.font.pixelSize.normal
                                            fill: 0
                                            horizontalAlignment: Text.AlignHCenter
                                            text: "add"
                                            color: root.blendedColors.colOnLayer1
                                        }
                                    }
                                }

                                // Inline "save current curve as..." row, shown by the "+" above.
                                RowLayout {
                                    Layout.fillWidth: true
                                    visible: root.showSaveDialog
                                    spacing: 6

                                    opacity: root.showSaveDialog ? 1 : 0
                                    scale: root.showSaveDialog ? 1 : 0.94
                                    transformOrigin: Item.Top
                                    Behavior on opacity {
                                        NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                                    }
                                    Behavior on scale {
                                        NumberAnimation { duration: 180; easing.type: Easing.OutBack }
                                    }

                                    Rectangle {
                                        Layout.fillWidth: true
                                        implicitHeight: 32
                                        radius: Appearance.rounding.normal
                                        color: ColorUtils.transparentize(root.blendedColors.colLayer1, 0.35)
                                        border.width: newPresetNameField.activeFocus ? 1 : 0
                                        border.color: root.blendedColors.colPrimary

                                        TextInput {
                                            id: newPresetNameField
                                            anchors.fill: parent
                                            anchors.leftMargin: 10
                                            anchors.rightMargin: 10
                                            verticalAlignment: TextInput.AlignVCenter
                                            color: root.blendedColors.colOnLayer1
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            clip: true
                                            onAccepted: root.saveCustomPreset(text)
                                            Keys.onEscapePressed: { root.showSaveDialog = false }
                                        }
                                    }
                                    PillChip {
                                        implicitWidth: 32
                                        implicitHeight: 32
                                        chipToggled: true
                                        downAction: () => root.saveCustomPreset(newPresetNameField.text)
                                        contentItem: MaterialSymbol {
                                            iconSize: Appearance.font.pixelSize.normal
                                            fill: 1
                                            horizontalAlignment: Text.AlignHCenter
                                            text: "check"
                                            color: root.blendedColors.colOnPrimary
                                        }
                                    }
                                    PillChip {
                                        implicitWidth: 32
                                        implicitHeight: 32
                                        downAction: () => { root.showSaveDialog = false; newPresetNameField.text = "" }
                                        contentItem: MaterialSymbol {
                                            iconSize: Appearance.font.pixelSize.normal
                                            fill: 0
                                            horizontalAlignment: Text.AlignHCenter
                                            text: "close"
                                            color: root.blendedColors.colOnLayer1
                                        }
                                    }
                                }

                                // Same layout as the built-in preset grid above, growing
                                // to fit however many are saved - railFlick (see above)
                                // now handles overflow, so this no longer needs its own
                                // height cap or scroll handling of its own.
                                GridLayout {
                                    Layout.fillWidth: true
                                    Layout.minimumHeight: implicitHeight
                                    visible: Object.keys(root.customPresets).length > 0
                                    columns: 2
                                    columnSpacing: root.itemSpacing
                                    rowSpacing: root.itemSpacing

                                    Repeater {
                                        model: Object.keys(root.customPresets)

                                        delegate: PillChip {
                                            id: customBtn
                                            required property string modelData
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true
                                            Layout.preferredWidth: 0
                                            Layout.preferredHeight: 34
                                            chipToggled: root.presetName === modelData
                                            downAction: () => root.customEditMode ? root.deleteCustomPreset(modelData) : root.applyCustomPreset(modelData)

                                            // Pops in rather than appearing instantly - both
                                            // when the panel first populates and when a
                                            // freshly-saved custom preset lands in the grid.
                                            opacity: 0
                                            scale: 0.7
                                            Component.onCompleted: {
                                                customBtn.opacity = 1
                                                customBtn.scale = 1
                                            }
                                            Behavior on opacity {
                                                NumberAnimation { duration: 220; easing.type: Easing.OutCubic }
                                            }
                                            Behavior on scale {
                                                NumberAnimation { duration: 260; easing.type: Easing.OutBack }
                                            }

                                            contentItem: RowLayout {
                                                spacing: 4
                                                Item { implicitWidth: 4 }
                                                MaterialSymbol {
                                                    iconSize: Appearance.font.pixelSize.normal
                                                    fill: 0
                                                    text: root.customEditMode ? "delete" : "tune"
                                                    color: customBtn.chipToggled ? root.blendedColors.colOnPrimary : root.blendedColors.colOnLayer1
                                                }
                                                StyledText {
                                                    Layout.fillWidth: true
                                                    horizontalAlignment: Text.AlignHCenter
                                                    elide: Text.ElideRight
                                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                                    text: customBtn.modelData
                                                    color: customBtn.chipToggled ? root.blendedColors.colOnPrimary : root.blendedColors.colOnLayer1
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        // Hit zone for the scroll indicator - wider than the
                        // 3px bar itself so hovering near the edge (not just
                        // exactly on the bar) is enough to reveal it, and
                        // pressing/dragging anywhere in this zone scrubs the
                        // list (not just the thin 3px thumb itself, which is
                        // too narrow to reliably grab with a mouse).
                        MouseArea {
                            id: railScrollDragArea
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: 16
                            hoverEnabled: true
                            preventStealing: true
                            cursorShape: Qt.PointingHandCursor

                            readonly property real trackHeight: railFlick.height
                            readonly property real thumbHeight: railFlick.visibleArea.heightRatio * railScrollDragArea.trackHeight
                            readonly property real maxThumbY: Math.max(0, railScrollDragArea.trackHeight - railScrollDragArea.thumbHeight)
                            readonly property real maxContentY: Math.max(0, railFlick.contentHeight - railFlick.height)

                            // Centers the thumb under the pointer and maps
                            // that back to railFlick.contentY, the same way
                            // any custom scrollbar thumb drag works - lets
                            // both an initial press and a drag jump/scrub
                            // the list, not just nudge it.
                            function scrollToPointerY(pointerY) {
                                if (railScrollDragArea.maxThumbY <= 0) return
                                const thumbTop = Math.max(0, Math.min(pointerY - railScrollDragArea.thumbHeight / 2, railScrollDragArea.maxThumbY))
                                railFlick.contentY = (thumbTop / railScrollDragArea.maxThumbY) * railScrollDragArea.maxContentY
                            }

                            onPressed: (mouse) => railScrollDragArea.scrollToPointerY(mouse.y)
                            onPositionChanged: (mouse) => {
                                if (railScrollDragArea.pressed) railScrollDragArea.scrollToPointerY(mouse.y)
                            }
                        }

                        // Thin translucent scroll indicator for the rail's
                        // own scrolling area, living in the gutter railFlick
                        // reserves above (anchors.rightMargin: 10) so it
                        // never sits on top of the content itself. Pushed
                        // close to the panel's true right edge.
                        //
                        // Shown while actually scrolling, hovering nearby, or
                        // dragging the thumb - and once none of those still
                        // hold, kept visible for a short grace period instead
                        // of vanishing instantly (railScrollHideTimer below),
                        // so briefly drifting off the thin 3px bar mid-drag,
                        // or just glancing away, doesn't yank it out of view.
                        Rectangle {
                            id: railScrollIndicator
                            visible: railFlick.contentHeight > railFlick.height
                            anchors.right: parent.right
                            anchors.rightMargin: 1
                            y: railFlick.visibleArea.yPosition * railFlick.height
                            width: 3
                            radius: 1.5
                            height: railFlick.visibleArea.heightRatio * railFlick.height
                            color: ColorUtils.transparentize(root.blendedColors.colSubtext, railScrollDragArea.pressed ? 0.35 : 0.6)
                            opacity: railScrollIndicator.revealed ? 1 : 0

                            property bool revealed: false
                            readonly property bool wantsReveal: railFlick.moving || railFlick.flicking || railScrollDragArea.containsMouse || railScrollDragArea.pressed

                            onWantsRevealChanged: {
                                if (railScrollIndicator.wantsReveal) {
                                    // Something is actively asking for the
                                    // thumb right now - show it immediately
                                    // and cancel any pending hide.
                                    railScrollHideTimer.stop()
                                    railScrollIndicator.revealed = true
                                } else {
                                    // Nothing wants it any more, but don't
                                    // hide right away - give it a grace
                                    // period first (see the Timer below).
                                    railScrollHideTimer.restart()
                                }
                            }

                            Behavior on opacity {
                                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                            }
                        }

                        // Delay before railScrollIndicator actually fades
                        // out once nothing still wants it shown - restarted
                        // every time wantsReveal drops back to false above,
                        // and stopped/cancelled the moment it's true again.
                        Timer {
                            id: railScrollHideTimer
                            interval: 900
                            onTriggered: railScrollIndicator.revealed = false
                        }
                    }

                    // Update '<name>' - only shown when the edit in progress
                    // started from an existing named custom preset (see
                    // editingCustomPresetName). The main Save pill below
                    // only ever commits into whichever EasyEffects preset
                    // is currently active - it never touches your saved
                    // custom-preset shapes, so without this, editing
                    // "MyBassBoost" and hitting Save would leave
                    // "MyBassBoost" itself unchanged (next time you picked
                    // it, you'd get the old values back). This writes the
                    // current bands into that same custom-preset entry
                    // directly, same as retyping its name into "save as"
                    // would - just without having to retype it.
                    PillChip {
                        Layout.fillWidth: true
                        Layout.minimumHeight: implicitHeight
                        implicitHeight: 36
                        visible: root.pending && root.editingCustomPresetName.length > 0
                        chipToggled: false
                        downAction: () => root.saveCustomPreset(root.editingCustomPresetName)
                        contentItem: RowLayout {
                            spacing: 6
                            Item { Layout.fillWidth: true }
                            MaterialSymbol {
                                iconSize: Appearance.font.pixelSize.normal
                                fill: 0
                                text: "sync"
                                color: root.blendedColors.colOnLayer1
                            }
                            StyledText {
                                font.pixelSize: Appearance.font.pixelSize.small
                                text: Translation.tr("Update \"%1\"").arg(root.editingCustomPresetName)
                                color: root.blendedColors.colOnLayer1
                                elide: Text.ElideRight
                            }
                            Item { Layout.fillWidth: true }
                        }
                    }

                    // Save - the rail's primary action, not a full-width bar
                    // spanning the whole popup. Placed after railFlick rather
                    // than inside it, so it stays visible and full size no
                    // matter how far the custom-preset list has scrolled -
                    // railFlick above is what absorbs overflow now, never this.
                    // Dragging a slider previews live audio on its own (see
                    // liveApplyTimer above) but never touches the real saved
                    // preset - this pill is now the ONLY thing that commits.
                    PillChip {
                        Layout.fillWidth: true
                        Layout.minimumHeight: implicitHeight
                        implicitHeight: 46
                        enabled: root.pending
                        chipToggled: true
                        colBackgroundToggled: root.pending ? root.blendedColors.colPrimary : ColorUtils.transparentize(root.blendedColors.colLayer1, 0.35)
                        colBackgroundToggledHover: root.pending ? root.blendedColors.colPrimaryHover : ColorUtils.mix(root.blendedColors.colLayer1, root.blendedColors.colOnLayer1, 0.92)
                        downAction: () => root.saveChanges()
                        contentItem: RowLayout {
                            spacing: 6
                            Item { Layout.fillWidth: true }
                            MaterialSymbol {
                                iconSize: Appearance.font.pixelSize.large
                                fill: 1
                                text: root.pending ? "save" : "check_circle"
                                color: root.pending ? root.blendedColors.colOnPrimary : root.blendedColors.colSubtext
                                Behavior on color {
                                    ColorAnimation { duration: 180; easing.type: Easing.OutCubic }
                                }
                            }
                            StyledText {
                                font.bold: true
                                text: root.pending ? Translation.tr("Save") : Translation.tr("Saved")
                                color: root.pending ? root.blendedColors.colOnPrimary : root.blendedColors.colSubtext
                                Behavior on color {
                                    ColorAnimation { duration: 180; easing.type: Easing.OutCubic }
                                }
                            }
                            Item { Layout.fillWidth: true }
                        }
                    }
                }
            }

            // Band cluster + preamp, stacked vertically: 2 columns of
            // horizontal StyledSliders (5 rows) for the 10 bands, plus one
            // full-width master gain slider underneath. Same Panel as the
            // rail on the left, so the pair reads as one matched set of
            // cards rather than a bordered rail next to bare content.
            Panel {
                id: eqPanel
                Layout.fillWidth: true
                Layout.fillHeight: true

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: root.panelPadding
                    spacing: root.sectionSpacing

                    // Bands + preamp, scrolled independently of the rest of
                    // the popup - same reasoning as railFlick on the left:
                    // a narrow/short popup would otherwise squash the band
                    // sliders and preamp control instead of letting this
                    // side scroll too.
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Flickable {
                            id: eqFlick
                            anchors.fill: parent
                            // Leaves a dedicated gutter for the scroll
                            // indicator below, so it floats in empty space
                            // instead of overlapping the rightmost few
                            // pixels of every row's content.
                            anchors.rightMargin: 10
                            clip: true
                            contentWidth: width
                            contentHeight: eqColumn.implicitHeight
                            boundsBehavior: Flickable.StopAtBounds

                            ColumnLayout {
                                id: eqColumn
                                width: eqFlick.width
                                spacing: root.sectionSpacing

                                PanelHeader {
                                    text: Translation.tr("Bands")
                                }

                                // Purely visual read-out of the current curve shape -
                                // not interactive (drag the sliders below to change
                                // anything). Redraws whenever root.bands changes,
                                // via the Connections below, since Canvas only
                                // auto-repaints on its own geometry changes, not on
                                // arbitrary property changes elsewhere.
                                //
                                // Styled to read as the Material 3 Expressive
                                // counterpart of the sliders below: a thicker glowing
                                // gradient line, a soft tinted fill ballooning out from
                                // the 0dB line toward wherever the curve strays from
                                // it, and dots drawn like little slider thumbs (a
                                // filled center ring-fenced by the panel's own surface
                                // color) instead of flat dots.
                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 84
                                    Layout.minimumHeight: 72
                                    radius: root.panelRadius
                                    color: ColorUtils.transparentize(root.blendedColors.colLayer1, 0.35)
                                    border.width: 1
                                    border.color: root.panelBorderColor

                                    Canvas {
                                        id: eqCurveCanvas
                                        anchors.fill: parent
                                        anchors.margins: 6

                                        // The values actually drawn - eased toward
                                        // root.bands rather than snapping straight to it,
                                        // so switching presets makes the curve visibly
                                        // flow into its new shape instead of jump-cutting.
                                        property var displayBands: root.bands.slice()
                                        property var animFrom: root.bands.slice()
                                        property var animTo: root.bands.slice()
                                        property real animProgress: 1

                                        // root.blendedColors is the live art/blur-tinted
                                        // scheme - its individual colors (colPrimary,
                                        // colSecondary, ...) animate in place as the blur
                                        // background settles on new art, rather than the
                                        // blendedColors object itself ever being swapped
                                        // out. Everything else on this page picks that up
                                        // for free through plain property bindings (e.g.
                                        // `color: root.blendedColors.colPrimary`), but
                                        // Canvas painting is imperative JS, not a binding -
                                        // it only ever repaints when requestPaint() is
                                        // called, so it needs an explicit real binding to
                                        // notice those in-place color changes. This string
                                        // is that binding: touching each color here makes
                                        // QML wire up a dependency on that color's own
                                        // change notifier, so colorSignature changes (and
                                        // this repaints) the moment any of them do -
                                        // catching live blur-color transitions the same way
                                        // onBandsChanged catches live band edits.
                                        readonly property string colorSignature: [
                                            root.blendedColors.colPrimary,
                                            root.blendedColors.colSecondary,
                                            root.blendedColors.colSubtext,
                                            root.blendedColors.colLayer1
                                        ].join("|")
                                        onColorSignatureChanged: eqCurveCanvas.requestPaint()

                                        onAnimProgressChanged: {
                                            if (eqCurveCanvas.animFrom.length !== eqCurveCanvas.animTo.length) return
                                            const next = []
                                            for (let i = 0; i < eqCurveCanvas.animTo.length; i++) {
                                                const a = eqCurveCanvas.animFrom[i]
                                                const b = eqCurveCanvas.animTo[i]
                                                next.push(a + (b - a) * eqCurveCanvas.animProgress)
                                            }
                                            eqCurveCanvas.displayBands = next
                                            eqCurveCanvas.requestPaint()
                                        }

                                        NumberAnimation {
                                            id: curveAnim
                                            target: eqCurveCanvas
                                            property: "animProgress"
                                            from: 0
                                            to: 1
                                            duration: 420
                                            easing.type: Easing.OutCubic
                                        }

                                        onPaint: {
                                            const ctx = getContext("2d")
                                            ctx.reset()

                                            const padX = 10
                                            const padY = 12
                                            const innerW = width - padX * 2
                                            const innerH = height - padY * 2
                                            const midY = padY + innerH / 2

                                            const n = root.bands.length
                                            if (n < 2) return

                                            // Faint vertical guides at each band position,
                                            // echoing the frequency-grid look of a proper
                                            // graph rather than a bare sparkline.
                                            ctx.strokeStyle = ColorUtils.transparentize(root.blendedColors.colSubtext, 0.92)
                                            ctx.lineWidth = 1
                                            for (let g = 0; g < n; g++) {
                                                const gx = padX + (innerW * g) / (n - 1)
                                                ctx.beginPath()
                                                ctx.moveTo(gx, padY)
                                                ctx.lineTo(gx, height - padY)
                                                ctx.stroke()
                                            }

                                            // 0dB reference line
                                            ctx.strokeStyle = ColorUtils.transparentize(root.blendedColors.colSubtext, 0.8)
                                            ctx.lineWidth = 1
                                            ctx.beginPath()
                                            ctx.moveTo(padX, midY)
                                            ctx.lineTo(width - padX, midY)
                                            ctx.stroke()

                                            const source = (eqCurveCanvas.displayBands && eqCurveCanvas.displayBands.length === n)
                                                ? eqCurveCanvas.displayBands : root.bands
                                            const pts = []
                                            for (let i = 0; i < n; i++) {
                                                const x = padX + (innerW * i) / (n - 1)
                                                const v = Math.max(-root.bandRange, Math.min(root.bandRange, source[i]))
                                                const y = midY - (v / root.bandRange) * (innerH / 2)
                                                pts.push({ x: x, y: y })
                                            }

                                            // Builds the same smoothed spline path used for
                                            // both the fill and the stroke below, so the two
                                            // always agree exactly on the curve's shape.
                                            function tracePath() {
                                                ctx.moveTo(pts[0].x, pts[0].y)
                                                for (let j = 0; j < pts.length - 1; j++) {
                                                    const xc = (pts[j].x + pts[j + 1].x) / 2
                                                    const yc = (pts[j].y + pts[j + 1].y) / 2
                                                    ctx.quadraticCurveTo(pts[j].x, pts[j].y, xc, yc)
                                                }
                                                ctx.quadraticCurveTo(
                                                    pts[pts.length - 1].x, pts[pts.length - 1].y,
                                                    pts[pts.length - 1].x, pts[pts.length - 1].y
                                                )
                                            }

                                            // Soft tinted area between the curve and the 0dB
                                            // line - colored toward primary above the line
                                            // (boosted bands) and secondary below it (cut
                                            // bands), fading to nothing right at 0dB so the
                                            // fill reads as "distance from flat" rather than
                                            // "area under the curve".
                                            const fillGrad = ctx.createLinearGradient(0, 0, 0, height)
                                            const midStop = Math.max(0, Math.min(1, midY / height))
                                            fillGrad.addColorStop(0, ColorUtils.transparentize(root.blendedColors.colPrimary, 0.72))
                                            fillGrad.addColorStop(midStop, ColorUtils.transparentize(root.blendedColors.colPrimary, 1))
                                            fillGrad.addColorStop(midStop, ColorUtils.transparentize(root.blendedColors.colSecondary, 1))
                                            fillGrad.addColorStop(1, ColorUtils.transparentize(root.blendedColors.colSecondary, 0.72))

                                            ctx.beginPath()
                                            tracePath()
                                            ctx.lineTo(pts[pts.length - 1].x, midY)
                                            ctx.lineTo(pts[0].x, midY)
                                            ctx.closePath()
                                            ctx.fillStyle = fillGrad
                                            ctx.fill()

                                            // Same bass-tinted-primary -> treble-tinted-secondary
                                            // gradient as the band sliders themselves, so the
                                            // curve reads as one continuous thing with them -
                                            // thicker and softly glowing for the Expressive feel.
                                            const lineGrad = ctx.createLinearGradient(padX, 0, width - padX, 0)
                                            lineGrad.addColorStop(0, root.blendedColors.colPrimary)
                                            lineGrad.addColorStop(1, root.blendedColors.colSecondary)

                                            ctx.save()
                                            ctx.shadowColor = ColorUtils.transparentize(root.blendedColors.colPrimary, 0.6)
                                            ctx.shadowBlur = 6
                                            ctx.strokeStyle = lineGrad
                                            ctx.lineWidth = 3
                                            ctx.lineJoin = "round"
                                            ctx.lineCap = "round"
                                            ctx.beginPath()
                                            tracePath()
                                            ctx.stroke()
                                            ctx.restore()

                                            // Dots drawn as little slider thumbs - a solid
                                            // accent-colored center fenced by a ring in the
                                            // panel's own surface color - rather than flat
                                            // dots, tying them visually to the handles below.
                                            for (let k = 0; k < pts.length; k++) {
                                                ctx.beginPath()
                                                ctx.arc(pts[k].x, pts[k].y, 5.5, 0, Math.PI * 2)
                                                ctx.fillStyle = root.blendedColors.colLayer1
                                                ctx.fill()

                                                ctx.beginPath()
                                                ctx.arc(pts[k].x, pts[k].y, 3.5, 0, Math.PI * 2)
                                                ctx.fillStyle = root.bandAccentColor(k)
                                                ctx.fill()
                                            }
                                        }

                                        Connections {
                                            target: root
                                            function onBandsChanged() {
                                                // Ease from wherever the curve is currently
                                                // sitting (mid-animation or at rest) toward
                                                // the new band values, rather than restarting
                                                // from the old target every time - so rapid
                                                // successive changes (e.g. Auto EQ re-scoring)
                                                // don't stutter.
                                                eqCurveCanvas.animFrom = eqCurveCanvas.displayBands.slice()
                                                eqCurveCanvas.animTo = root.bands.slice()
                                                curveAnim.restart()
                                            }
                                        }
                                    }
                                }

                                GridLayout {
                                    Layout.fillWidth: true
                                    Layout.minimumHeight: implicitHeight
                                    columns: 2
                                    columnSpacing: root.itemSpacing
                                    rowSpacing: root.itemSpacing

                                    Repeater {
                                        model: root.bandLabels.length
                                        delegate: BandCell {
                                            Layout.fillWidth: true
                                            Layout.preferredWidth: 0
                                            Layout.preferredHeight: 34
                                            Layout.minimumHeight: 34
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.minimumHeight: implicitHeight
                                    implicitHeight: 1
                                    color: ColorUtils.transparentize(root.blendedColors.colSubtext, 0.85)
                                }

                                // Which EasyEffects preset the equalizer curve gets merged
                                // into - i.e. whichever one holds the rest of your chain
                                // (compressor, limiter, deesser, etc). This used to be a
                                // hardcoded guess ("output") with no way to change it; now
                                // you can pick one of your existing presets or type a
                                // different name.
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    Layout.minimumHeight: implicitHeight
                                    spacing: root.itemSpacing

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: root.itemSpacing

                                        StyledText {
                                            font.pixelSize: Appearance.font.pixelSize.small
                                            font.bold: true
                                            color: root.blendedColors.colSubtext
                                            text: Translation.tr("EasyEffects preset")
                                        }
                                        StyledText {
                                            Layout.fillWidth: true
                                            horizontalAlignment: Text.AlignHCenter
                                            elide: Text.ElideRight
                                            font.pixelSize: Appearance.font.pixelSize.smaller
                                            color: root.blendedColors.colOnLayer1
                                            text: root.activePreset
                                        }
                                        // Opens the dialog only - no longer toggles it shut
                                        // too. The name field's own "check" chip below already
                                        // closes the dialog when tapped (it's prefilled with
                                        // the current preset, so tapping it unchanged is a
                                        // no-op reselect that closes cleanly), and Escape on
                                        // that field closes it too - so a dedicated X here was
                                        // redundant with those, on top of visually colliding
                                        // with the trash toggle's own icon once that existed.
                                        PillChip {
                                            implicitWidth: 26
                                            implicitHeight: 26
                                            chipToggled: root.showActivePresetDialog
                                            downAction: () => root.showActivePresetDialog = true
                                            contentItem: MaterialSymbol {
                                                iconSize: Appearance.font.pixelSize.normal
                                                fill: 0
                                                horizontalAlignment: Text.AlignHCenter
                                                text: "edit"
                                                color: root.showActivePresetDialog ? root.blendedColors.colOnPrimary : root.blendedColors.colOnLayer1
                                            }
                                        }
                                        // Tap-to-delete toggle for the existing-presets list
                                        // below - kept on this same header row (rather than a
                                        // row of its own) so opening it doesn't cost an extra
                                        // line of otherwise-empty space. Only makes sense once
                                        // the dialog is open and there's actually something to
                                        // delete. Stays as the trash icon in both states (just
                                        // filled once active, plus the chip's own highlight)
                                        // rather than swapping to "check" once active, since
                                        // the name field's own apply chip below already uses
                                        // "check" - two check icons on screen read as
                                        // duplicates of each other.
                                        PillChip {
                                            implicitWidth: 26
                                            implicitHeight: 26
                                            visible: root.showActivePresetDialog && root.availablePresets.length > 0
                                            chipToggled: root.activePresetEditMode
                                            downAction: () => root.activePresetEditMode = !root.activePresetEditMode
                                            contentItem: MaterialSymbol {
                                                iconSize: Appearance.font.pixelSize.normal
                                                fill: root.activePresetEditMode ? 1 : 0
                                                horizontalAlignment: Text.AlignHCenter
                                                text: "delete"
                                                color: root.activePresetEditMode ? root.blendedColors.colOnPrimary : root.blendedColors.colOnLayer1
                                            }
                                        }
                                    }

                                    // Inline "type a preset name" row, toggled by the
                                    // pencil above - same pattern as the custom-preset
                                    // save row below.
                                    RowLayout {
                                        Layout.fillWidth: true
                                        visible: root.showActivePresetDialog
                                        spacing: 6

                                        opacity: root.showActivePresetDialog ? 1 : 0
                                        scale: root.showActivePresetDialog ? 1 : 0.94
                                        transformOrigin: Item.Top
                                        Behavior on opacity {
                                            NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
                                        }
                                        Behavior on scale {
                                            NumberAnimation { duration: 180; easing.type: Easing.OutBack }
                                        }

                                        Rectangle {
                                            Layout.fillWidth: true
                                            implicitHeight: 32
                                            radius: Appearance.rounding.normal
                                            color: ColorUtils.transparentize(root.blendedColors.colLayer1, 0.35)
                                            border.width: activePresetField.activeFocus ? 1 : 0
                                            border.color: root.blendedColors.colPrimary

                                            TextInput {
                                                id: activePresetField
                                                anchors.fill: parent
                                                anchors.leftMargin: 10
                                                anchors.rightMargin: 10
                                                verticalAlignment: TextInput.AlignVCenter
                                                color: root.blendedColors.colOnLayer1
                                                font.pixelSize: Appearance.font.pixelSize.smaller
                                                clip: true
                                                onAccepted: root.setActivePreset(text)
                                                Keys.onEscapePressed: { root.showActivePresetDialog = false }
                                            }
                                        }
                                        PillChip {
                                            implicitWidth: 32
                                            implicitHeight: 32
                                            chipToggled: true
                                            downAction: () => root.setActivePreset(activePresetField.text)
                                            contentItem: MaterialSymbol {
                                                iconSize: Appearance.font.pixelSize.normal
                                                fill: 1
                                                horizontalAlignment: Text.AlignHCenter
                                                text: "check"
                                                color: root.blendedColors.colOnPrimary
                                            }
                                        }
                                    }

                                    // Shown when the typed/tapped name doesn't match any
                                    // existing preset - creating one force-switches
                                    // EasyEffects to it, which replaces whatever's
                                    // currently live (discarding unsaved changes to other
                                    // effects), so this needs an explicit yes rather than
                                    // happening the moment you finish typing.
                                    Rectangle {
                                        Layout.fillWidth: true
                                        visible: root.pendingNewPresetName.length > 0
                                        Layout.minimumHeight: implicitHeight
                                        radius: Appearance.rounding.normal
                                        color: ColorUtils.transparentize(root.blendedColors.colPrimary, 0.85)
                                        implicitHeight: confirmColumn.implicitHeight + 16

                                        opacity: root.pendingNewPresetName.length > 0 ? 1 : 0
                                        scale: root.pendingNewPresetName.length > 0 ? 1 : 0.94
                                        transformOrigin: Item.Top
                                        Behavior on opacity {
                                            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                                        }
                                        Behavior on scale {
                                            NumberAnimation { duration: 200; easing.type: Easing.OutBack }
                                        }

                                        ColumnLayout {
                                            id: confirmColumn
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            spacing: 6

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 6

                                                MaterialSymbol {
                                                    Layout.alignment: Qt.AlignTop
                                                    iconSize: Appearance.font.pixelSize.normal
                                                    fill: 0
                                                    text: "info"
                                                    color: root.blendedColors.colPrimary
                                                }
                                                StyledText {
                                                    Layout.fillWidth: true
                                                    wrapMode: Text.WordWrap
                                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                                    color: root.blendedColors.colOnLayer1
                                                    text: Translation.tr("\"%1\" doesn't exist in EasyEffects yet. Creating it will replace whatever's currently live with a fresh preset containing just this equalizer - any unsaved changes to your other effects will be lost.").arg(root.pendingNewPresetName)
                                                }
                                            }

                                            RowLayout {
                                                Layout.alignment: Qt.AlignRight
                                                spacing: 6

                                                PillChip {
                                                    implicitWidth: 90
                                                    implicitHeight: 30
                                                    downAction: () => root.pendingNewPresetName = ""
                                                    contentItem: StyledText {
                                                        horizontalAlignment: Text.AlignHCenter
                                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                                        text: Translation.tr("Cancel")
                                                        color: root.blendedColors.colOnLayer1
                                                    }
                                                }
                                                PillChip {
                                                    implicitWidth: 90
                                                    implicitHeight: 30
                                                    chipToggled: true
                                                    downAction: () => root.createActivePreset(root.pendingNewPresetName)
                                                    contentItem: StyledText {
                                                        horizontalAlignment: Text.AlignHCenter
                                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                                        text: Translation.tr("Create")
                                                        color: root.blendedColors.colOnPrimary
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Shown after tapping a preset chip in delete mode -
                                    // this removes a real EasyEffects preset file, which
                                    // (unlike a custom EQ-curve entry) may hold hand-tuned
                                    // effects with no backup anywhere else, so it gets an
                                    // explicit confirm instead of deleting on first tap.
                                    Rectangle {
                                        Layout.fillWidth: true
                                        visible: root.pendingDeletePresetName.length > 0
                                        Layout.minimumHeight: implicitHeight
                                        radius: Appearance.rounding.normal
                                        color: ColorUtils.transparentize(root.blendedColors.colPrimary, 0.85)
                                        implicitHeight: deleteConfirmColumn.implicitHeight + 16

                                        opacity: root.pendingDeletePresetName.length > 0 ? 1 : 0
                                        scale: root.pendingDeletePresetName.length > 0 ? 1 : 0.94
                                        transformOrigin: Item.Top
                                        Behavior on opacity {
                                            NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                                        }
                                        Behavior on scale {
                                            NumberAnimation { duration: 200; easing.type: Easing.OutBack }
                                        }

                                        ColumnLayout {
                                            id: deleteConfirmColumn
                                            anchors.fill: parent
                                            anchors.margins: 8
                                            spacing: 6

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 6

                                                MaterialSymbol {
                                                    Layout.alignment: Qt.AlignTop
                                                    iconSize: Appearance.font.pixelSize.normal
                                                    fill: 0
                                                    text: "warning"
                                                    color: root.blendedColors.colPrimary
                                                }
                                                StyledText {
                                                    Layout.fillWidth: true
                                                    wrapMode: Text.WordWrap
                                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                                    color: root.blendedColors.colOnLayer1
                                                    text: Translation.tr("Delete the EasyEffects preset \"%1\"? This removes its file from disk, including any other effects (compressor, limiter, etc) saved in it - not just the equalizer. This can't be undone.").arg(root.pendingDeletePresetName)
                                                }
                                            }

                                            RowLayout {
                                                Layout.alignment: Qt.AlignRight
                                                spacing: 6

                                                PillChip {
                                                    implicitWidth: 90
                                                    implicitHeight: 30
                                                    downAction: () => root.pendingDeletePresetName = ""
                                                    contentItem: StyledText {
                                                        horizontalAlignment: Text.AlignHCenter
                                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                                        text: Translation.tr("Cancel")
                                                        color: root.blendedColors.colOnLayer1
                                                    }
                                                }
                                                PillChip {
                                                    implicitWidth: 90
                                                    implicitHeight: 30
                                                    chipToggled: true
                                                    downAction: () => root.deleteEasyEffectsPreset(root.pendingDeletePresetName)
                                                    contentItem: StyledText {
                                                        horizontalAlignment: Text.AlignHCenter
                                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                                        text: Translation.tr("Delete")
                                                        color: root.blendedColors.colOnPrimary
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Existing EasyEffects presets to pick from instead of
                                    // typing blind - whichever one actually holds your
                                    // other effects. Wraps rather than a fixed 2-column
                                    // grid since preset names vary a lot more in length
                                    // than the built-in EQ curve names do. The tap-to-delete
                                    // toggle for this list lives up in the header row above
                                    // (next to the edit pencil) rather than its own row here.
                                    Flow {
                                        Layout.fillWidth: true
                                        visible: root.showActivePresetDialog && root.availablePresets.length > 0
                                        spacing: 6

                                        Repeater {
                                            model: root.availablePresets

                                            delegate: PillChip {
                                                id: presetPickChip
                                                required property string modelData
                                                // Can't delete whatever's currently active - see
                                                // deleteEasyEffectsPreset()/the backend's own
                                                // refusal for why. Dimmed rather than hidden in
                                                // edit mode so it's clear this one's excluded on
                                                // purpose, not missing.
                                                readonly property bool isActive: root.activePreset === presetPickChip.modelData
                                                implicitHeight: 28
                                                implicitWidth: pickRow.implicitWidth + 20
                                                chipToggled: presetPickChip.isActive
                                                opacity: root.activePresetEditMode && presetPickChip.isActive ? 0.45 : 1
                                                downAction: () => {
                                                    if (root.activePresetEditMode) {
                                                        if (!presetPickChip.isActive)
                                                            root.requestDeleteEasyEffectsPreset(presetPickChip.modelData)
                                                    } else {
                                                        root.setActivePreset(presetPickChip.modelData)
                                                    }
                                                }
                                                contentItem: RowLayout {
                                                    id: pickRow
                                                    spacing: 4
                                                    MaterialSymbol {
                                                        visible: root.activePresetEditMode
                                                        iconSize: Appearance.font.pixelSize.normal
                                                        fill: 0
                                                        text: "delete"
                                                        color: presetPickChip.chipToggled ? root.blendedColors.colOnPrimary : root.blendedColors.colOnLayer1
                                                    }
                                                    StyledText {
                                                        horizontalAlignment: Text.AlignHCenter
                                                        font.pixelSize: Appearance.font.pixelSize.smaller
                                                        text: presetPickChip.modelData
                                                        color: presetPickChip.chipToggled ? root.blendedColors.colOnPrimary : root.blendedColors.colOnLayer1
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    StyledText {
                                        Layout.fillWidth: true
                                        visible: root.showActivePresetDialog && root.availablePresets.length === 0
                                        wrapMode: Text.WordWrap
                                        font.pixelSize: Appearance.font.pixelSize.smallest
                                        color: root.blendedColors.colSubtext
                                        text: Translation.tr("No saved EasyEffects presets found yet - type a name above and choose Create to start a fresh one, or save one from EasyEffects' own Presets tab first.")
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.minimumHeight: implicitHeight
                                    implicitHeight: 1
                                    color: ColorUtils.transparentize(root.blendedColors.colSubtext, 0.85)
                                }

                                // Preamp / output gain - one master control under the ten
                                // individual bands rather than an 11th band. Compensates
                                // for headroom lost when several bands are boosted,
                                // instead of the mix just clipping. Maps to the
                                // equalizer block's own output-gain, independent of
                                // whichever curve/preset is active.
                                RowLayout {
                                    id: preampRow
                                    Layout.fillWidth: true
                                    Layout.minimumHeight: implicitHeight
                                    spacing: 8

                                    StyledText {
                                        Layout.preferredWidth: 26
                                        font.pixelSize: Appearance.font.pixelSize.smallest
                                        font.features: { "tnum": 1 }
                                        color: root.blendedColors.colSubtext
                                        text: Translation.tr("Pre")
                                    }

                                    StyledSlider {
                                        id: preampSlider
                                        Layout.fillWidth: true
                                        configuration: StyledSlider.Configuration.M
                                        from: -root.preampRange
                                        to: root.preampRange
                                        value: root.preamp
                                        highlightColor: root.blendedColors.colPrimary
                                        trackColor: ColorUtils.transparentize(root.blendedColors.colPrimary, 0.85)
                                        handleColor: root.blendedColors.colPrimary
                                        // Same fix as the band sliders - default
                                        // stop-indicator value 1 has no meaning on
                                        // this -preampRange..+preampRange scale.
                                        stopIndicatorValues: [0]
                                        dotColor: root.blendedColors.colOnLayer1
                                        dotColorHighlighted: root.blendedColors.colOnPrimary
                                        usePercentTooltip: false
                                        tooltipContent: `${Math.round(value) > 0 ? "+" : ""}${Math.round(value)} dB`
                                        onMoved: root.setPreamp(value)

                                        Behavior on value {
                                            enabled: !preampSlider.pressed
                                            NumberAnimation { duration: 260; easing.type: Easing.OutCubic }
                                        }
                                    }

                                    StyledText {
                                        Layout.preferredWidth: 28
                                        horizontalAlignment: Text.AlignRight
                                        font.pixelSize: Appearance.font.pixelSize.smallest
                                        font.features: { "tnum": 1 }
                                        color: root.blendedColors.colPrimary
                                        text: `${Math.round(root.preamp) > 0 ? "+" : ""}${Math.round(root.preamp)}`
                                    }
                                }

                            }
                        }

                        // Hit zone for the scroll indicator - wider than the
                        // 3px bar itself so hovering near the edge (not just
                        // exactly on the bar) is enough to reveal it, and
                        // pressing/dragging anywhere in this zone scrubs the
                        // list (not just the thin 3px thumb itself, which is
                        // too narrow to reliably grab with a mouse).
                        MouseArea {
                            id: eqScrollDragArea
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: 16
                            hoverEnabled: true
                            preventStealing: true
                            cursorShape: Qt.PointingHandCursor

                            readonly property real trackHeight: eqFlick.height
                            readonly property real thumbHeight: eqFlick.visibleArea.heightRatio * eqScrollDragArea.trackHeight
                            readonly property real maxThumbY: Math.max(0, eqScrollDragArea.trackHeight - eqScrollDragArea.thumbHeight)
                            readonly property real maxContentY: Math.max(0, eqFlick.contentHeight - eqFlick.height)

                            // Centers the thumb under the pointer and maps
                            // that back to eqFlick.contentY, the same way
                            // any custom scrollbar thumb drag works - lets
                            // both an initial press and a drag jump/scrub
                            // the list, not just nudge it.
                            function scrollToPointerY(pointerY) {
                                if (eqScrollDragArea.maxThumbY <= 0) return
                                const thumbTop = Math.max(0, Math.min(pointerY - eqScrollDragArea.thumbHeight / 2, eqScrollDragArea.maxThumbY))
                                eqFlick.contentY = (thumbTop / eqScrollDragArea.maxThumbY) * eqScrollDragArea.maxContentY
                            }

                            onPressed: (mouse) => eqScrollDragArea.scrollToPointerY(mouse.y)
                            onPositionChanged: (mouse) => {
                                if (eqScrollDragArea.pressed) eqScrollDragArea.scrollToPointerY(mouse.y)
                            }
                        }

                        // Thin translucent scroll indicator for this panel's
                        // own scrolling area, living in the gutter eqFlick
                        // reserves above (anchors.rightMargin: 10) so it
                        // never sits on top of the content itself. Pushed
                        // close to the panel's true right edge.
                        //
                        // Shown while actually scrolling, hovering nearby, or
                        // dragging the thumb - and once none of those still
                        // hold, kept visible for a short grace period instead
                        // of vanishing instantly (eqScrollHideTimer below),
                        // so briefly drifting off the thin 3px bar mid-drag,
                        // or just glancing away, doesn't yank it out of view.
                        Rectangle {
                            id: eqScrollIndicator
                            visible: eqFlick.contentHeight > eqFlick.height
                            anchors.right: parent.right
                            anchors.rightMargin: 1
                            y: eqFlick.visibleArea.yPosition * eqFlick.height
                            width: 3
                            radius: 1.5
                            height: eqFlick.visibleArea.heightRatio * eqFlick.height
                            color: ColorUtils.transparentize(root.blendedColors.colSubtext, eqScrollDragArea.pressed ? 0.35 : 0.6)
                            opacity: eqScrollIndicator.revealed ? 1 : 0

                            property bool revealed: false
                            readonly property bool wantsReveal: eqFlick.moving || eqFlick.flicking || eqScrollDragArea.containsMouse || eqScrollDragArea.pressed

                            onWantsRevealChanged: {
                                if (eqScrollIndicator.wantsReveal) {
                                    // Something is actively asking for the
                                    // thumb right now - show it immediately
                                    // and cancel any pending hide.
                                    eqScrollHideTimer.stop()
                                    eqScrollIndicator.revealed = true
                                } else {
                                    // Nothing wants it any more, but don't
                                    // hide right away - give it a grace
                                    // period first (see the Timer below).
                                    eqScrollHideTimer.restart()
                                }
                            }

                            Behavior on opacity {
                                NumberAnimation { duration: 200; easing.type: Easing.OutCubic }
                            }
                        }

                        // Delay before eqScrollIndicator actually fades
                        // out once nothing still wants it shown - restarted
                        // every time wantsReveal drops back to false above,
                        // and stopped/cancelled the moment it's true again.
                        Timer {
                            id: eqScrollHideTimer
                            interval: 900
                            onTriggered: eqScrollIndicator.revealed = false
                        }
                    }
                }
            }
        }
    }
}

