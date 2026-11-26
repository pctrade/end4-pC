import qs.services

ConfigSwitch {
    id: root

    required property string optionKey
    property bool fallback: false

    checked: Boolean(HyprlandOptions.get(root.optionKey, root.fallback))
    onCheckedChanged: {
        if (checked === Boolean(HyprlandOptions.get(root.optionKey, root.fallback))) return
        HyprlandOptions.apply(root.optionKey, checked)
    }
}
