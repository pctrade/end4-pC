pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property list<string> keys: [
        "general:resize_on_border", "general:extend_border_grab_area", "general:allow_tearing",
        "decoration:shadow:enabled", "decoration:shadow:range", "decoration:dim_inactive", "decoration:dim_strength",
        "decoration:blur:noise", "decoration:blur:vibrancy",
        "input:sensitivity", "input:accel_profile", "input:force_no_accel", "input:left_handed",
        "input:kb_variant", "input:kb_options",
        "input:touchpad:tap-to-click", "input:touchpad:tap-and-drag", "input:touchpad:middle_button_emulation",
        "misc:vrr", "misc:disable_hyprland_logo", "misc:disable_splash_rendering",
        "misc:mouse_move_enables_dpms", "misc:key_press_enables_dpms", "misc:animate_manual_resizes",
        "misc:enable_swallow", "misc:middle_click_paste", "misc:close_special_on_empty",
        "cursor:no_hardware_cursors", "cursor:inactive_timeout", "cursor:hide_on_key_press", "cursor:warp_on_change_workspace",
        "dwindle:preserve_split", "dwindle:smart_split", "dwindle:force_split", "dwindle:default_split_ratio",
        "master:new_status", "master:mfact", "master:orientation",
        "xwayland:force_zero_scaling", "render:direct_scanout",
        "binds:workspace_back_and_forth", "binds:allow_workspace_cycles", "group:auto_group"
    ]

    property var values: ({})

    function get(key, fallback) {
        const value = root.values[key]
        return value === undefined ? fallback : value
    }

    function apply(key, value) {
        const next = Object.assign({}, root.values)
        next[key] = value
        root.values = next
        let sent = value
        if (typeof value === "boolean") sent = value ? 1 : 0
        else if (value === "") sent = "[[EMPTY]]"
        HyprlandConfig.set(key, sent)
    }

    function refresh() {
        readProc.running = false
        readProc.running = true
    }

    Process {
        id: readProc
        command: ["bash", "-c", `for key in ${root.keys.join(" ")}; do hyprctl getoption "$key" -j; done | jq -c 'if has("bool") then {key: .option, value: .bool} elif has("int") then {key: .option, value: .int} elif has("float") then {key: .option, value: .float} elif has("str") then {key: .option, value: (if .str == "[[EMPTY]]" then "" else .str end)} else empty end'`]
        stdout: StdioCollector {
            onStreamFinished: {
                const next = {}
                for (const line of text.split("\n")) {
                    if (line.trim().length === 0) continue
                    try {
                        const entry = JSON.parse(line)
                        next[entry.key] = entry.value
                    } catch (e) {
                        console.log("Failed to parse Hyprland option:", line)
                    }
                }
                root.values = next
            }
        }
    }
}
