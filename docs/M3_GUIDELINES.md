# Material 3 & M3 Expressive UI Guidelines

This document establishes the strict rules for developing UI components in `end4-pC` to ensure they fully conform to the Material 3 (M3) and M3 Expressive design standards. 

These guidelines are **hard constraints** for all future UI work. Ad hoc values ("whatever looks right") are strictly prohibited.

## 1. Design Tokens and Theming

All UI components must exclusively use design tokens defined in `modules/common/Appearance.qml`. Hardcoding colors, radii, font sizes, or animation parameters is strictly forbidden.

### Colors and Layering
The shell uses dynamic, tonal color palettes derived from the wallpaper or theme. 

- **UI Colors (`Appearance.colors`)**: Always use these role-based colors rather than the raw `m3colors` palettes when styling UI surfaces, text, and borders.
  - `colLayer0`: The **outermost** background of a standalone floating surface (e.g., a popup, toast, or OSD with nothing behind it). This token correctly applies `backgroundTransparency` and achieves compositor blur.
  - `colLayer1` through `colLayer4`: Backgrounds for cards or elements **nested inside an already-opaque parent surface** (e.g., a list item inside a sidebar that already has `colLayer0`). These use `contentTransparency`. *Do not use these for standalone popups, as they will render with unblurred transparency.*
- **Text and Icons**: Use `colOnLayer0`, `colOnLayer1`, `colOnSurface`, `colSubtext`, etc., ensuring contrast is maintained across dark/light modes.
- **Primary/Secondary/Tertiary**: Use `colPrimary`, `colSecondary`, `colTertiary` (and their respective `Hover` / `Active` variants) for interactive or accented elements.
### Borders and Outlines
Visible borders are not required for every surface. Many components rely entirely on elevation shadows or tonal contrast (e.g., `GroupedList` relies purely on `colLayer1` against the background without a border). When borders are used, adhere to the following strict conventions:

- **Border Width**: 
  - Use `border.width: 1` for standard structural outlines (e.g., `AboutCard`, `BarIsland`, `StyledPopup`, `StyledSwitch`).
  - Use `border.width: 2` to emphasize active/selected states (e.g., `StyledRadioButton`, `ColorSelectionArray`, `GroupButton`, `MonitorRect` when dragged).
  - *Never* use fractional or ad hoc border widths (e.g., `1.5`).

- **Border Colors**:
  - `colLayer0Border`: The standard 1px outline for standalone floating surfaces and prominent containers. Often combined with `StyledRectangularShadow` (as seen in `StyledPopup`).
  - `colOutline`: Used for high-contrast interior dividers or form field outlines (e.g., `WindowDialogSeparator`).
  - `colOutlineVariant`: Used for subtle dividers or secondary structural boundaries (e.g., `DockSeparator`, `SecondaryTabBar`).
  - `colError`: Used for semantic error states (e.g., high usage in `ResourceCard`).

- **Combining with Shadows**:
  - Standalone popups and floating elements (like `StyledPopup`, `Toolbar`) combine `StyledRectangularShadow` with a 1px `colLayer0Border` to clearly define edges against complex backgrounds.
  - Interiors and nested menus (e.g., `GroupedList`) drop the border and shadow entirely in favor of tonal contrast (`colLayer1`+).

### Grouped Settings

- Use the standard `GroupedList` presentation when rows are related but remain visually distinct.
- Use `GroupedList { cohesive: true }` when every row belongs to one continuous form or semantic
  unit. Cohesive groups have no gaps or rounded internal seams; only the outside corners are rounded.
- Let `GroupedList` provide the common content inset. Child controls must not add another horizontal
  inset that makes icons, labels, or fields drift out of alignment with adjacent rows.

### Corner Rounding (Radii)
Always use predefined rounding values from `Appearance.rounding`. Never use hardcoded pixel values (e.g., `radius: 12`) or arbitrary maximum values (e.g., `radius: 9999`).

- `unsharpen` (2px) / `unsharpenmore` (6px): Extremely subtle rounding for small, nearly square elements.
- `verysmall` (8px): Tooltips, small indicators.
- `small` (12px): Small chips, standard buttons.
- `normal` (17px): Standard cards, list items, menus.
- `large` (23px) / `windowRounding` (18px): Large standalone widgets, floating windows.
- `verylarge` (30px): Prominent dialogs, major distinct UI blocks.
- `full` (9999px): Circular elements, full-bleed pills, FABs.

## 2. Motion and Animation

This codebase uses the **M3 Expressive** motion scheme. You must use the component factories in `Appearance.animation` or the explicit curve/duration definitions in `Appearance.animationCurves`. 

Never use raw integer durations (e.g., `duration: 150`), generic QML easing curves (e.g., `Easing.OutCubic`, `Easing.Linear`), or ad hoc bezier curves.

### Spatial Moves (Position and Size)
For elements changing position, dimensions, or layout:
- **Default Spatial Move**: `Appearance.animation.elementMove` (500ms, `expressiveDefaultSpatial`). Use for most spatial transitions.
- **Small Spatial Move**: `Appearance.animation.elementMoveSmall` (350ms, `expressiveFastSpatial`). Use for small adjustments or small elements shifting slightly.

### Effects and State Changes (Color, Opacity)
For color fades, opacities, and non-spatial state transitions:
- **Fast Effects**: `Appearance.animation.elementMoveFast` (200ms, `expressiveEffects`). 

### Entrance and Exit (Emphasized)
When introducing or removing elements from the screen:
- **Entrance**: `Appearance.animation.elementMoveEnter` (`emphasizedDecel`, 400ms).
- **Exit**: `Appearance.animation.elementMoveExit` (`emphasizedAccel`, 200ms).

## 3. Existing Nonconformances

The following existing widgets contain hardcoded values that violate these strict guidelines. They have been explicitly identified and should be fixed in future PRs (do not copy their implementation for new widgets):

- **Hardcoded Radii**:
  - `radius: 9999` instead of `Appearance.rounding.full` (e.g., `CircularProgress.qml`).
  - Arbitrary pixel values (e.g., `35`, `14`, `8`, `6`, `4`, `2`, `1`) in `CliphistImage.qml`, `ClippedProgressBar.qml`, `ClockPicker.qml`, `LayoutSection.qml`, `PlayerControlsLyrics.qml`, `ResourceCard.qml`, `StyledDropShadow.qml`, `ThemeCarousel.qml`, and shapes.
- **Hardcoded Colors**:
  - Hex values (e.g., `#ffffff`, `#000000`, `#605790`) in `DashedBorder.qml`, `RoundCorner.qml`, `SineCookie.qml`, and the `shapes/` directory.
- **Inconsistent Borders/Outlines**:
  - `StyledComboBox` uses a floating popup but lacks the standard 1px `colLayer0Border` outline found on `StyledPopup`.
  - `ResourceCard.qml` uses `border.width: 1.5`, which is a non-standard fractional width.
- **Hardcoded Motion**:
  - Ad hoc integer durations (`50`, `110`, `150`, `200`, `300`, `350`, `400`) and arbitrary easing curves (e.g., `Easing.OutCubic`) in `AndroidClock.qml`, `ConfigSelectionShapeArray.qml`, `DragApps.qml`, `ErrorShakeAnimation.qml`, `LayoutSection.qml`, `Lyrics.qml`, `MaterialLoadingIndicator.qml`, `MonitorRect.qml`, `SelectionGroupButton.qml`, `StyledScrollBar.qml`, `StyledSwitch.qml`, `StyledText.qml`, `ThemeCarousel.qml`, `VerticalTabBar.qml`, and `widgetCanvas/WidgetCanvas.qml`.
