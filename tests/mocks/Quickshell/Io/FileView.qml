import QtQuick

Item {
    property string path
    property bool watchChanges
    property bool blockWrites
    property var adapter
    
    signal fileChanged()
    signal adapterUpdated()
    signal loaded()
    signal loadFailed(var error)
    
    function reload() {}
    function writeAdapter() {}
    function text() { return "" }
    function setText(newText) {}
}
