import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

/**
 * Popup dialog for configuring Wallhaven search filters.
 * Used within the wallpaper selector when Wallhaven mode is active.
 * Filters are laid out as an even 2x3 grid (left: combos, right: toggles)
 * so the dialog stays compact, wide and aligned instead of tall.
 */
WindowDialog {
    id: root
    backgroundWidth: 620

    // Becomes true when a filter is changed while the menu is open.
    // The actual search is deferred until the menu closes (see WallhavenSearchGrid's onDismiss).
    property bool dirty: false

    // Combos fire a spurious currentIndexChanged during construction (before bindings settle);
    // ignore it so opening the menu alone doesn't mark the filters as changed.
    property bool ready: false
    Component.onCompleted: Qt.callLater(() => root.ready = true)

    // Force both grid columns to the same width so combos/chips align evenly.
    readonly property real cellWidth: (root.backgroundWidth - 2 * Appearance.rounding.large - 16) / 2

    WindowDialogTitle {
        text: Translation.tr("Wallhaven Settings")
    }

    WindowDialogSeparator {}

    readonly property bool isToplist: sortingCombo.sortKeys[sortingCombo.currentIndex] === "toplist"

    GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: 16
        rowSpacing: 12

        // Left column — combos
        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: root.cellWidth
            spacing: 12

            // Sort by
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                StyledText {
                    text: Translation.tr("Sort by")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                }

                StyledComboBox {
                    id: sortingCombo
                    Layout.fillWidth: true
                    model: [
                        Translation.tr("Date Added"),
                        Translation.tr("Relevance"),
                        Translation.tr("Random"),
                        Translation.tr("Views"),
                        Translation.tr("Favorites"),
                        Translation.tr("Top List"),
                        Translation.tr("Hot"),
                    ]
                    property var sortKeys: ["date_added", "relevance", "random", "views", "favorites", "toplist", "hot"]
                    currentIndex: sortKeys.indexOf(WallhavenSearch.sorting)
                    onCurrentIndexChanged: {
                        if (!root.ready || currentIndex < 0) return
                        if (sortKeys[currentIndex] === WallhavenSearch.sorting) return
                        WallhavenSearch.sorting = sortKeys[currentIndex]
                        root.dirty = true
                    }
                }
            }

            // Top Range (only for toplist)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                visible: root.isToplist

                StyledText {
                    text: Translation.tr("Top Range")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                }

                StyledComboBox {
                    Layout.fillWidth: true
                    model: [
                        Translation.tr("1 Day"),
                        Translation.tr("3 Days"),
                        Translation.tr("1 Week"),
                        Translation.tr("1 Month"),
                        Translation.tr("3 Months"),
                        Translation.tr("6 Months"),
                        Translation.tr("1 Year"),
                    ]
                    property var topRangeKeys: ["1d", "3d", "1w", "1m", "3m", "6m", "1y"]
                    currentIndex: topRangeKeys.indexOf(WallhavenSearch.topRange)
                    onCurrentIndexChanged: {
                        if (!root.ready || currentIndex < 0) return
                        if (topRangeKeys[currentIndex] === WallhavenSearch.topRange) return
                        WallhavenSearch.topRange = topRangeKeys[currentIndex]
                        root.dirty = true
                    }
                }
            }

            // Order
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                visible: sortingCombo.currentIndex !== 2 // Hide for "random"

                StyledText {
                    text: Translation.tr("Order")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                }

                StyledComboBox {
                    Layout.fillWidth: true
                    model: [Translation.tr("Descending"), Translation.tr("Ascending")]
                    property var orderKeys: ["desc", "asc"]
                    currentIndex: orderKeys.indexOf(WallhavenSearch.order)
                    onCurrentIndexChanged: {
                        if (!root.ready || currentIndex < 0) return
                        if (orderKeys[currentIndex] === WallhavenSearch.order) return
                        WallhavenSearch.order = orderKeys[currentIndex]
                        root.dirty = true
                    }
                }
            }

            // Ratio
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                StyledText {
                    text: Translation.tr("Ratio")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                }

                StyledComboBox {
                    Layout.fillWidth: true
                    model: [
                        Translation.tr("Any"),
                        "16x9", "16x10", "21x9", "32x9",
                        "9x16", "10x16",
                        "1x1", "3x2", "4x3", "5x4",
                    ]
                    property var ratioKeys: ["", "16x9", "16x10", "21x9", "32x9", "9x16", "10x16", "1x1", "3x2", "4x3", "5x4"]
                    currentIndex: Math.max(0, ratioKeys.indexOf(WallhavenSearch.ratios))
                    onCurrentIndexChanged: {
                        if (!root.ready || currentIndex < 0) return
                        if (ratioKeys[currentIndex] === WallhavenSearch.ratios) return
                        WallhavenSearch.ratios = ratioKeys[currentIndex]
                        root.dirty = true
                    }
                }
            }
        }

        // Right column — toggles & text fields
        ColumnLayout {
            Layout.fillWidth: true
            Layout.minimumWidth: root.cellWidth
            spacing: 12

            // Categories
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                StyledText {
                    text: Translation.tr("Categories")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 6

                    RippleButton {
                        implicitHeight: 32
                        buttonRadius: height / 2
                        leftPadding: 14
                        rightPadding: 14
                        toggled: WallhavenSearch.categories.charAt(0) === "1"
                        colBackgroundToggled: Appearance.colors.colPrimary
                        onClicked: {
                            var cats = WallhavenSearch.categories
                            WallhavenSearch.categories = (cats.charAt(0) === "1" ? "0" : "1") + cats.charAt(1) + cats.charAt(2)
                            root.dirty = true
                        }
                        contentItem: StyledText {
                            text: Translation.tr("General")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: parent.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                        }
                    }

                    RippleButton {
                        implicitHeight: 32
                        buttonRadius: height / 2
                        leftPadding: 14
                        rightPadding: 14
                        toggled: WallhavenSearch.categories.charAt(1) === "1"
                        colBackgroundToggled: Appearance.colors.colPrimary
                        onClicked: {
                            var cats = WallhavenSearch.categories
                            WallhavenSearch.categories = cats.charAt(0) + (cats.charAt(1) === "1" ? "0" : "1") + cats.charAt(2)
                            root.dirty = true
                        }
                        contentItem: StyledText {
                            text: Translation.tr("Anime")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: parent.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                        }
                    }

                    RippleButton {
                        implicitHeight: 32
                        buttonRadius: height / 2
                        leftPadding: 14
                        rightPadding: 14
                        toggled: WallhavenSearch.categories.charAt(2) === "1"
                        colBackgroundToggled: Appearance.colors.colPrimary
                        onClicked: {
                            var cats = WallhavenSearch.categories
                            WallhavenSearch.categories = cats.charAt(0) + cats.charAt(1) + (cats.charAt(2) === "1" ? "0" : "1")
                            root.dirty = true
                        }
                        contentItem: StyledText {
                            text: Translation.tr("People")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: parent.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                        }
                    }
                }
            }

            // Purity
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                StyledText {
                    text: Translation.tr("Purity")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                }

                Flow {
                    Layout.fillWidth: true
                    spacing: 6

                    RippleButton {
                        implicitHeight: 32
                        buttonRadius: height / 2
                        leftPadding: 14
                        rightPadding: 14
                        toggled: WallhavenSearch.purity.charAt(0) === "1"
                        colBackgroundToggled: Appearance.colors.colPrimary
                        onClicked: {
                            var p = WallhavenSearch.purity
                            WallhavenSearch.purity = (p.charAt(0) === "1" ? "0" : "1") + p.charAt(1) + p.charAt(2)
                            root.dirty = true
                        }
                        contentItem: StyledText {
                            text: "SFW"
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: parent.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                        }
                    }

                    RippleButton {
                        implicitHeight: 32
                        buttonRadius: height / 2
                        leftPadding: 14
                        rightPadding: 14
                        toggled: WallhavenSearch.purity.charAt(1) === "1"
                        colBackgroundToggled: Appearance.colors.colPrimary
                        onClicked: {
                            var p = WallhavenSearch.purity
                            WallhavenSearch.purity = p.charAt(0) + (p.charAt(1) === "1" ? "0" : "1") + p.charAt(2)
                            root.dirty = true
                        }
                        contentItem: StyledText {
                            text: Translation.tr("Sketchy")
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: parent.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                        }
                    }

                    RippleButton {
                        visible: WallhavenSearch.apiKey.length > 0
                        implicitHeight: 32
                        buttonRadius: height / 2
                        leftPadding: 14
                        rightPadding: 14
                        toggled: WallhavenSearch.purity.charAt(2) === "1"
                        colBackgroundToggled: Appearance.m3colors.m3error
                        onClicked: {
                            var p = WallhavenSearch.purity
                            WallhavenSearch.purity = p.charAt(0) + p.charAt(1) + (p.charAt(2) === "1" ? "0" : "1")
                            root.dirty = true
                        }
                        contentItem: StyledText {
                            text: "NSFW"
                            font.pixelSize: Appearance.font.pixelSize.smaller
                            color: parent.toggled ? Appearance.colors.colOnPrimary : Appearance.colors.colOnLayer1
                        }
                    }
                }
            }

            // API Key
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                StyledText {
                    text: Translation.tr("API Key")
                    font.pixelSize: Appearance.font.pixelSize.small
                    color: Appearance.colors.colSubtext
                }

                TextField {
                    id: apiKeyField
                    Layout.fillWidth: true
                    echoMode: TextInput.Password
                    placeholderText: Translation.tr("Optional — needed for NSFW")
                    placeholderTextColor: Appearance.colors.colSubtext
                    color: Appearance.colors.colOnLayer1
                    text: WallhavenSearch.apiKey
                    font {
                        family: Appearance.font.family.main
                        pixelSize: Appearance.font.pixelSize.small
                        hintingPreference: Font.PreferFullHinting
                    }
                    renderType: Text.NativeRendering
                    background: Rectangle {
                        color: Appearance.colors.colLayer1
                        radius: Appearance.rounding.small
                        border.width: 1
                        border.color: apiKeyField.activeFocus ? Appearance.colors.colPrimary : Appearance.colors.colLayer0Border
                    }
                    onEditingFinished: {
                        WallhavenSearch.apiKey = text
                        WallhavenSearch.saveToConfig()
                    }
                }
            }
        }
    }
}