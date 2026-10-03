// Run with node tests/player-activation-check.js.
const fs = require("node:fs")
const vm = require("node:vm")
const assert = require("node:assert/strict")
// Exercise the production action: compositor activation must accompany MPRIS Raise.
const controller = fs.readFileSync("services/MprisController.qml", "utf8")
const start = controller.indexOf("function raiseActivePlayer()")
const activation = controller.slice(start, controller.indexOf("\n\tProcess {", start))
let activated = ""
const window = (appId, title, focused = false) => ({appId, title, activated: focused,
    activate() { activated = title }})
const context = vm.createContext({
    root: {activePlayer: {dbusName: "org.mpris.MediaPlayer2.firefox.instance_1", desktopEntry: "Firefox.desktop", trackTitle: "Song"}},
    ToplevelManager: {toplevels: {values: [window("other", "Song"),
        window("firefox", "Browser", true), window("firefox", "Song — Apple Music")]}},
    raisePlayerProcess: {running: false, command: []}
})
vm.runInContext(activation, context)
vm.runInContext("raiseActivePlayer()", context)
assert.equal(activated, "Song — Apple Music")
assert.equal(context.raisePlayerProcess.running, true)
assert.equal(context.raisePlayerProcess.command.at(-1), "org.mpris.MediaPlayer2.Raise")
activated = ""
context.root.activePlayer.trackTitle = "Unknown title"
vm.runInContext("raiseActivePlayer()", context)
assert.equal(activated, "Browser")
activated = ""
context.root.activePlayer = null
context.raisePlayerProcess.running = false
context.ToplevelManager.toplevels.values = [window("", "Unrelated window")]
vm.runInContext("raiseActivePlayer()", context)
assert.equal(activated, "")
assert.equal(context.raisePlayerProcess.running, false)
console.log("Player window activation checks passed")
