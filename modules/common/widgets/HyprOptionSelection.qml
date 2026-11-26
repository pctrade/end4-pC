import qs.services

ConfigSelectionArray {
    id: root

    required property string optionKey
    property var fallback: ""

    currentValue: HyprlandOptions.get(root.optionKey, root.fallback)
    onSelected: newValue => HyprlandOptions.apply(root.optionKey, newValue)
}
