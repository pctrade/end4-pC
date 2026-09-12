pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.services
import qs.modules.common as C

NestableObject {
    id: root

    required property var screen
    readonly property string monitorName: screen?.name ?? ""

    readonly property var hyprMonitor: WM.compositor === "hyprland" ? Hyprland.monitorFor(screen) : null
    readonly property var liveMonitorData: WM.compositor === "hyprland"
        ? HyprlandData.monitors.find(m => m.id === hyprMonitor?.id)
        : null

    readonly property Toplevel activeWindow: ToplevelManager.activeToplevel
    readonly property int shownCount: C.Config.options.bar.workspaces.shown

    readonly property int activeNumber: {
        if (WM.compositor === "hyprland")
            return hyprMonitor?.activeWorkspace?.id ?? 1
        const ws = WM.workspaces.find(w => w.output === root.monitorName && w.is_active)
        return ws?.idx ?? 1
    }

    readonly property bool currentWorkspaceNotFake: WM.compositor === "hyprland"
        ? (activeWindow?.activated ?? false) // Active empty workspace = fake. At least, that's how I like to call it.
        : true 
    readonly property int fakeWorkspace: currentWorkspaceNotFake ? -9999 : activeNumber

    readonly property int group: Math.floor((activeNumber - 1) / shownCount)

    readonly property var specialWorkspace: WM.compositor === "hyprland" ? liveMonitorData?.specialWorkspace : null
    readonly property string specialWorkspaceName: specialWorkspace?.name.replace("special:", "") ?? "special"
    readonly property bool specialWorkspaceActive: WM.compositor === "hyprland" && specialWorkspaceName !== ""

    property list<bool> occupied: []
    readonly property bool shouldShowAppIcons: Boolean(C.Config.options.bar?.workspaces?.showAppIcons || C.Config.options.bar?.workspaces?.indicatorStyle === "icon")
    property list<var> biggestWindow: shouldShowAppIcons ? occupied.map((_, index) => {
        const number = getWorkspaceIdAt(index)
        return root.biggestWindowForNumber(number)
    }) : []

    function getWorkspaceId(group, index) {
        return group * root.shownCount + index + 1
    }
    function getWorkspaceIdAt(index) {
        return root.getWorkspaceId(root.group, index)
    }

    function _niriRealId(number) {
        const ws = WM.workspaces.find(w => w.output === root.monitorName && w.idx === number)
        return ws?.id ?? null
    }

    function biggestWindowForNumber(number) {
        if (WM.compositor === "hyprland")
            return HyprlandData.biggestWindowForWorkspace(number)

        const realId = root._niriRealId(number)
        if (realId === null) return null
        const winsInWs = WM.windowList.filter(w => w.workspaceId === realId)
        if (winsInWs.length === 0) return null
        const win = winsInWs.find(w => w.focused) ?? winsInWs[0]
        return { class: win.appId, title: win.title, id: win.id }
    }

    function updateWorkspaceOccupied() {
        const count = root.shownCount;
        let newOccupied = new Array(count);

        if (WM.compositor === "hyprland") {
            const occupiedWsIds = new Set();
            const wsVals = Hyprland.workspaces?.values || [];
            for (let i = 0; i < wsVals.length; i++) {
                const ws = wsVals[i];
                if (ws && (ws.windows > 0 || ws.id !== root.activeNumber)) {
                    occupiedWsIds.add(ws.id);
                }
            }
            const winList = HyprlandData.windowList || [];
            for (let i = 0; i < winList.length; i++) {
                const w = winList[i];
                if (w?.workspace?.id !== undefined) {
                    occupiedWsIds.add(w.workspace.id);
                }
            }

            for (let i = 0; i < count; i++) {
                const thisWorkspaceId = getWorkspaceId(root.group, i);
                newOccupied[i] = occupiedWsIds.has(thisWorkspaceId);
            }
        } else {
            const winList = WM.windowList || [];
            for (let i = 0; i < count; i++) {
                const number = getWorkspaceId(root.group, i);
                const realId = root._niriRealId(number);
                newOccupied[i] = (realId !== null) && winList.some(w => w.workspaceId === realId);
            }
        }
        root.occupied = newOccupied;
    }

    Component.onCompleted: updateWorkspaceOccupied()

    // Hyprland
    Connections {
        target: Hyprland.workspaces
        enabled: WM.compositor === "hyprland"
        function onValuesChanged() {
            root.updateWorkspaceOccupied()
        }
    }
    Connections {
        target: Hyprland
        enabled: WM.compositor === "hyprland"
        function onFocusedWorkspaceChanged() {
            root.updateWorkspaceOccupied()
        }
    }
    Connections {
        target: HyprlandData
        enabled: WM.compositor === "hyprland"
        function onWindowListChanged() {
            root.updateWorkspaceOccupied()
        }
    }

    // Niri
    Connections {
        target: WM
        enabled: WM.compositor !== "hyprland"
        function onWorkspacesChanged() {
            root.updateWorkspaceOccupied()
        }
        function onWindowListChanged() {
            root.updateWorkspaceOccupied()
        }
    }

    onGroupChanged: {
        updateWorkspaceOccupied()
    }
}