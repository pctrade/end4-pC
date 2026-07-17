.pragma library

const componentWhitelist = [
    "StyledText", "StyledRectangularShadow", "MaterialSymbol", "GroupedList",
    "RippleButton", "ResourceCard", "StyledImage", "MaterialShape", "StyledPopup", "ConfigSwitch", "NoticeBox",
    "Row", "Column", "Item", "Rectangle", "AtAGlance"
];

const bindingWhitelist = [
    "DateTime.time", "DateTime.date", "DateTime.shortDate",
    "Battery.percentage", "Battery.charging", "Battery.pluggedIn",
    "Network.networkName", "Network.primaryIp", "SystemInfo.cpuUsage",
    "SystemInfo.ramUsage", "Audio.volume", "Audio.muted",
    "Docker.runningCount", "Docker.totalCount"
];

function validateManifest(manifest) {
    if (!manifest || typeof manifest !== 'object') {
        return { valid: false, error: "Manifest must be an object" };
    }
    if (!manifest.id || typeof manifest.id !== 'string') {
        return { valid: false, error: "Manifest must have a string 'id'" };
    }
    if (!manifest.name || typeof manifest.name !== 'string') {
        return { valid: false, error: "Manifest must have a string 'name'" };
    }
    const entryPoints = ["desktopWidget", "barWidget", "controlCenterWidget", "launcherProvider", "panel", "settingsUi"];
    let hasEntryPoint = false;

    for (let i = 0; i < entryPoints.length; i++) {
        let ep = entryPoints[i];
        if (manifest[ep]) {
            hasEntryPoint = true;
            let res = validateNode(manifest[ep]);
            if (!res.valid) {
                return { valid: false, error: "Invalid " + ep + ": " + res.error };
            }
        }
    }

    if (!hasEntryPoint) {
        return { valid: false, error: "Manifest must have at least one entry point (e.g. desktopWidget, barWidget)" };
    }

    if (manifest.desktopWidget && manifest.desktopWidget.blur !== undefined
            && typeof manifest.desktopWidget.blur !== "boolean") {
        return { valid: false, error: "desktopWidget.blur must be a boolean" };
    }

    if (manifest.options !== undefined) {
        if (!Array.isArray(manifest.options)) {
            return { valid: false, error: "Manifest 'options' must be an array" };
        }
        const optionKeys = new Set();
        for (const option of manifest.options) {
            if (!option || typeof option !== "object" || typeof option.key !== "string" || !option.key) {
                return { valid: false, error: "Every plugin option must have a non-empty string 'key'" };
            }
            if (optionKeys.has(option.key)) {
                return { valid: false, error: "Duplicate plugin option key '" + option.key + "'" };
            }
            optionKeys.add(option.key);
            if (!["boolean", "choice", "number"].includes(option.type)) {
                return { valid: false, error: "Unsupported plugin option type '" + option.type + "'" };
            }
            if (option.type === "choice" && (!Array.isArray(option.choices) || option.choices.length === 0)) {
                return { valid: false, error: "Choice option '" + option.key + "' must have choices" };
            }
            if (option.type === "number"
                    && (typeof option.from !== "number" || typeof option.to !== "number" || option.from > option.to)) {
                return { valid: false, error: "Number option '" + option.key + "' must have a valid range" };
            }
        }
    }

    return { valid: true };
}

function validateNode(node) {
    if (!node.type || typeof node.type !== 'string') {
        return { valid: false, error: "Node must have a string 'type'" };
    }
    if (!componentWhitelist.includes(node.type)) {
        return { valid: false, error: "Component type '" + node.type + "' is not whitelisted" };
    }

    if (node.bindings) {
        if (typeof node.bindings !== 'object') {
            return { valid: false, error: "Node 'bindings' must be an object" };
        }
        for (let prop in node.bindings) {
            let bindTarget = node.bindings[prop];
            if (typeof bindTarget !== 'string') {
                return { valid: false, error: "Binding target for property '" + prop + "' must be a string" };
            }
            if (!bindingWhitelist.includes(bindTarget)) {
                return { valid: false, error: "Binding target '" + bindTarget + "' is not whitelisted" };
            }
        }
    }

    if (node.children) {
        if (!Array.isArray(node.children)) {
            return { valid: false, error: "Node 'children' must be an array" };
        }
        for (let i = 0; i < node.children.length; i++) {
            let childRes = validateNode(node.children[i]);
            if (!childRes.valid) return childRes;
        }
    }

    return { valid: true };
}
