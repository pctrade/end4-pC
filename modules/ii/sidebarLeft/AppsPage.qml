import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

// Every installed application from A to Z, as a grid of icons or a list
Item {
    id: root
    readonly property bool listView: Config.options.sidebar.apps.view === "list"
    property string query: ""

    readonly property var apps: {
        const q = root.query.trim().toLowerCase();
        return AppSearch.list
            .filter(app => q.length === 0 || [app.name, app.genericName, (app.keywords ?? []).join(" ")]
                .some(text => (text ?? "").toLowerCase().includes(q)))
            .sort((a, b) => a.name.toLowerCase().localeCompare(b.name.toLowerCase()));
    }

    function letterOf(app) {
        const first = (app?.name ?? "").charAt(0).toUpperCase();
        return first.toLowerCase() !== first ? first : "#";
    }

    function launch(app) {
        if (!app) return;
        if (!app.runInTerminal)
            app.execute();
        else
            Quickshell.execDetached(["bash", "-c", `${Config.options.apps.terminal} -e '${StringUtils.shellSingleQuoteEscape(app.command.join(" "))}'`]);
        GlobalStates.sidebarLeftOpen = false;
    }

    onFocusChanged: focus => {
        if (focus) searchField.forceActiveFocus();
    }

    ColumnLayout {
        anchors {
            fill: parent
            margins: 10
        }
        spacing: 10

        RowLayout {
            Layout.fillWidth: true
            spacing: 6

            ToolbarTextField {
                id: searchField
                Layout.fillWidth: true
                Layout.fillHeight: false // ToolbarTextField fills the height of its toolbar by default
                implicitHeight: 40
                colBackground: Appearance.colors.colLayer2
                placeholderText: Translation.tr("Search %1 apps").arg(AppSearch.list.length)
                onTextChanged: root.query = text
                Keys.onReturnPressed: root.launch(root.apps[0])
                Keys.onEscapePressed: text = ""
            }

            RippleButton {
                implicitWidth: 40
                implicitHeight: 40
                buttonRadius: Appearance.rounding.full
                colBackground: Appearance.colors.colLayer2
                onClicked: Config.options.sidebar.apps.view = root.listView ? "grid" : "list"
                contentItem: MaterialSymbol {
                    anchors.centerIn: parent
                    horizontalAlignment: Text.AlignHCenter
                    text: root.listView ? "grid_view" : "view_list"
                    iconSize: Appearance.font.pixelSize.larger
                    color: Appearance.colors.colOnLayer1
                }
                StyledToolTip {
                    text: root.listView ? Translation.tr("Show as grid") : Translation.tr("Show as list")
                }
            }
        }

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            StyledGridView {
                id: grid
                readonly property int columns: Math.max(3, Math.floor(width / 84))
                anchors.fill: parent
                visible: !root.listView
                clip: true
                cellWidth: width / columns
                cellHeight: 92
                model: root.listView ? [] : root.apps
                delegate: RippleButton {
                    id: gridItem
                    required property var modelData
                    width: grid.cellWidth
                    height: grid.cellHeight
                    buttonRadius: Appearance.rounding.normal
                    onClicked: root.launch(modelData)
                    contentItem: ColumnLayout {
                        spacing: 6
                        IconImage {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 6
                            implicitSize: 40
                            source: SystemAppearance.iconPath(gridItem.modelData.icon, "image-missing")
                        }
                        StyledText {
                            Layout.fillWidth: true
                            Layout.leftMargin: 4
                            Layout.rightMargin: 4
                            horizontalAlignment: Text.AlignHCenter
                            text: gridItem.modelData.name
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: Appearance.colors.colOnLayer1
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                        Item { Layout.fillHeight: true }
                    }
                    StyledToolTip {
                        text: gridItem.modelData.comment || gridItem.modelData.genericName || gridItem.modelData.name
                    }
                }
            }

            StyledListView {
                id: list
                anchors.fill: parent
                visible: root.listView
                clip: true
                spacing: 2
                popin: false
                animateAppearance: false
                model: root.listView ? root.apps : []
                delegate: ColumnLayout {
                    id: listItem
                    required property var modelData
                    required property int index
                    readonly property string letter: root.letterOf(modelData)
                    readonly property bool firstOfLetter: index === 0 || root.letterOf(root.apps[index - 1]) !== letter
                    width: list.width
                    spacing: 2

                    StyledText {
                        visible: listItem.firstOfLetter
                        Layout.leftMargin: 12
                        Layout.topMargin: listItem.index === 0 ? 0 : 8
                        text: listItem.letter
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.DemiBold
                        color: Appearance.colors.colPrimary
                    }

                    RippleButton {
                        Layout.fillWidth: true
                        implicitHeight: 52
                        buttonRadius: Appearance.rounding.normal
                        onClicked: root.launch(listItem.modelData)
                        contentItem: RowLayout {
                            spacing: 12
                            IconImage {
                                Layout.leftMargin: 10
                                implicitSize: 32
                                source: SystemAppearance.iconPath(listItem.modelData.icon, "image-missing")
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0
                                StyledText {
                                    Layout.fillWidth: true
                                    text: listItem.modelData.name
                                    color: Appearance.colors.colOnLayer1
                                    elide: Text.ElideRight
                                }
                                StyledText {
                                    Layout.fillWidth: true
                                    visible: text.length > 0
                                    text: listItem.modelData.genericName || listItem.modelData.comment || ""
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    color: Appearance.colors.colSubtext
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
            }

            StyledText {
                anchors.centerIn: parent
                visible: root.apps.length === 0
                text: Translation.tr("No apps found")
                color: Appearance.colors.colSubtext
            }
        }
    }
}
