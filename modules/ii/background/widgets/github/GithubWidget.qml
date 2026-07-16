import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.modules.common.widgets.widgetCanvas
import qs.modules.ii.background.widgets

AbstractBackgroundWidget {
    id: root
    configEntryName: "github"
    hoverEnabled: true

    property string contributionCount: "0"
    property var contributions: []
    property bool loading: true
    
    property string hoveredDate: ""
    property string hoveredInfo: ""
    property int hoveredLevel: -1

    implicitWidth: 612
    implicitHeight: 148

    function getHoveredTitle() {
        if (root.hoveredInfo === "") return "";
        var parts = root.hoveredInfo.split(" on ");
        return parts[0];
    }

    function getHoveredSubtitle() {
        if (root.hoveredInfo === "") return "";
        var parts = root.hoveredInfo.split(" on ");
        var sub = parts[1] || "";
        if (sub.endsWith(".")) {
            sub = sub.slice(0, -1);
        }
        return sub;
    }

    function getColorForLevel(level) {
        switch (level) {
            case 1:
                return "#0e4429"
            case 2:
                return "#006d32"
            case 3:
                return "#26a641"
            case 4:
                return "#39d353"
            default:
                // Level 0 or fallback: subtle greyish outline mixed with the container background
                return ColorUtils.mix(Appearance.colors.colOnPrimaryContainer, Appearance.colors.colPrimaryContainer, 0.08)
        }
    }

    function fetchContributions() {
        if (!root.configEntry) return;
        root.loading = true;
        
        var xhr = new XMLHttpRequest();
        var url = "https://github.com/users/" + root.configEntry.username + "/contributions";
        xhr.open("GET", url, true);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    var html = xhr.responseText;
                    
                    // Parse total contributions
                    var countMatch = html.match(/js-contribution-activity-description"[^>]*>\s*([\d,]+)\s*contributions/);
                    if (countMatch) {
                        root.contributionCount = countMatch[1];
                    } else {
                        var countMatchAlt = html.match(/(\d+)\s+contributions\s+in\s+the\s+last\s+year/i);
                        if (countMatchAlt) {
                            root.contributionCount = countMatchAlt[1];
                        }
                    }

                    // Parse tooltips into a map of id -> description
                    var tooltipMap = {};
                    var tooltipMatches = html.match(/<tool-tip[^>]*for="([^"]*)"[^>]*>([^<]*)<\/tool-tip>/g);
                    if (tooltipMatches) {
                        var tooltipRegex = /<tool-tip[^>]*for="([^"]*)"[^>]*>([^<]*)<\/tool-tip>/;
                        for (var j = 0; j < tooltipMatches.length; j++) {
                            var tm = tooltipMatches[j].match(tooltipRegex);
                            if (tm) {
                                tooltipMap[tm[1]] = tm[2].trim();
                            }
                        }
                    }

                    // Parse td elements
                    var tdMatches = html.match(/<td[^>]*class="[^"]*ContributionCalendar-day[^"]*"[^>]*>/g);
                    if (tdMatches) {
                        var parsedData = [];
                        for (var i = 0; i < tdMatches.length; i++) {
                            var td = tdMatches[i];
                            var dateMatch = td.match(/data-date="([^"]*)"/);
                            var levelMatch = td.match(/data-level="([0-9])"/);
                            var idMatch = td.match(/id="([^"]*)"/);
                            
                            if (dateMatch && levelMatch) {
                                var date = dateMatch[1];
                                var level = parseInt(levelMatch[1]);
                                var id = idMatch ? idMatch[1] : "";
                                var info = tooltipMap[id] || (level + " contributions on " + date);
                                
                                parsedData.push({
                                    date: date,
                                    level: level,
                                    info: info
                                });
                            }
                        }
                        root.contributions = parsedData;
                        root.loading = false;
                    }
                } else {
                    console.log("[GitHub Heatmap] Fetch failed with status:", xhr.status);
                    root.loading = false;
                }
            }
        };
        xhr.send();
    }

    property string currentUsername: root.configEntry?.username ?? ""
    onCurrentUsernameChanged: {
        if (currentUsername !== "") {
            fetchContributions();
        }
    }

    Component.onCompleted: {
        fetchContributions();
    }

    Timer {
        id: refreshTimer
        interval: 3600000 // Refresh hourly
        running: true
        repeat: true
        onTriggered: fetchContributions()
    }

    Rectangle {
        id: card
        anchors.fill: parent
        radius: Appearance.rounding?.verylarge ?? 30
        color: Appearance.colors.colPrimaryContainer

        StyledRectangularShadow {
            target: card
            z: -2
        }

        ColumnLayout {
            anchors {
                fill: parent
                margins: 14
            }
            spacing: 8

            // Header Section
            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                MaterialShapeWrappedMaterialSymbol {
                    wrappedShape: MaterialShape.Shape.Cookie4Sided
                    color: Appearance.colors.colPrimary
                    colSymbol: Appearance.colors.colOnPrimary
                    text: "code"
                    iconSize: 20
                    fill: 1
                    padding: 6
                    implicitWidth: 32
                    implicitHeight: 32
                }

                ColumnLayout {
                    spacing: -2
                    Layout.fillWidth: true

                    StyledText {
                        text: root.hoveredDate !== ""
                            ? root.getHoveredTitle()
                            : "@" + root.configEntry.username
                        font.pixelSize: Appearance.font.pixelSize.normal
                        font.weight: Font.Bold
                        color: Appearance.colors.colOnPrimaryContainer
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }

                    StyledText {
                        text: root.hoveredDate !== ""
                            ? root.getHoveredSubtitle()
                            : (root.loading ? "Fetching latest data..." : root.contributionCount + " contributions this year")
                        font.pixelSize: Appearance.font.pixelSize.smallest
                        color: Appearance.colors.colOnPrimaryContainer
                        opacity: 0.6
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }
            }

            // Heatmap Grid Section
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                MaterialLoadingIndicator {
                    anchors.centerIn: parent
                    visible: root.loading
                    loading: root.loading
                }

                Grid {
                    id: grid
                    anchors.centerIn: parent
                    columns: 53
                    rows: 7
                    rowSpacing: 3
                    columnSpacing: 3
                    visible: !root.loading

                    Repeater {
                        model: root.contributions
                        delegate: Rectangle {
                            required property var modelData
                            width: 8
                            height: 8
                            radius: 2
                            color: root.getColorForLevel(modelData.level)

                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: {
                                    root.hoveredDate = modelData.date;
                                    root.hoveredInfo = modelData.info;
                                    root.hoveredLevel = modelData.level;
                                }
                                onExited: {
                                    root.hoveredDate = "";
                                    root.hoveredInfo = "";
                                    root.hoveredLevel = -1;
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
