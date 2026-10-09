import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

Item {
    id: root

    required property Item pager
    property int staggerMs: 45
    readonly property string query: pager.searchQuery ?? ""

    readonly property real rowHeight: 140
    readonly property real headerHeight: 36
    readonly property real gap: 12

    readonly property var shapePool: [
        MaterialShape.Shape.Cookie6Sided, MaterialShape.Shape.Gem, MaterialShape.Shape.Pentagon,
        MaterialShape.Shape.Flower, MaterialShape.Shape.Puffy, MaterialShape.Shape.Clover8Leaf, MaterialShape.Shape.Sunny
    ]

    DashboardSettingsCatalog {
        id: catalog
    }

    readonly property string group: GlobalStates.dashboardGroup

    readonly property var groupDefs: {
        const c = Appearance.colors;
        const mix = (a, b) => ColorUtils.mix(a, b, 0.5);
        return [
            { name: Translation.tr("General"), icon: "browse", container: mix(c.colPrimaryContainer, c.colTertiaryContainer), onContainer: mix(c.colOnPrimaryContainer, c.colOnTertiaryContainer), accent: mix(c.colPrimary, c.colTertiary), onAccent: mix(c.colOnPrimary, c.colOnTertiary) },
            { name: Translation.tr("Interface"), icon: "bottom_app_bar", container: c.colPrimaryContainer, onContainer: c.colOnPrimaryContainer, accent: c.colPrimary, onAccent: c.colOnPrimary },
            { name: Translation.tr("Bar"), icon: "toast", rotation: 180, container: c.colSecondaryContainer, onContainer: c.colOnSecondaryContainer, accent: c.colSecondary, onAccent: c.colOnSecondary },
            { name: Translation.tr("Desktop"), icon: "texture", container: c.colTertiaryContainer, onContainer: c.colOnTertiaryContainer, accent: c.colTertiary, onAccent: c.colOnTertiary },
            { name: Translation.tr("Hyprland"), icon: "select_window_2", container: mix(c.colPrimaryContainer, c.colSecondaryContainer), onContainer: mix(c.colOnPrimaryContainer, c.colOnSecondaryContainer), accent: mix(c.colPrimary, c.colSecondary), onAccent: mix(c.colOnPrimary, c.colOnSecondary) },
            { name: Translation.tr("Services"), icon: "settings", container: mix(c.colSecondaryContainer, c.colTertiaryContainer), onContainer: mix(c.colOnSecondaryContainer, c.colOnTertiaryContainer), accent: mix(c.colSecondary, c.colTertiary), onAccent: mix(c.colOnSecondary, c.colOnTertiary) }
        ];
    }

    readonly property var groupColors: {
        const found = groupDefs.find(g => g.name === group);
        return found ?? { container: Appearance.m3colors.m3surfaceContainerHighest, onContainer: Appearance.m3colors.m3onSurface, accent: Appearance.m3colors.m3onSurface, onAccent: Appearance.m3colors.m3surface };
    }

    readonly property var matchedGroups: {
        const set = {};
        if (tokens.length > 0) matches(tokens).forEach(e => { set[e.group] = true; });
        return set;
    }

    readonly property var railGroups: [Object.assign({ id: "", count: 0 }, {
        name: Translation.tr("All"), icon: "apps",
        container: Appearance.m3colors.m3surfaceContainerHighest, onContainer: Appearance.m3colors.m3onSurface,
        accent: Appearance.m3colors.m3onSurface, onAccent: Appearance.m3colors.m3surface
    })].concat(groupDefs.map(g => Object.assign({ id: g.name, count: allEntries.filter(e => e.kind === "card" && e.group === g.name && isVisibleEntry(e)).length }, g)))

    readonly property var railDimmed: {
        const dim = {};
        if (tokens.length > 0) railGroups.forEach(g => { if (g.id !== "") dim[g.id] = !matchedGroups[g.id]; });
        return dim;
    }

    readonly property var groupSections: {
        if (group === "" || tokens.length > 0) return [];
        const list = [];
        catalog.sections.forEach((section, si) => {
            if ((section.page ?? "") === group && isVisibleEntry({ requires: section.requires ?? "", when: section.when ?? "" }))
                list.push({ index: si, title: section.title });
        });
        return list;
    }

    function spanOf(entry) {
        return entry.w ? [entry.w, 1] : baseSpan(entry.type);
    }

    function baseSpan(type) {
        if (type === "style") return [2, 2];
        if (type === "schemes" || type === "barpos") return [2, 2];
        if (type === "weathermap") return [4, 2];
        if (type === "collagelayouts") return [4, 2];
        if (type === "timepreview") return [3, 2];
        if (type === "widgets") return [4, 3];
        if (type === "shape") return [2, 2];
        if (type === "barlayout") return [4, 3];
        if (type === "displays") return [4, 4];
        if (type === "palette") return [4, 1];
        if (type === "iconpicker") return [2, 2];
        if (type === "toggle" || type === "spin") return [1, 1];
        return [2, 1];
    }

    readonly property var heroEntries: [
        { id: "hero:style", type: "style", title: Translation.tr("Settings panel style"), section: Translation.tr("Interface"), kw: "settings panel style default minimal dashboard window overlay" },
        { id: "hero:blur", type: "toggle", key: "desktop:Blur wall", title: Translation.tr("Blur wallpaper"), icon: "blur_on", section: Translation.tr("Desktop"), kw: "blur wallpaper background" },
        { id: "hero:transparency", type: "toggle", key: "interface:Transparency/Enable", title: Translation.tr("Transparency"), icon: "opacity", section: Translation.tr("Interface"), kw: "transparency opacity" },
        { id: "hero:collage", type: "toggle", key: "desktop:Collage enable", title: Translation.tr("Multiple wallpapers"), icon: "grid_view", section: Translation.tr("Desktop"), kw: "multiple wallpapers collage tiles" },
        { id: "hero:centered", type: "toggle", key: "desktop:Wallpaper/Centered wallpaper/Enable", title: Translation.tr("Centered wallpaper"), icon: "filter_center_focus", section: Translation.tr("Desktop"), kw: "centered wallpaper" },
        { id: "hero:schemes", type: "schemes", title: Translation.tr("Color scheme"), section: Translation.tr("Interface"), kw: "color scheme theme palette accent catppuccin gruvbox nord dracula tokyo everforest one dark" },
        { id: "hero:uibg", type: "select", w: 2, key: "interface:UI background", title: Translation.tr("UI background"), icon: "format_color_fill", section: Translation.tr("Interface"), kw: "ui background oled black amoled themed dark surface layer panels sidebars" },
        { id: "hero:palette", type: "palette", when: "material", key: "interface:Palette type", title: Translation.tr("Palette style"), icon: "auto_awesome", section: Translation.tr("Interface"), kw: "palette style scheme auto content expressive fidelity fruit salad monochrome neutral rainbow tonal spot material you dynamic" },
        { id: "hero:barpos", type: "barpos", title: Translation.tr("Bar position"), section: Translation.tr("Bar"), kw: "bar position top bottom left right vertical panel" },
        { id: "hero:tooltips", type: "toggle", w: 2, searchable: true, key: "bar:Tooltips/Enable", title: Translation.tr("Tooltips"), icon: "tooltip", section: Translation.tr("Bar"), kw: "bar tooltips enable hover" },
        { id: "hero:tooltipsClick", type: "toggle", w: 2, searchable: true, key: "bar:Click to show", title: Translation.tr("Click to show"), icon: "ads_click", section: Translation.tr("Bar"), kw: "bar tooltips click to show" },
        { id: "hero:tooltipsStyle", type: "select", w: 4, searchable: true, key: "bar:Tooltips/Style", title: Translation.tr("Tooltip style"), icon: "tooltip", section: Translation.tr("Bar"), kw: "bar tooltips style morph attached popup" }
    ]

    readonly property var allEntries: {
        const list = [];
        heroEntries.forEach(e => list.push(Object.assign({ kind: "card", hero: true, group: e.section }, e)));
        catalog.sections.forEach((section, si) => {
            list.push({ id: "section:" + si, kind: "header", requires: section.requires ?? "", when: section.when ?? "", title: section.title, icon: section.icon, page: section.page ?? "", group: section.page ?? "", section: section.title, sectionIndex: si, count: section.cards.length });
            section.cards.forEach(card => list.push(Object.assign({
                id: card.key, kind: "card", requires: section.requires ?? "", when: section.when ?? "", group: section.page ?? "", section: section.title, sectionIndex: si, kw: card.kw ?? ""
            }, card)));
        });
        const heroGroups = {};
        heroEntries.forEach(e => { heroGroups[e.section] = (heroGroups[e.section] ?? 0) + 1; });
        Object.keys(heroGroups).forEach(name => list.push({
            id: "hsection:" + name, kind: "header", searchOnly: true, requires: "",
            title: name, icon: name === "Desktop" ? "texture" : name === "Bar" ? "toast" : "bottom_app_bar",
            page: name, group: name, section: name, count: heroGroups[name]
        }));
        return list.map(e => Object.assign(e, {
            shape: shapePool[Math.floor(Math.random() * shapePool.length)],
            travelX: (Math.random() - 0.5) * 500,
            travelY: (Math.random() - 0.5) * 400
        }));
    }

    readonly property var usedWidgets: {
        const layouts = Config.options.bar.layouts;
        return Array.from(layouts.leftLayout).concat(Array.from(layouts.middleLayout), Array.from(layouts.rightLayout));
    }

    function isVisibleEntry(e) {
        if (e.when === "material" && ColorSchemes.current !== "") return false;
        if (e.when === "hyprland" && WM.compositor !== "hyprland") return false;
        if (e.when === "layoutdwindle" && (WM.compositor !== "hyprland" || Config.options.hyprland.general.layout !== "dwindle")) return false;
        if (e.when === "layoutmaster" && (WM.compositor !== "hyprland" || Config.options.hyprland.general.layout !== "master")) return false;
        if (e.when === "hyprbordercolor" && (WM.compositor !== "hyprland" || !Config.options.hyprland.general.borderColor.enable)) return false;
        if (e.when === "dockhug" && Config.options.dock.style !== "hug") return false;
        if (e.when === "dockfloat" && Config.options.dock.style === "hug") return false;
        if (e.when === "clockdigital" && Config.options.background.widgets.clock.style !== "digital") return false;
        if (e.when === "clockcookie" && Config.options.background.widgets.clock.style !== "cookie") return false;
        if (e.when === "clockpixel" && Config.options.background.widgets.clock.style !== "pixel") return false;
        return !e.requires || usedWidgets.includes(e.requires);
    }

    function normalized(text) {
        return Wallpapers.normalizeText(text).replace(/[_\-.:/]+/g, " ");
    }

    function matches(tokens) {
        const scored = [];
        allEntries.forEach(e => {
            if (e.kind !== "card" || (e.hero && e.type === "toggle" && !e.searchable) || !isVisibleEntry(e)) return;
            const key = normalized([e.title, e.section, e.kw, e.key ?? ""].join(" "));
            const score = Wallpapers.scoreItem(key, tokens);
            if (score < 0) return;
            const sectionScore = Wallpapers.scoreItem(normalized(e.section ?? ""), tokens);
            scored.push({ entry: e, score: sectionScore >= 0 ? score + 1000 : score });
        });
        scored.sort((a, b) => b.score - a.score);
        return scored.map(s => s.entry);
    }

    function isEnableCard(card) {
        return card.type === "toggle" && !card.keepOrder && card.title === Translation.tr("Enable");
    }

    function packRows(allCards, capacity) {
        const enables = allCards.filter(c => isEnableCard(c));
        const cards = allCards.filter(c => !isEnableCard(c));
        const fulls = cards.filter(c => spanOf(c)[0] === 4);
        const wides = cards.filter(c => spanOf(c)[0] === 2);
        const allSmalls = cards.filter(c => spanOf(c)[0] === 1);
        const tall = cards.filter(c => spanOf(c)[0] === 3);
        const side = tall.length > 0 ? allSmalls.slice(0, 2) : [];
        const smalls = allSmalls.slice(side.length);
        const placed = [];
        enables.forEach(card => placed.push({ entry: card, w: 1, h: 1 }));
        tall.forEach(card => placed.push({ entry: card, w: 3, h: spanOf(card)[1] }));
        side.forEach(card => placed.push({ entry: card, w: 1, h: 1 }));
        let remaining = capacity;
        let rowStart = placed.length;
        const ghosts = wides.length === 0 ? enables.map(() => ({ ghost: true })) : [];
        fulls.concat(ghosts, wides, smalls).forEach(card => {
            const span = card.ghost ? 1 : spanOf(card)[0];
            if (span > remaining) {
                remaining = capacity;
                rowStart = placed.length;
            }
            if (!card.ghost) placed.push({ entry: card, w: span, h: spanOf(card)[1] });
            remaining -= span;
            if (remaining === 0) {
                remaining = capacity;
                rowStart = placed.length;
            }
        });
        let leftover = remaining === capacity ? 0 : remaining;
        let i = placed.length - 1;
        while (leftover > 0 && i >= rowStart) {
            placed[i].w += 1;
            leftover--;
            i = i === rowStart ? placed.length - 1 : i - 1;
        }
        return placed;
    }

    function computeLayout(tokens) {
        const items = [];
        if (tokens.length > 0) {
            const groups = {};
            const order = [];
            matches(tokens).forEach(e => {
                const groupId = e.sectionIndex !== undefined ? "section:" + e.sectionIndex : "hsection:" + e.section;
                if (!groups[groupId]) {
                    groups[groupId] = [];
                    order.push(groupId);
                }
                groups[groupId].push(e);
            });
            order.forEach(groupId => {
                const header = allEntries.find(e => e.id === groupId);
                if (header) items.push({ entry: header, w: 4, h: 1, header: true });
                packRows(groups[groupId], 4).forEach(p => items.push(p));
            });
        } else {
            let i = 0;
            while (i < allEntries.length) {
                const e = allEntries[i];
                if (e.searchOnly || !isVisibleEntry(e) || (group !== "" && e.group !== group)) {
                    i++;
                    continue;
                }
                if (e.kind === "header") {
                    items.push({ entry: e, w: 4, h: 1, header: true });
                    const cards = [];
                    i++;
                    while (i < allEntries.length && allEntries[i].kind === "card") {
                        if (isVisibleEntry(allEntries[i])) cards.push(allEntries[i]);
                        i++;
                    }
                    packRows(cards, 4).forEach(p => items.push(p));
                } else {
                    const s = spanOf(e);
                    items.push({ entry: e, w: s[0], h: s[1] });
                    i++;
                }
            }
        }

        const occ = [];
        const rowH = [];
        const map = {};
        let floor = 0;

        function ensure(r) {
            while (occ.length <= r) {
                occ.push([false, false, false, false]);
                rowH.push(rowHeight);
            }
        }

        function fits(r, c, w, h) {
            for (let dr = 0; dr < h; dr++) {
                ensure(r + dr);
                for (let dc = 0; dc < w; dc++)
                    if (occ[r + dr][c + dc]) return false;
            }
            return true;
        }

        items.forEach(it => {
            if (it.header) {
                const r = occ.length;
                ensure(r);
                occ[r] = [true, true, true, true];
                rowH[r] = headerHeight;
                map[it.entry.id] = { col: 0, row: r, w: 4, h: 1, header: true };
                floor = r + 1;
                return;
            }
            let r = floor;
            for (;; r++) {
                let found = -1;
                for (let c = 0; c + it.w <= 4; c++) {
                    if (fits(r, c, it.w, it.h)) {
                        found = c;
                        break;
                    }
                }
                if (found >= 0) {
                    for (let dr = 0; dr < it.h; dr++)
                        for (let dc = 0; dc < it.w; dc++)
                            occ[r + dr][found + dc] = true;
                    map[it.entry.id] = { col: found, row: r, w: it.w, h: it.h };
                    break;
                }
            }
        });

        function free(r, c, w, h) {
            for (let dr = 0; dr < h; dr++)
                for (let dc = 0; dc < w; dc++)
                    if (r + dr >= occ.length || c + dc < 0 || c + dc > 3 || occ[r + dr][c + dc]) return false;
            return true;
        }

        function mark(r, c, w, h) {
            for (let dr = 0; dr < h; dr++)
                for (let dc = 0; dc < w; dc++) occ[r + dr][c + dc] = true;
        }

        Object.keys(map).forEach(id => {
            const p = map[id];
            if (p.header) return;
            while (free(p.row, p.col + p.w, 1, p.h)) {
                mark(p.row, p.col + p.w, 1, p.h);
                p.w++;
            }
            while (free(p.row, p.col - 1, 1, p.h)) {
                mark(p.row, p.col - 1, 1, p.h);
                p.col--;
                p.w++;
            }
            while (free(p.row + p.h, p.col, p.w, 1)) {
                mark(p.row + p.h, p.col, p.w, 1);
                p.h++;
            }
        });

        const rowY = [];
        let y = 0;
        rowH.forEach(h => {
            rowY.push(y);
            y += h + gap;
        });
        Object.keys(map).forEach(id => {
            const p = map[id];
            let height = 0;
            for (let dr = 0; dr < p.h; dr++) height += rowH[p.row + dr] + (dr > 0 ? gap : 0);
            p.y = rowY[p.row];
            p.height = height;
        });
        return { map: map, total: Math.max(0, y - gap), count: items.filter(i => !i.header).length };
    }

    readonly property var tokens: normalized(query).split(/\s+/).filter(t => t.length > 0)
    readonly property var layoutResult: computeLayout(tokens)
    readonly property var layoutMap: layoutResult.map

    onTokensChanged: flick.contentY = 0
    onGroupChanged: flick.contentY = 0

    Component.onCompleted: {
        if (WM.compositor === "hyprland") HyprlandOptions.refresh();
    }

    readonly property int activeSection: {
        if (groupSections.length === 0) return -1;
        const top = flick.contentY + 8;
        const atEnd = flick.contentHeight > flick.height && flick.contentY >= flick.contentHeight - flick.height - 2;
        if (atEnd) return groupSections[groupSections.length - 1].index;
        let best = groupSections[0].index;
        groupSections.forEach(sec => {
            const place = layoutMap["section:" + sec.index];
            if (place && place.y <= top) best = sec.index;
        });
        return best;
    }

    function scrollToSection(index) {
        const place = layoutMap["section:" + index];
        if (place) flick.contentY = Math.max(0, Math.min(place.y, Math.max(0, flick.contentHeight - flick.height)));
    }

    function scrollBy(delta) {
        flick.contentY = Math.max(0, Math.min(Math.max(0, flick.contentHeight - flick.height), flick.contentY + delta));
    }


        DashboardGroupRail {
            id: rail
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: 70
            groups: root.railGroups
            current: root.group
            dimmed: root.railDimmed
            onPicked: id => { GlobalStates.dashboardGroup = id; }
        }

        Flickable {
            id: chipsRow
            anchors.left: rail.right
            anchors.leftMargin: 16
            anchors.right: parent.right
            anchors.top: parent.top
            height: root.groupSections.length > 0 ? 40 : 0
            opacity: root.groupSections.length > 0 ? 1 : 0
            clip: true
            contentWidth: chipsLayout.implicitWidth
            contentHeight: height
            flickableDirection: Flickable.HorizontalFlick
            boundsBehavior: Flickable.StopAtBounds

            WheelHandler {
                enabled: chipsRow.contentWidth > chipsRow.width
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: event => {
                    const delta = Math.abs(event.angleDelta.x) > Math.abs(event.angleDelta.y) ? event.angleDelta.x : event.angleDelta.y;
                    chipsRow.contentX = Math.max(0, Math.min(chipsRow.contentWidth - chipsRow.width, chipsRow.contentX - delta));
                }
            }

            Behavior on height {
                NumberAnimation { duration: 220 / Math.max(0.5, Config.options.settings.animationSpeed ?? 1); easing.type: Easing.OutCubic }
            }

            Behavior on opacity {
                NumberAnimation { duration: 180 }
            }

            RowLayout {
                id: chipsLayout
                height: 34
                spacing: 8

                Repeater {
                    model: root.groupSections

                    delegate: RippleButton {
                        id: chip
                        required property var modelData
                        readonly property bool selected: root.activeSection === modelData.index
                        implicitHeight: 34
                        implicitWidth: chipRow.implicitWidth + 28
                        buttonRadius: 8
                        toggled: selected
                        border: !selected
                        colBackground: "transparent"
                        colBackgroundToggled: Appearance.colors.colSecondaryContainer
                        colBackgroundToggledHover: Appearance.colors.colSecondaryContainerHover
                        colRippleToggled: Appearance.colors.colSecondaryContainerActive
                        onClicked: root.scrollToSection(chip.modelData.index)
                        contentItem: Item {
                            RowLayout {
                                id: chipRow
                                anchors.centerIn: parent
                                spacing: 6

                                MaterialSymbol {
                                    visible: chip.selected
                                    text: "check"
                                    iconSize: Appearance.font.pixelSize.larger
                                    color: Appearance.colors.colOnSecondaryContainer
                                }

                                StyledText {
                                    text: chip.modelData.title
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    font.weight: Font.Medium
                                    color: chip.selected ? Appearance.colors.colOnSecondaryContainer : Appearance.colors.colOnSurfaceVariant
                                }
                            }
                        }
                    }
                }
            }
        }

        Flickable {
            id: flick
            anchors.left: rail.right
            anchors.leftMargin: 16
            anchors.right: parent.right
            anchors.top: chipsRow.bottom
            anchors.topMargin: root.groupSections.length > 0 ? 8 : 0
            anchors.bottom: parent.bottom
            clip: true
            contentWidth: width
            contentHeight: root.layoutResult.total
            boundsBehavior: Flickable.StopAtBounds
            flickDeceleration: 4000
            maximumFlickVelocity: 2500

            Behavior on contentY {
                enabled: !flick.moving && !flick.dragging
                NumberAnimation { duration: 180; easing.type: Easing.OutCubic }
            }

            Item {
                id: canvas
                width: flick.width
                height: root.layoutResult.total

                Repeater {
                    model: root.allEntries

                    delegate: Loader {
                        id: slot
                        required property int index
                        required property var modelData

                        readonly property var place: root.layoutMap[modelData.id] ?? null
                        property var lastPlace: null
                        property bool ready: false
                        readonly property var shown: place ?? lastPlace
                        readonly property real colW: (canvas.width - root.gap * 3) / 4
                        readonly property bool inView: place !== null
                            && place.y + place.height > flick.contentY - 240
                            && place.y < flick.contentY + flick.height + 240

                        onPlaceChanged: {
                            if (place) lastPlace = place;
                        }
                        Component.onCompleted: Qt.callLater(() => { ready = true; })

                        x: shown ? shown.col * (colW + root.gap) : 0
                        y: shown ? shown.y : 0
                        width: shown ? shown.w * colW + (shown.w - 1) * root.gap : 0
                        height: shown ? shown.height : 0
                        opacity: place ? 1 : 0
                        scale: place ? 1 : 0.6
                        visible: opacity > 0.01

                        Behavior on x { enabled: slot.ready; SpringAnimation { spring: 3.2; damping: 0.28 } }
                        Behavior on y { enabled: slot.ready; SpringAnimation { spring: 3.2; damping: 0.28 } }
                        Behavior on width { enabled: slot.ready; SpringAnimation { spring: 3.2; damping: 0.28 } }
                        Behavior on height { enabled: slot.ready; SpringAnimation { spring: 3.2; damping: 0.28 } }
                        Behavior on opacity { enabled: slot.ready; NumberAnimation { duration: 180 } }
                        Behavior on scale { enabled: slot.ready; SpringAnimation { spring: 3.2; damping: 0.3 } }

                        active: place !== null && (modelData.kind === "header" || inView)
                        sourceComponent: modelData.kind === "header" ? headerComponent
                            : modelData.type === "style" ? styleComponent
                            : modelData.type === "schemes" ? schemesComponent
                            : modelData.type === "barpos" ? barposComponent
                            : modelData.type === "toggle" ? toggleComponent
                            : modelData.type === "slider" ? sliderComponent
                            : modelData.type === "spin" ? spinComponent
                            : modelData.type === "combo" ? comboComponent
                            : modelData.type === "text" ? textComponent
                            : modelData.type === "swatch" ? swatchComponent
                            : modelData.type === "shape" ? shapeComponent
                            : modelData.type === "barlayout" ? barLayoutComponent
                            : modelData.type === "displays" ? displaysComponent
                            : modelData.type === "palette" ? paletteComponent
                            : modelData.type === "duration" ? durationComponent
                            : modelData.type === "iconpicker" ? iconPickerComponent
                            : modelData.type === "timepreview" ? timePreviewComponent
                            : modelData.type === "collagelayouts" ? collageLayoutsComponent
                            : modelData.type === "weathermap" ? weatherMapComponent
                            : modelData.type === "widgets" ? widgetsComponent
                            : selectComponent

                        Component {
                            id: headerComponent

                            RowLayout {
                                anchors.fill: parent
                                spacing: 10

                                Rectangle {
                                    radius: height / 2
                                    color: Appearance.colors.colPrimaryContainer
                                    implicitHeight: 32
                                    implicitWidth: headerChip.implicitWidth + 22

                                    RowLayout {
                                        id: headerChip
                                        anchors.centerIn: parent
                                        spacing: 8

                                        MaterialSymbol {
                                            text: slot.modelData.icon
                                            iconSize: 18
                                            fill: 1
                                            color: Appearance.colors.colOnPrimaryContainer
                                        }
                                        StyledText {
                                            text: slot.modelData.title
                                            font.pixelSize: Appearance.font.pixelSize.normal
                                            font.weight: Font.DemiBold
                                            color: Appearance.colors.colOnPrimaryContainer
                                        }
                                    }
                                }

                                StyledText {
                                    text: slot.modelData.count
                                    font.pixelSize: Appearance.font.pixelSize.small
                                    color: Appearance.colors.colSubtext
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    implicitHeight: 2
                                    radius: 1
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0; color: Appearance.colors.colPrimary }
                                        GradientStop { position: 0.35; color: Appearance.colors.colOutlineVariant }
                                        GradientStop { position: 1; color: "transparent" }
                                    }
                                }

                                StyledText {
                                    visible: slot.modelData.page !== ""
                                    text: slot.modelData.page.toUpperCase()
                                    font.pixelSize: Appearance.font.pixelSize.smaller
                                    font.weight: Font.Bold
                                    font.letterSpacing: 1.5
                                    color: Appearance.colors.colSubtext
                                    opacity: 0.7
                                }
                            }
                        }

                        Component {
                            id: styleComponent
                            DashboardStyleCard {
                                anchors.fill: parent
                                pager: root.pager
                                staggerMs: root.staggerMs
                                animIndex: slot.index % 6
                                travelX: slot.modelData.travelX
                                travelY: slot.modelData.travelY
                            }
                        }

                        Component {
                            id: schemesComponent
                            DashboardSchemeCard {
                                anchors.fill: parent
                                pager: root.pager
                                staggerMs: root.staggerMs
                                animIndex: slot.index % 6
                                travelX: slot.modelData.travelX
                                travelY: slot.modelData.travelY
                            }
                        }

                        Component {
                            id: barposComponent
                            DashboardBarPositionCard {
                                anchors.fill: parent
                                pager: root.pager
                                staggerMs: root.staggerMs
                                animIndex: slot.index % 6
                                travelX: slot.modelData.travelX
                                travelY: slot.modelData.travelY
                            }
                        }

                        Component {
                            id: toggleComponent
                            DashboardToggleCard {
                                anchors.fill: parent
                                controlKey: slot.modelData.key
                                override: catalog.controlFor(slot.modelData.key)
                                title: slot.modelData.title
                                icon: slot.modelData.icon
                                tileShape: slot.modelData.shape
                                pager: root.pager
                                staggerMs: root.staggerMs
                                animIndex: slot.index % 6
                                travelX: slot.modelData.travelX
                                travelY: slot.modelData.travelY
                            }
                        }

                        Component {
                            id: sliderComponent
                            DashboardSliderCard {
                                anchors.fill: parent
                                controlKey: slot.modelData.key
                                override: catalog.controlFor(slot.modelData.key)
                                title: slot.modelData.title
                                icon: slot.modelData.icon
                                tileShape: slot.modelData.shape
                                showPercent: slot.modelData.percent !== false
                                pager: root.pager
                                staggerMs: root.staggerMs
                                animIndex: slot.index % 6
                                travelX: slot.modelData.travelX
                                travelY: slot.modelData.travelY
                            }
                        }

                        Component {
                            id: spinComponent
                            DashboardSpinCard {
                                anchors.fill: parent
                                controlKey: slot.modelData.key
                                override: catalog.controlFor(slot.modelData.key)
                                title: slot.modelData.title
                                icon: slot.modelData.icon
                                tileShape: slot.modelData.shape
                                pager: root.pager
                                staggerMs: root.staggerMs
                                animIndex: slot.index % 6
                                travelX: slot.modelData.travelX
                                travelY: slot.modelData.travelY
                            }
                        }

                        Component {
                            id: comboComponent
                            DashboardComboCard {
                                anchors.fill: parent
                                controlKey: slot.modelData.key
                                override: catalog.controlFor(slot.modelData.key)
                                title: slot.modelData.title
                                icon: slot.modelData.icon
                                tileShape: slot.modelData.shape
                                pager: root.pager
                                staggerMs: root.staggerMs
                                animIndex: slot.index % 6
                                travelX: slot.modelData.travelX
                                travelY: slot.modelData.travelY
                            }
                        }

                        Component {
                            id: textComponent
                            DashboardTextCard {
                                anchors.fill: parent
                                placeholder: slot.modelData.placeholder ?? ""
                                controlKey: slot.modelData.key
                                override: catalog.controlFor(slot.modelData.key)
                                title: slot.modelData.title
                                icon: slot.modelData.icon
                                tileShape: slot.modelData.shape
                                pager: root.pager
                                staggerMs: root.staggerMs
                                animIndex: slot.index % 6
                                travelX: slot.modelData.travelX
                                travelY: slot.modelData.travelY
                            }
                        }

                        Component {
                            id: widgetsComponent
                            DashboardWidgetsCard {
                                anchors.fill: parent
                                title: slot.modelData.title
                                icon: slot.modelData.icon
                                tileShape: slot.modelData.shape
                                pager: root.pager
                                staggerMs: root.staggerMs
                                animIndex: slot.index % 6
                                travelX: slot.modelData.travelX
                                travelY: slot.modelData.travelY
                            }
                        }

                        Component {
                            id: timePreviewComponent
                            DashboardTimeCard {
                                anchors.fill: parent
                                title: slot.modelData.title
                                icon: slot.modelData.icon
                                tileShape: slot.modelData.shape
                                pager: root.pager
                                staggerMs: root.staggerMs
                                animIndex: slot.index % 6
                                travelX: slot.modelData.travelX
                                travelY: slot.modelData.travelY
                            }
                        }

                        Component {
                            id: collageLayoutsComponent
                            DashboardCollageLayoutsCard {
                                anchors.fill: parent
                                title: slot.modelData.title
                                icon: slot.modelData.icon
                                tileShape: slot.modelData.shape
                                pager: root.pager
                                staggerMs: root.staggerMs
                                animIndex: slot.index % 6
                                travelX: slot.modelData.travelX
                                travelY: slot.modelData.travelY
                            }
                        }

                        Component {
                            id: weatherMapComponent
                            DashboardWeatherMapCard {
                                anchors.fill: parent
                                pager: root.pager
                                staggerMs: root.staggerMs
                                animIndex: slot.index % 6
                                travelX: slot.modelData.travelX
                                travelY: slot.modelData.travelY
                            }
                        }

                        Component {
                            id: swatchComponent
                            DashboardSwatchCard {
                                anchors.fill: parent
                                controlKey: slot.modelData.key
                                override: catalog.controlFor(slot.modelData.key)
                                title: slot.modelData.title
                                icon: slot.modelData.icon
                                tileShape: slot.modelData.shape
                                pager: root.pager
                                staggerMs: root.staggerMs
                                animIndex: slot.index % 6
                                travelX: slot.modelData.travelX
                                travelY: slot.modelData.travelY
                            }
                        }

                        Component {
                            id: shapeComponent
                            DashboardShapeCard {
                                anchors.fill: parent
                                controlKey: slot.modelData.key
                                override: catalog.controlFor(slot.modelData.key)
                                title: slot.modelData.title
                                icon: slot.modelData.icon
                                tileShape: slot.modelData.shape
                                pager: root.pager
                                staggerMs: root.staggerMs
                                animIndex: slot.index % 6
                                travelX: slot.modelData.travelX
                                travelY: slot.modelData.travelY
                            }
                        }

                        Component {
                            id: barLayoutComponent
                            DashboardBarLayoutCard {
                                anchors.fill: parent
                                title: slot.modelData.title
                                icon: slot.modelData.icon
                                tileShape: slot.modelData.shape
                                pager: root.pager
                                staggerMs: root.staggerMs
                                animIndex: slot.index % 6
                                travelX: slot.modelData.travelX
                                travelY: slot.modelData.travelY
                            }
                        }

                        Component {
                            id: displaysComponent
                            DashboardDisplaysCard {
                                anchors.fill: parent
                                title: slot.modelData.title
                                icon: slot.modelData.icon
                                tileShape: slot.modelData.shape
                                pager: root.pager
                                staggerMs: root.staggerMs
                                animIndex: slot.index % 6
                                travelX: slot.modelData.travelX
                                travelY: slot.modelData.travelY
                            }
                        }

                        Component {
                            id: paletteComponent
                            DashboardPaletteCard {
                                anchors.fill: parent
                                controlKey: slot.modelData.key
                                override: catalog.controlFor(slot.modelData.key)
                                title: slot.modelData.title
                                icon: slot.modelData.icon
                                tileShape: slot.modelData.shape
                                pager: root.pager
                                staggerMs: root.staggerMs
                                animIndex: slot.index % 6
                                travelX: slot.modelData.travelX
                                travelY: slot.modelData.travelY
                            }
                        }

                        Component {
                            id: durationComponent
                            DashboardDurationCard {
                                anchors.fill: parent
                                controlKey: slot.modelData.key
                                override: catalog.controlFor(slot.modelData.key)
                                title: slot.modelData.title
                                icon: slot.modelData.icon
                                tileShape: slot.modelData.shape
                                pager: root.pager
                                staggerMs: root.staggerMs
                                animIndex: slot.index % 6
                                travelX: slot.modelData.travelX
                                travelY: slot.modelData.travelY
                            }
                        }

                        Component {
                            id: iconPickerComponent
                            DashboardIconCard {
                                anchors.fill: parent
                                title: slot.modelData.title
                                icon: slot.modelData.icon
                                tileShape: slot.modelData.shape
                                pager: root.pager
                                staggerMs: root.staggerMs
                                animIndex: slot.index % 6
                                travelX: slot.modelData.travelX
                                travelY: slot.modelData.travelY
                            }
                        }

                        Component {
                            id: selectComponent
                            DashboardSelectCard {
                                anchors.fill: parent
                                controlKey: slot.modelData.key
                                override: catalog.controlFor(slot.modelData.key)
                                title: slot.modelData.title
                                icon: slot.modelData.icon
                                tileShape: slot.modelData.shape
                                pager: root.pager
                                staggerMs: root.staggerMs
                                animIndex: slot.index % 6
                                travelX: slot.modelData.travelX
                                travelY: slot.modelData.travelY
                            }
                        }
                    }
                }
            }
        }
}
