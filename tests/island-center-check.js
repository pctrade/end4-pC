// Run with node tests/island-center-check.js.
const fs = require('node:fs')
const assert = require('node:assert/strict')
const vm = require('node:vm')
const read = path => fs.readFileSync(`${__dirname}/../${path}`, 'utf8')
const config = read('modules/common/Config.qml')
const source = read('modules/ii/bar/DynamicIsland.qml')
const settings = read('modules/ii/settings/pages/BarConfig.qml')
const migration = config.match(/if \(!island.centerWidgetMigrated\) \{[^}]+\}/)[0]
for (const enabled of [true, false]) {
    const island = {centerWorkspaces: enabled, centerEnabled: false, centerWidget: 'workspaces'}
    vm.runInNewContext(migration, {island})
    assert.equal(island.centerEnabled, enabled)
    island.centerEnabled = !enabled
    vm.runInNewContext(migration, {island})
    assert.equal(island.centerEnabled, !enabled, 'Migration must not override later choices')
}
const centerSection = settings.slice(settings.indexOf('sectionTitle: Translation.tr("Centered")'),
    settings.indexOf('sectionTitle: Translation.tr("Right side")'))
const update = centerSection.slice(centerSection.indexOf('onUpdate: ') + 10, centerSection.lastIndexOf('\n                }'))
const island = {centerWidget: '', leftWidgets: ['clockWidget', 'media'], rightWidgets: ['clockWidget', 'resources']}
vm.runInNewContext(`const update = ${update}; update(['clockWidget', 'media'])`, {Config: {options: {bar: {dynamicIsland: island}}}})
assert.equal(island.centerWidget, 'clockWidget')
assert.deepEqual(island.leftWidgets, ['media'])
assert.deepEqual(island.rightWidgets, ['resources'])
// Evaluate the production geometry with changing central widths and uneven wings.
const geometry = source.slice(source.indexOf('    readonly property real leftContentWidth:'),
    source.indexOf('    HoverHandler { id: islandHover }'))
const properties = [...geometry.matchAll(/^    readonly property real (\w+): ([\s\S]*?)(?=\n    (?:readonly property|implicitHeight))/gm)]
for (const width of [24, 100, 240]) {
    const root = {centerEnabled: true, contentPadding: 8, widgetSpacing: 8,
        primaryWidth: 0, maxLeftExtent: 120, maxRightExtent: 600}
    const context = {root, leftWidgets: {implicitWidth: 90}, rightWidgets: {implicitWidth: 260},
        centerLoader: {implicitWidth: width}}
    for (const [, name, expression] of properties) {
        if (name === 'centerX' || name === 'barCenterOffset') root.width = root.leftExtent + root.rightExtent
        root[name] = vm.runInNewContext(expression, context)
    }
    const screenCenter = 960
    const islandX = screenCenter - root.width / 2 + root.barCenterOffset
    assert.equal(islandX + root.centerX, screenCenter, 'Selected widget must remain at the screen center')
}
// Upstream hides unused settings sections: island lists and center must count.
const usedWidgetsBody = settings.slice(settings.indexOf('    readonly property var usedWidgets: {') + '    readonly property var usedWidgets: {'.length,
    settings.indexOf('\n    function isUsed(')).trim().replace(/}$/, '')
const usedConfig = {options: {bar: {vertical: false,
    layouts: {leftLayout: ['clockWidget'], middleLayout: ['dynamicIsland'], rightLayout: []},
    dynamicIsland: {leftWidgets: ['resources'], rightWidgets: ['media'],
        centerEnabled: true, centerWidget: 'workspaces'}}}}
const usedWidgets = () => Array.from(vm.runInNewContext('(function () {' + usedWidgetsBody + '})()', {Config: usedConfig}))
assert.deepEqual(usedWidgets(), ['clockWidget', 'dynamicIsland', 'resources', 'media', 'workspaces'])
usedConfig.options.bar.dynamicIsland.centerEnabled = false
assert.equal(usedWidgets().includes('workspaces'), false)
usedConfig.options.bar.dynamicIsland.centerEnabled = true
usedConfig.options.bar.vertical = true
assert.equal(usedWidgets().includes('workspaces'), false)
usedConfig.options.bar.layouts.middleLayout = []
assert.deepEqual(usedWidgets(), ['clockWidget'])
console.log('Island center and settings visibility checks passed')
