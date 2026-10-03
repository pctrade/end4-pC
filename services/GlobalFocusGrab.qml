pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs
import qs.services

/**
 * Manages a HyprlandFocusGrab that's to be shared by all windows.
 * "Persistent" is for windows that should always be included but not closed on dismiss, like bar and onscreen keyboard.
 * "Dismissable" is for stuff like sidebars.
 **/
 
Singleton {
    id: root

    signal dismissed()

    property list<var> persistent: []
    property list<var> dismissable: []
    property list<var> barWindows: []
    property bool sessionGrabReady: false

    function dismiss() {
        root.dismissable = [];
        root.dismissed();
    }

    Component.onCompleted: {
        console.log("[GlobalFocusGrab] Initialized" + (WM.compositor !== "hyprland" ? " (inactive, non-Hyprland compositor)" : ""));
    }

    function addPersistent(window) {
        if (root.persistent.indexOf(window) === -1) {
            root.persistent.push(window);
        }
    }

    function removePersistent(window) {
        var index = root.persistent.indexOf(window);
        if (index !== -1) {
            root.persistent.splice(index, 1);
        }
    }

    function addBarWindow(window) {
        if (root.barWindows.indexOf(window) === -1)
            root.barWindows.push(window);
    }

    function removeBarWindow(window) {
        const index = root.barWindows.indexOf(window);
        if (index !== -1)
            root.barWindows.splice(index, 1);
    }

    function addDismissable(window) {
        if (root.dismissable.indexOf(window) === -1) {
            root.dismissable.push(window);
        }
    }

    function removeDismissable(window) {
        var index = root.dismissable.indexOf(window);
        if (index !== -1) {
            root.dismissable.splice(index, 1);
        }
    }

    function hasActive(element) {
        return element?.activeFocus || Array.from(
            element?.children ?? []
        ).some(
            (child) => hasActive(child)
        );
    }

    Connections {
        target: GlobalStates
        function onDiSessionOpenChanged() {
            if (GlobalStates.diSessionOpen) {
                sessionGrabDelay.restart()
            } else {
                sessionGrabDelay.stop()
                root.sessionGrabReady = false
            }
        }
    }

    Timer {
        id: sessionGrabDelay
        interval: 50
        onTriggered: root.sessionGrabReady = GlobalStates.diSessionOpen
    }

    HyprlandFocusGrab {
        id: grab
        windows: root.sessionGrabReady
            ? [...root.barWindows]
            : (root.dismissable.every(w => !w?.focusable)
                || root.dismissable.some(w => root.hasActive(w?.contentItem))
                ? [...root.dismissable, ...root.persistent] : [...root.dismissable])
        active: WM.compositor === "hyprland"
            && (root.sessionGrabReady || root.dismissable.length > 0)
        onCleared: () => {
            if (root.sessionGrabReady)
                GlobalStates.diSessionOpen = false;
            root.dismiss();
        }
    }
}