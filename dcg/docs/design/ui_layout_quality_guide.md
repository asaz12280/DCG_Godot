# Project DCG UI Layout Quality Guide

Last updated: 2026-07-01

This guide defines the UI layout quality bar for early Project DCG development. The goal is not final art. The goal is clean base panels, readable typography, consistent buttons, predictable spacing, and layouts that will still work when final art is added later.

## Core Principle

Do not mark UI work complete only because the code runs. A player-facing UI is complete only when it is usable, readable, visually organized, and stable at the supported test resolutions.

## Early UI Priorities

Focus on these before art polish:

- Panel base layout.
- Button size and placement.
- Spacing between controls.
- Alignment and grouping.
- Text readability.
- Information hierarchy.
- Consistent reusable patterns.
- No overlap, clipping, or cramped layout.

Do not spend early time on:

- Final illustrations.
- Final icon sets.
- Decorative effects.
- Complex animation.
- Highly themed skins.

## Layout Quality Checklist

Use this checklist for every UI task and every Project Health Check.

### 1. Visual Hierarchy

- The player can identify the screen purpose within 1-2 seconds.
- The title is visually stronger than body text.
- Primary action is more obvious than secondary actions.
- Dangerous or destructive actions are not visually confused with safe actions.
- Important gameplay information is not buried in same-size text.

### 2. Spacing And Grouping

- Related controls are grouped together.
- Unrelated sections have visibly larger separation.
- Margins are consistent within a panel.
- Button groups use consistent gaps.
- The layout has breathing room and does not feel randomly scattered.

Recommended early spacing:

- Small internal gap: `8-12 px`.
- Row gap: `12-16 px`.
- Section gap: `20-32 px`.
- Panel outer padding: `24-48 px`.
- Large screen safe margin: at least `48 px`.

These are guidelines, not strict pixels. Consistency matters more than one exact number.

### 3. Alignment

- Panel edges align to a clear grid.
- Labels and values align consistently in rows.
- Buttons in the same group have the same width or a deliberate hierarchy.
- Lists, grids, and scroll areas have predictable starts and ends.
- No control looks a few pixels accidentally off.

### 4. Buttons

- Buttons are large enough to read and click comfortably.
- Buttons in the same group share height, font size, and spacing.
- Primary, secondary, back/cancel, and disabled states are visually distinct.
- The player can predict where confirm/back actions will be across screens.
- Button text fits without clipping at 1280x720 and 1920x1080.

Recommended early button rules:

- Common button height: `44-56 px`.
- Main menu button height: `52-64 px`.
- Minimum comfortable button width: content plus `24 px` horizontal padding.
- Button rows should not shift when labels change language.

### 5. Text Readability

- Body text is large enough for gameplay UI.
- Important text has enough contrast against the panel/background.
- Long Traditional Chinese, Simplified Chinese, Japanese, and English text does not clip.
- Text is not placed directly over noisy gameplay backgrounds unless it has a panel, shadow, or high-contrast backing.
- Avoid long paragraphs in gameplay UI; prefer compact labels and clear values.

Early guidance:

- Avoid body text below roughly `16 px`.
- Important labels should usually be `18 px` or larger.
- Titles and panel headers should be visually distinct.
- Use wrapping or truncation intentionally; do not let text overflow silently.

### 6. Panel Structure

- A panel should have a clear header, content area, and action area when applicable.
- Reusable panels should be Godot node-first with `.tscn` and `Control` nodes.
- Scrollable content should not hide primary actions.
- Back/cancel buttons should stay easy to find.
- Empty states should look intentional, not broken.

### 7. Responsive Fit

Required early test resolutions:

- `1280x720`
- `1920x1080`

Check:

- No overlap.
- No clipped button labels.
- No panel overflowing past screen edges.
- Scroll areas leave space for tabs, headers, and action buttons.
- HUD does not block core gameplay view more than needed.

### 8. Consistency

- Similar screens reuse similar margins, button sizes, panel styles, and typography.
- New UI should reuse `UIStyle`, `UILayout`, theme resources, and existing panel patterns where possible.
- If a new pattern is required, document why.

### 9. Placeholder Art Compatibility

- Placeholder panels should reserve space for future art/icon placement.
- Do not make layout depend on final art being present.
- Avoid tiny decorative elements that will need to be replaced before the layout is proven.
- Keep background/base panels clean enough that final art can be layered later.

## UI Layout Review Procedure

For every task that creates or changes UI:

1. Load the relevant scene.
2. Check the UI at `1280x720` and `1920x1080`.
3. Confirm visual hierarchy: title, content, actions.
4. Confirm spacing and alignment.
5. Confirm button sizes and text fit.
6. Confirm there is no overlap or clipping.
7. Confirm the layout uses Godot nodes/scenes for stable panels unless there is a documented reason.
8. Record the result in `docs/tasks/progress_log.md`.

For automated or semi-automated checks:

- Add runtime rect checks for critical panels when practical.
- Add screenshot checks when using Godot MCP or another visual inspection path.
- Keep headless validation for structure and basic sizing, but do not treat headless success as proof that UI looks good.

## Common Failure Patterns To Fix Immediately

- A panel technically opens but looks cramped.
- Buttons have inconsistent widths or irregular spacing.
- Back/confirm actions jump to different positions between similar screens.
- Text clips in Chinese or Japanese because wrapping only considered English.
- The panel is built entirely in script even though a stable `.tscn` layout would be clearer.
- A new UI copies colors/sizes locally instead of using shared style helpers.
- A scroll area consumes the whole panel and pushes action buttons out of view.
- A UI element works at 1920x1080 but breaks at 1280x720.

## Sources Used For Principles

- Nielsen Norman Group, visual design principles: https://www.nngroup.com/articles/principles-visual-design/
- Nielsen Norman Group, aesthetic-usability effect: https://www.nngroup.com/articles/aesthetic-usability-effect/
- Game Accessibility Guidelines, full list: https://gameaccessibilityguidelines.com/full-list/
- Microsoft Xbox Accessibility Guideline 101, text display: https://learn.microsoft.com/en-us/xbox/accessibility/xbox-accessibility-guidelines/101
- W3C WCAG contrast minimum explanation: https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html
- Interaction Design Foundation, visual hierarchy overview: https://ixdf.org/literature/topics/visual-hierarchy
