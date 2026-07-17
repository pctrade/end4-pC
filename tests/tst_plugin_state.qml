import QtQuick
import QtTest
import qs.modules.common.plugins

TestCase {
    name: "PluginStateTest"

    function test_positionDefaultsWhenUnset() {
        var pos = PluginState.position("nonexistent_plugin", "DP-1");
        compare(pos.x, 100);
        compare(pos.y, 100);
        compare(pos.placementStrategy, "free");
    }

    function test_setPositionRoundTrips() {
        PluginState.setPosition("docker_plugin", "DP-1", { x: 564, y: 432, placementStrategy: "free" });
        var pos = PluginState.position("docker_plugin", "DP-1");
        compare(pos.x, 564);
        compare(pos.y, 432);
        compare(pos.placementStrategy, "free");
    }

    // Regression test: AbstractBackgroundWidget's onReleased used to write straight into
    // Config.options.background.widgets[configEntryName], an undeclared JsonObject key for
    // plugin widgets, which crashed qs on drag-release. Positions must round-trip purely
    // through PluginState instead, with no dependency on a Config-side entry existing.
    function test_setPositionDoesNotRequireConfigEntry() {
        PluginState.setPosition("some_never_configured_plugin", "HDMI-A-1", { x: 12, y: 34, placementStrategy: "free" });
        var pos = PluginState.position("some_never_configured_plugin", "HDMI-A-1");
        compare(pos.x, 12);
        compare(pos.y, 34);
    }

    function test_positionIsPerScreen() {
        PluginState.setPosition("at_a_glance_plugin", "DP-1", { x: 10, y: 20, placementStrategy: "free" });
        PluginState.setPosition("at_a_glance_plugin", "DP-2", { x: 30, y: 40, placementStrategy: "free" });
        compare(PluginState.position("at_a_glance_plugin", "DP-1").x, 10);
        compare(PluginState.position("at_a_glance_plugin", "DP-2").x, 30);
    }

    function test_normalizedPositionRejectsMalformedValues() {
        var pos = PluginState.normalizedPosition({ x: "not a number", y: 50, placementStrategy: 42 });
        compare(pos.x, 100);
        compare(pos.y, 50);
        compare(pos.placementStrategy, "free");
    }

    function test_normalizedPositionRejectsNonObject() {
        var pos = PluginState.normalizedPosition("garbage");
        compare(pos.x, 100);
        compare(pos.y, 100);
        compare(pos.placementStrategy, "free");
    }

    function test_optionDefaultsWhenUnset() {
        compare(PluginState.option("nonexistent_plugin", "blurEnabled", false), false);
        compare(PluginState.option("nonexistent_plugin", "fontSize", 24), 24);
    }

    function test_setOptionRoundTrips() {
        PluginState.setOption("at_a_glance_plugin", "blurEnabled", true);
        PluginState.setOption("at_a_glance_plugin", "fontSize", 26);
        compare(PluginState.option("at_a_glance_plugin", "blurEnabled", false), true);
        compare(PluginState.option("at_a_glance_plugin", "fontSize", 24), 26);
    }

    function test_setOptionDoesNotClobberOtherPlugins() {
        PluginState.setOption("docker_plugin", "blurEnabled", true);
        PluginState.setOption("at_a_glance_plugin", "blurEnabled", false);
        compare(PluginState.option("docker_plugin", "blurEnabled", false), true);
        compare(PluginState.option("at_a_glance_plugin", "blurEnabled", true), false);
    }

    function test_loadTextIgnoresMalformedState() {
        PluginState.setPosition("docker_plugin", "DP-1", { x: 1, y: 2, placementStrategy: "free" });
        PluginState.loadText("{ not valid json");
        // Falls back to an empty state rather than crashing or keeping stale data.
        var pos = PluginState.position("docker_plugin", "DP-1");
        compare(pos.x, 100);
        compare(pos.y, 100);
    }

    function test_loadTextRejectsNonObjectRoot() {
        PluginState.loadText("[1, 2, 3]");
        compare(Object.keys(PluginState.state.desktopPositions).length, 0);
    }
}
