import QtQuick
import QtTest
import "../modules/common/plugins/PluginValidator.js" as PluginValidator

TestCase {
    name: "PluginValidatorTest"

    function test_validManifest() {
        var manifest = {
            "id": "my_clock",
            "name": "My Clock",
            "desktopWidget": {
                "type": "StyledRectangularShadow",
                "props": { "radius": 17 },
                "children": [
                    {
                        "type": "StyledText",
                        "bindings": { "text": "DateTime.time" }
                    }
                ]
            }
        };

        var result = PluginValidator.validateManifest(manifest);
        verify(result.valid, "Manifest should be valid: " + (result.error ? result.error : ""));
    }

    function test_validDockerManifest() {
        var manifest = {
            "id": "my_docker",
            "name": "My Docker",
            "desktopWidget": {
                "type": "Row",
                "children": [
                    {
                        "type": "StyledText",
                        "bindings": { "text": "Docker.runningCount" }
                    },
                    {
                        "type": "StyledText",
                        "bindings": { "text": "Docker.totalCount" }
                    }
                ]
            }
        };

        var result = PluginValidator.validateManifest(manifest);
        verify(result.valid, "Docker manifest should be valid: " + (result.error ? result.error : ""));
    }

    function test_validAtAGlanceManifest() {
        var manifest = {
            "id": "at_a_glance",
            "name": "At a Glance",
            "options": [
                { "key": "showGreeting", "type": "boolean", "default": true },
                {
                    "key": "alignment",
                    "type": "choice",
                    "default": "left",
                    "choices": [{ "displayName": "Left", "value": "left" }]
                },
                { "key": "fontSize", "type": "number", "default": 24, "from": 14, "to": 48 }
            ],
            "desktopWidget": {
                "type": "AtAGlance",
                "props": {
                    "width": 420,
                    "showQuote": true
                },
                "blur": false
            }
        };

        var result = PluginValidator.validateManifest(manifest);
        verify(result.valid, "At-a-glance manifest should be valid: " + (result.error ? result.error : ""));
    }

    function test_missingId() {
        var manifest = {
            "name": "My Clock",
            "desktopWidget": { "type": "Item" }
        };
        var result = PluginValidator.validateManifest(manifest);
        verify(!result.valid);
        compare(result.error, "Manifest must have a string 'id'");
    }

    function test_invalidComponentType() {
        var manifest = {
            "id": "bad_plugin",
            "name": "Bad Plugin",
            "desktopWidget": {
                "type": "Process", // not whitelisted
            }
        };
        var result = PluginValidator.validateManifest(manifest);
        verify(!result.valid);
        compare(result.error, "Invalid desktopWidget: Component type 'Process' is not whitelisted");
    }

    function test_invalidPluginOptionType() {
        var manifest = {
            "id": "bad_options",
            "name": "Bad Options",
            "options": [{ "key": "script", "type": "javascript" }],
            "desktopWidget": { "type": "Item" }
        };
        var result = PluginValidator.validateManifest(manifest);
        verify(!result.valid);
        compare(result.error, "Unsupported plugin option type 'javascript'");
    }

    function test_invalidBindingTarget() {
        var manifest = {
            "id": "bad_binding",
            "name": "Bad Binding",
            "desktopWidget": {
                "type": "StyledText",
                "bindings": { "text": "Config.options.lock.enable" } // not whitelisted
            }
        };
        var result = PluginValidator.validateManifest(manifest);
        verify(!result.valid);
        compare(result.error, "Invalid desktopWidget: Binding target 'Config.options.lock.enable' is not whitelisted");
    }

    function test_nestedInvalidChild() {
        var manifest = {
            "id": "nested_invalid",
            "name": "Nested",
            "desktopWidget": {
                "type": "Column",
                "children": [
                    { "type": "StyledText" },
                    { "type": "UnknownType" }
                ]
            }
        };
        var result = PluginValidator.validateManifest(manifest);
        verify(!result.valid);
        compare(result.error, "Invalid desktopWidget: Component type 'UnknownType' is not whitelisted");
    }
}
