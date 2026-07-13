# Duckov Template Task Board

Last updated: 2026-07-04 automation pass 53

Purpose: keep the Duckov-like template work grounded in observed public mechanics, then convert gaps into small, testable DCG tasks. This board describes system patterns only; do not copy protected art, text, maps, code, UI skins, or trademark expression.

## Reference Observations

Sources checked on 2026-07-03 and 2026-07-04:

- `https://escapefromduckov.net/` describes the loop as PvE survival RPG play built around scavenging resources, building the hideout, upgrading gear, surviving enemies, five maps, dynamic loot, extraction risk, weapon customization, base building, skill trees, blueprints, crafting, and stronger expeditions.
- `https://escapefromduckov.net/guide/21-practical-tips-for-escape-from-duckcov` highlights inventory shortcuts, especially pressing `L` on an item to lock it so storage actions do not accidentally move essential supplies.
- `https://www.keengamer.com/articles/guides/escape-from-duckov-how-to-expand-storage-warehouse-backpack-guide/` separates permanent base Warehouse capacity from backpack capacity, and frames warehouse upgrades as prep-time and stockpile power spikes.
- `https://gl.ali213.net/html/2025-10/1705185.html` and `https://www.entertainment14.net/blog/post/111002920-%E9%80%83%E9%9B%A2%E9%B4%A8%E7%A7%91%E5%A4%AB-escape-from-duckov-%E6%96%B0%E6%89%8B%E5%AF%A6%E7%94%A8%E6%8A%80%E5%B7%A7%E6%95%B4%E7%90%86` both describe the warehouse convenience loop as locking items with `L`, then using bulk storage while locked items remain in the backpack.
- `https://escapefromduckov.net/perks/storageexpand` lists Storage Expansion as a sequence of capacity upgrades, starting with a +35 storage-capacity tier and later item-gated tiers.
- `https://escape-from-duckov.fandom.com/wiki/Large_Capacity` records a quest objective that asks the player to unlock Storage Level 1, which reinforces storage expansion as progression content rather than a static UI number.
- `https://gamerblurb.com/articles/escape-from-duckov-how-to-expand-storage-guide` and `https://bo3.gg/games/articles/how-to-expand-storage-in-escape-from-duckov` describe storage expansion as a warehouse interface mode/tab where the player applies an upgrade and increases total capacity.
- `https://escapefromduckov.net/perks/storageexpand` records Storage Expansion Lv.2 as another +35 capacity tier with money plus a Plastic Barrel requirement, and item/wiki sources connect Plastic Barrel to warehouse expansion use.
- `https://www.reddit.com/r/EscapeFromDuckov/comments/1ol0e4k/compiled_34_beginner_tips_for_escape_from_duckov/` and public guide summaries describe pressing `N` to mark quest or upgrade materials so needed items are easier to recognize before selling or discarding.
- `https://steamcommunity.com/sharedfiles/filedetails/?id=3593634019` shows that quest-required item planning is a large player-facing concern: players maintain lists of what to keep and what to sell across many quests.
- `https://steamcommunity.com/app/3167020/discussions/0/596289460456391955/` includes player discussion that marking applies to the item type and its other copies, which supports DCG using item paths rather than slot indexes for needed-item marks.
- `https://escape-from-duckov.fandom.com/wiki/Workbench` describes the workbench as the place to craft, dismantle, repair, register blueprints, and unlock workbench upgrades with material costs.
- `https://steamcommunity.com/sharedfiles/filedetails/?id=3599714399` describes blueprints as permanent craft unlocks researched at the workbench or medical table, reinforcing that crafting-related materials should feed the same keep/sell awareness loop.
- `https://escapefromduckov.net/items` presents item browsing around categories, value, weight, max stack, item stats, and blueprint/workbench tags, which supports showing those fields close to inventory decisions.
- `https://www.escapefromduckov.io/archive/items` describes item entries as having weight, price, quality, durability, equipment stats, sources, acquisition methods, and usage tips.
- `https://steamcommunity.com/sharedfiles/filedetails/?id=3592004817` shows strong player demand for sorting by weight, value, and value-to-weight ratio.
- `https://www.reddit.com/r/EscapeFromDuckov/comments/1ohf6fp/should_i_loot_everything_i_see_and_extract_when/` includes player advice to prioritize quest/hideout items, use `N` marking on upgrade trees, and rely on item descriptions to show quest/upgrade requirements.
- `https://steamcommunity.com/app/3167020/discussions/0/601895505111328801/` includes player demand for clearer item weight at a glance while on mission, supporting tooltip parity in the active backpack/equipment panel instead of only warehouse storage.
- `https://escapefromduckov.net/buildings/workbench` describes the Workbench as the place to craft, dismantle, repair, and register blueprints, and shows building requirements as item costs.
- `https://duckovmap.com/blueprints` presents blueprint data by craft category, including weapons, armor, ammunition, medical supplies, tools, and miscellaneous items.
- `https://steamcommunity.com/sharedfiles/filedetails/?id=3599714399` describes blueprints as permanent crafts learned through Blueprint Research, with combat/tool recipes at the Workbench and medical recipes at the Medic Table.
- `https://steamcommunity.com/app/3167020/discussions/0/603033083890929220/` reinforces that learned blueprints become reusable crafting options, while formulas route to the workbench or medical table depending on type.
- `https://boostroom.com/blog/crafting-workbench-tips-turn-junk-into-real-upgrades-in-duckov` frames crafting as a routine that turns warehouse clutter into raid supplies, especially reliable ammo and practical items.
- `https://escapefromduckov.net/perks/perktree-workbench/ap-bullet-crafting` shows Workbench-tree crafting unlocks with costs, prerequisites, and a short craft time, reinforcing that crafting sits behind progression and material checks.
- `https://gmtreks.com/escape-from-duckov/quests/27` shows a quest asking the player to test an upgraded Workbench by crafting/submitting an item, which supports making craft execution part of base progression rather than a standalone database entry.
- `https://escape-from-duckov.fandom.com/wiki/Workbench` and `https://escapefromduckov.net/buildings/workbench` both describe the Workbench as a building that becomes a normal interactable station after construction, with crafting, dismantling, repair, and blueprint registration as station functions.
- `https://duckovmap.com/blueprints` presents blueprint/craft data as a large list by category, which supports DCG using recipe rows instead of a single hardcoded craft action.
- `https://boostroom.com/blog/blueprints-gear-upgrades-where-to-find-them-and-how-to-use-them` describes blueprints as permanent unlocks and calls out the Workbench vs Medic Station split, reinforcing recipe station routing and selected recipe state.
- `https://duckhelper.info/recipes` exposes crafting recipes as a searchable recipe/component reference, reinforcing that recipe UIs should be list-driven and material-readable.
- `https://boostroom.com/blog/blueprints-gear-upgrades-where-to-find-them-and-how-to-use-them` also recommends checking the crafting list at the correct station after research and planning crafts for the next few raids, which supports a player-selectable Workbench recipe list.
- `https://escapefromduckov.net/buildings/workbench` describes the Workbench as a station for crafting, dismantling, repair, and blueprint registration, reinforcing that the DCG station UI should support repeated recipe navigation rather than a one-off button.
- `https://boostroom.com/blog/crafting-workbench-tips-turn-junk-into-real-upgrades-in-duckov` frames Workbench use as a routine loop that turns warehouse materials into reliable raid supplies and gated upgrades, so recipe selection needs to be quick enough for repeated use.
- `https://boostroom.com/blog/blueprints-gear-upgrades-where-to-find-them-and-how-to-use-them` recommends checking the correct station's crafting list after research and planning crafts for upcoming raids, supporting recipe-list selection as a first-class station behavior.
- `https://escapefromduckov.net/buildings/workbench`, `https://boostroom.com/blog/blueprints-gear-upgrades-where-to-find-them-and-how-to-use-them`, and community starter tips all describe the Workbench as a multi-function station: crafting, blueprint registration, repair, and dismantling/deconstruction are related station modes instead of unrelated screens.
- `https://duckovmap.com/blueprints` lists a large blueprint catalog across weapons, armor, ammunition, medical supplies, tools, and miscellaneous items, supporting DCG exposing blueprint mode as a station surface before it becomes a full data-backed research flow.
- `https://steamcommunity.com/sharedfiles/filedetails/?id=3599714399` summarizes blueprints as permanent crafts unlocked through Blueprint Research at the Workbench or Medic Table, with combat items routing to Workbench and medical items to the medical table.
- `https://boostroom.com/blog/blueprints-gear-upgrades-where-to-find-them-and-how-to-use-them` frames blueprint registration as immediate post-extraction behavior: a found blueprint should become permanent value and then appear in the correct station's craft list.
- Reddit player discussion on lost blueprints reports that blueprint boxes/duplicates are tied to whether the player has registered the blueprint, supporting save-backed researched flags instead of one-time volatile item checks.
- `https://boostroom.com/blog/blueprints-gear-upgrades-where-to-find-them-and-how-to-use-them` also recommends checking the correct station craft list after research and tracking missing blueprints, supporting a visible Blueprints mode that updates recipe rows after research.
- `https://steamcommunity.com/sharedfiles/filedetails/?id=3599714399` summarizes the player habit as find the blueprint, bank it, then research it at the correct station; this supports exposing research as a base-station action, not as an automatic pickup effect.
- `https://steamcommunity.com/app/3167020/discussions/0/603033083890929220/` describes formulas routing to Workbench or Medic Table by blueprint type, supporting `station_id` filtering in blueprint rows.
- `https://escapefromduckov.net/buildings/workbench` describes the Workbench as a craft, dismantle, repair, and blueprint-registration station, reinforcing a tabbed station surface where Blueprints is now actionable and Repair/Dismantle remain future validated modes.
- `https://allthings.how/escape-from-duckov-repair-guide-gear-fixes-durability-and-early-repair-quests/` describes repair as a base Workbench/Fix Station flow: broken weapons or armor are repaired from inventory after the station upgrade, with costs scaling by item condition.
- `https://escape-from-duckov.fandom.com/wiki/Workbench` lists Fix Station as a Workbench upgrade that unlocks weapon and equipment repair, while Disassemble Station unlocks dismantling; this supports keeping Repair/Dismantle as Workbench modes gated by data and upgrades.
- `https://escapefromduckov.net/perks/perktree-workbench` records Fix Station and Disassemble Station as separate Workbench-tree unlocks, reinforcing that repair/dismantle should not be free actions on the base Workbench tab.
- `https://www.reddit.com/r/EscapeFromDuckov/comments/1ot7se1/what_happens_if_i_dont_repair_my_weapons_and_what/` and `https://steamcommunity.com/app/3167020/discussions/0/598541076225263169/` describe current durability, maximum durability, low-durability penalties, and max-durability loss after repairs, supporting separate current/max durability fields.
- `https://allthings.how/escape-from-duckov-repair-guide-gear-fixes-durability-and-early-repair-quests/` emphasizes checking current/max durability before raids and treating worn gear as persistent equipment state, supporting durability preservation across base loadout, raid entry, death rules, and stash return.
- `https://allthings.how/escape-from-duckov-repair-guide-gear-fixes-durability-and-early-repair-quests/` also states that current durability falls with use while repair restores current durability and shaves max durability, supporting combat-time wear as a separate rule from repair max-loss.
- `https://escape-from-duckov.fandom.com/wiki/Weapons` describes firearms as consuming specific ammo and ammo affecting durability loss rate among other characteristics, supporting a future ammo-driven wear multiplier once DCG ammo stats are expanded.
- `https://www.reddit.com/r/EscapeFromDuckov/comments/1ootcum/question_about_your_weapons_quality/` includes community discussion that weapon wear differs by ammo tier, supporting ammo data that can carry a wear-rate value instead of a fixed per-shot durability loss.
- `https://steamcommunity.com/app/3167020/discussions/0/601894623046035786/?l=swedish` describes better ammo as reducing weapon wear, supporting lower ammo wear-rate values for higher-grade ammo templates.
- `https://escape-from-duckov.fandom.com/wiki/Ammunition` describes ammo as lootable, craftable, or purchasable and organized by caliber, supporting high-grade same-caliber ammo that appears through both loot and Workbench crafting routes.
- `https://www.gamesradar.com/games/action/escape-from-duckov-guns-weapons/` notes that higher quality bullets drain gun durability more slowly, supporting the first original high-grade ammo item as a low-wear variant rather than only a value bump.
- `https://escape-from-duckov.fandom.com/wiki/Ammunition` also describes ammo families as carrying different damage, penetration, recoil, and spread tradeoffs, supporting a staged ammo-stat model instead of only durability wear.
- `https://www.reddit.com/r/EscapeFromDuckov/comments/1p9cb0p/for_anyone_wondering_how_armor_levelarmor/`, `https://steamcommunity.com/app/3167020/discussions/0/659340488559640409/`, and `https://steamcommunity.com/app/3167020/discussions/0/596289460456706226` discuss armor penetration, protection levels, and damage effectiveness, supporting a data-backed penetration/protection layer rather than a flat damage number only.
- `https://www.reddit.com/r/EscapeFromDuckov/comments/1ocdojd/short_explanation_on_weapon_stats_best_attachments/` describes ADS spread as an accuracy-critical weapon stat, and `https://steamcommunity.com/app/3167020/discussions/0/671726025354393604/` separates recoil movement from spread, supporting ammo/weapon handling stats as separate fields rather than more damage math.
- `https://www.pcgamer.com/games/third-person-shooter/escape-from-duckov-might-look-like-a-parody-but-its-a-full-fledged-full-featured-singleplayer-bottling-of-extraction-shooter-juice/` also notes ammo types affecting recoil, shot grouping, armor penetration, and movement coefficients, supporting staged ammo ballistics modifiers.
- `https://www.reddit.com/r/EscapeFromDuckov/comments/1ocdojd/short_explanation_on_weapon_stats_best_attachments/` explains vertical recoil as cursor movement behind the enemy and horizontal recoil as random left/right cursor jump, supporting recoil as sustained-fire aim displacement rather than the same thing as spread.
- `https://escape-from-duckov.fandom.com/wiki/Ammunition` describes S-class rounds as low-recoil ammunition, supporting ammo-level recoil modifiers.
- `https://escape-from-duckov.fandom.com/wiki/Attachments` describes grips as improving sustained-fire weapon control, reducing spread, and improving recoil recovery, supporting a recoverable recoil offset that attachments can later tune.
- `https://escape-from-duckov.fandom.com/wiki/Attachments` also describes magazines as defining ammunition capacity and reload efficiency, with higher-tier magazines offering increased capacity or faster reloads depending on weapon class.
- `https://escapefromduckov.net/items/magazine-ar-cap-1` presents an extended magazine item as a magazine attachment that increases ammo capacity, supporting DCG's first attachment effect as a capacity modifier rather than another passive tooltip-only item.
- `https://escapefromduckov.net/items/magazine-smg-lv-1` exposes a magazine-capacity bonus row for an extended magazine, reinforcing that attachment bonuses should be data fields that combat models read.
- `https://escapefromduckov.net/items/br-vss-normal` exposes item-style stats such as min/max vertical recoil, min/max horizontal recoil, and recoil time, supporting separate weapon recoil data fields.
- The 2026-07-04 recoil UI refresh confirms that recoil is visible crosshair/cursor movement while spread is projectile deviation, so the template should present recoil as HUD reticle displacement instead of hiding it only in projectile math.
- The 2026-07-04 attachment refresh supports treating attachments as modifiers that flow from item data, through equipped slots, into combat models, so crafted attachments should no longer remain "future" items with no runtime effect.
- `https://escape-from-duckov.fandom.com/wiki/Attachments`, `https://boostroom.com/blog/weapon-modding-guide-attachments-that-actually-matter-in-escape-from-duckov`, and `https://escapefromduckov.net/items/grip-all-rec-2` all present grip-style attachments as handling modifiers, supporting recoil/recovery multipliers as attachment data rather than one-off weapon code.
- `https://escape-from-duckov.fandom.com/wiki/Weapons`, `https://steamcommunity.com/app/3167020/discussions/0/769678769228165119/`, and public attachment guides describe weapons exposing compatible mod categories such as Scope, Muzzle, Grip, Stock, Tactic, and Mag, supporting dedicated weapon-mod slots instead of treating mods as generic accessories.
- `https://escape-from-duckov.fandom.com/wiki/Weapons`, `https://escape-from-duckov.fandom.com/wiki/Attachments`, and the same public compatibility discussion reinforce that players need visible supported mod categories, not hidden service-only compatibility rules.
- `https://escape-from-duckov.fandom.com/wiki/Attachments`, `https://escapefromduckov.net/items/stock-ar-rec-2`, and public weapon-modding guides describe stocks as stability/recoil-control attachments, supporting a stock lane that reuses existing recoil/recovery fields before adding new ADS or handling systems.
- `https://escape-from-duckov.fandom.com/wiki/Attachments` describes Tactic attachments as a handling-focused lane where laser sights affect spread or aiming speed, supporting a first tactic slice that reuses existing spread multiplier fields before inventing ADS timing.
- `https://escapefromduckov.net/items/tec-lazer-lv-1` presents a Tactical Laser item as a Tactic attachment that improves shooting accuracy, reinforcing `weapon_tactic` as a real mod slot rather than a generic charm/accessory.
- The 2026-07-04 user correction and public `Attachments`/`Weapons` references reinforce that Mag, Grip, Muzzle, Scope, Stock, and Tactic are weapon hardpoints opened from a weapon item, not always-visible character equipment slots. The template should store installed mods on the weapon stack and keep character equipment UI focused on worn/carried gear.
- `https://www.gamesradar.com/games/action/escape-from-duckov-guns-weapons/` references the 50% durability warning threshold for guns, supporting a later player-facing low-durability warning instead of hiding the state in data only.
- `https://escapefromduckov.net/tips` records an in-game-style tip that firearm durability below 50% affects damage and spread, supporting a player-visible combat warning before implementing the full penalty math.
- `https://www.reddit.com/r/EscapeFromDuckov/comments/1oybd3i/below_50_gun_durability_same_damage_but_larger/` includes community observation that low gun durability presents as larger spread, supporting an accuracy/spread penalty lane after the HUD warning is readable.
- `https://steamcommunity.com/app/3167020/discussions/0/598541076225263169/` describes the low-durability penalty as being based on the current maximum durability threshold, supporting penalty math that reads stack current/max durability instead of only static item data.
- `https://www.reddit.com/r/EscapeFromDuckov/comments/1ot7se1/what_happens_if_i_dont_repair_my_weapons_and_what/`, `https://steamcommunity.com/app/3167020/discussions/0/601894623046035786/?l=swedish`, and `https://allthings.how/escape-from-duckov-repair-guide-gear-fixes-durability-and-early-repair-quests/` reinforce worn gear as persistent repairable state: current/max durability, ammo-driven wear differences, and broken gear that should stay in inventory for repair rather than disappearing.
- `https://www.reddit.com/r/EscapeFromDuckov/comments/1oybd3i/below_50_gun_durability_same_damage_but_larger/` includes community testing that worn armor keeps protecting until it reaches zero durability, while `https://allthings.how/escape-from-duckov-repair-guide-gear-fixes-durability-and-early-repair-quests/` describes armor durability degradation more broadly. For the template, treat zero durability as the first verified armor cutoff before adding any gradual armor-efficiency curve.
- `https://kamigame.jp/escapefromduckov/page/397651682101578383.html` states that equipment repair happens at the workbench repair station, that weapon spread rises under 50% durability, and that armor at zero durability fully stops functioning, supporting a hit-wear path that can naturally push armor into the existing broken-state cutoff.
- The 2026-07-04 durability refresh still shows disagreement around low-durability damage or jam rules, but is consistent enough on accuracy/spread impact and hard 0-durability failure. For now, prefer readable depleted/low-durability feedback over adding uncertain damage penalties.
- The 2026-07-04 weapon-stat refresh supports keeping recoil separate from spread: spread changes projectile grouping, while recoil is sustained-fire aim displacement that different weapon/ammo data can scale.

## Current DCG Comparison

Already close:

- 3D base with warehouse, workbench, medical, quest board, raid gate.
- Warehouse UI connected to save stash, backpack, equipment, and safe pocket.
- Warehouse screen now separates concerns closer to the corrected reference direction: the right panel is the warehouse, while the left panel is a backpack-transfer surface with All Store; it no longer redraws a separate character equipment grid.
- Raid loop has extraction/death persistence, enemy loot, locked containers, quests, and result panel.
- Validation coverage exists for stash storage, user-reported correctness, UI layout, and three-raid smoke flow.

Still different:

- Warehouse has manual transfer, item locking, and an All Store flow for safe bulk storage.
- Warehouse capacity now reads save-backed storage upgrade bonuses instead of being only a fixed UI export.
- Warehouse UI now exposes the first Storage Expansion purchase action and persists the result through the shared base progression/save path.
- Warehouse expansion now advances from Lv.1 to Lv.2, including a material-gated blocked state and Plastic Barrel as a rare loot material.
- Warehouse can now show needed-item marks from active item quests, workbench upgrade materials, the next storage-upgrade material requirement, and manual `N` marks saved per slot.
- Warehouse, container, codex, backpack, equipment, and safe-pocket item tooltips now share one presenter for value, weight, max stack, value/weight, combat stats, and needed-item sources where available.
- Warehouse, backpack, and container item lists now share item sorting by type, value, weight, and value/weight.
- Workbench recipes now have a data/resource template and can feed missing recipe materials into warehouse needed-item marks and tooltip sources.
- Workbench recipes can now execute against save-backed stash data: consume ingredients, create output stacks, and update the 3D workbench panel action.
- Workbench state now exposes recipe rows, a selected recipe id, and save-backed recipe selection, so future UI controls do not need to parse panel text or read recipe resources directly.
- Workbench recipe rows now render as selectable buttons in the 3D Base interaction panel, and button or keyboard/controller selection persists through `selected_recipe_ids` before crafting.
- Workbench now exposes a mode-tab surface after the upgrade is purchased: Craft is the active validated mode, while Blueprints, Repair, and Dismantle are visible unavailable mode slots for future services.
- Blueprint research now has a save-backed service: a blueprint item can be consumed from stash, persisted in `researched_blueprints`, and used by `required_blueprint_item_path` to unlock a matching Workbench recipe.
- A rare generic blueprint can now appear in the common-map loot table and unlock an original reclaimed-wire Workbench recipe after research.
- Backpack capacity comes from stats/equipment, but there is no skill or consumable progression lane.
- Workbench upgrade can unlock recipe material planning, selected craft execution, a multi-mode station surface, and a player-facing blueprint research mode that consumes stash blueprints and unlocks recipe rows.
- Repair now has item durability data, tooltip/codex presentation, a Fix Station upgrade gate, and save-backed Workbench repair for damaged warehouse gear.
- Backpack, equipment, container, warehouse, raid-loadout, and death-loss paths now preserve durable stack state through a shared save codec instead of recreating gear as fresh items.
- Workbench Repair now discovers and repairs damaged gear from stash, carried backpack, safe pocket, and equipped slots while keeping money deduction save-backed.
- Workbench Repair rows now label their source, so duplicate gear from stash/backpack/safe pocket/equipment is readable.
- Workbench Dismantle now has a Disassemble Station upgrade gate, data-backed dismantle recipes, save-backed selected row ids, stash capacity checks, and a 3D panel action flow.
- Combat-time weapon durability wear now consumes equipped weapon current durability when a shot is fired, and the worn equipment state is preserved by raid loadout transfer.
- Raid HUD now warns when the equipped firearm is under the durability penalty threshold or depleted, using centralized localization keys.
- Low-durability firearms now apply deterministic projectile spread from the equipped stack's current/max durability state, while keeping damage unchanged for this template slice.
- Ammo now carries a data-backed weapon wear rate, and fired shots use the currently loaded ammo to apply fractional durability wear while preserving wear progress in save-backed durable stacks.
- A first high-grade same-caliber ammo item now exists as rare map loot and a Workbench recipe, proving that lower weapon wear rates can be authored as real item data.
- Ammo now carries a data-backed damage multiplier, and WeaponController damage events apply the currently loaded ammo multiplier while baseline Ammo-S keeps existing damage.
- Ammo and armor now carry data-backed penetration/protection levels, and a shared `ArmorMitigationService` applies ballistic armor reduction for player, enemy, and generic damageable targets.
- Ammo now carries a data-backed spread multiplier, and PlayerController applies the currently loaded ammo multiplier to the existing low-durability projectile spread path.
- Depleted equipped firearms now block player firing before ammo/projectile consumption, preserve the repairable equipment stack, and keep the Raid HUD depleted-durability state visible.
- Depleted equipped body armor now contributes no flat defense or ballistic protection, while still remaining equipped and repairable through the existing durability stack.
- Equipped body armor now loses durability when the player accepts damage, so protection can wear down into the existing zero-durability failure state and repair loop.
- Death results now preserve armor durability after lethal hit wear, so dropped equipment context reflects the last combat exchange instead of pre-hit state.
- Raid HUD now prioritizes depleted firearm durability over empty-ammo status, so a broken empty weapon still communicates the repair problem instead of looking like a normal reload problem.
- Weapons now carry vertical/horizontal recoil data, ammo can scale recoil, and PlayerController applies sustained-fire recoil as a recoverable aim offset separate from durability spread.
- Raid HUD now spawns a full-screen recoil reticle sibling in the HUD CanvasLayer and updates it from `PlayerController3D.get_last_weapon_recoil_state()`, making sustained-fire recoil visible without coupling reticle drawing into gameplay scripts.
- The crafted Extended Magazine-S attachment now has a data-backed magazine-capacity bonus, flows through `WeaponAttachmentService`, expands the active pistol magazine from 8 to 12 rounds, and is visible in shared item tooltips.
- The Balanced Grip-S attachment now has data-backed vertical/horizontal recoil reduction and recoil-recovery multiplier fields, flows through the same `WeaponAttachmentService`, and affects PlayerController recoil impulse state.
- The first visible `weapon_mag`/`weapon_grip` equipment-slot implementation was corrected in pass 51: weapon mods now live under a weapon stack's `weapon_mods` state, and old direct `weapon_*` equipment slots migrate into the active weapon for save/backcompat.
- Weapon items can now declare `weapon_attachment_slots`; Pistol-S declares Mag/Grip/Muzzle/Scope/Stock support and `WeaponAttachmentService` filters equipped attachments by active weapon data before applying modifiers.
- The original Compact Muzzle-S, Reflex Sight-S, Stabilizing Stock-S, and Targeting Laser-S are now treated as weapon hardpoint candidates instead of character equipment lanes; their modifiers are read from the active weapon stack through `WeaponAttachmentService`. Scope cursor variants, muzzle sound/damage tradeoffs, jams, and low-durability damage penalties are not yet systemic.
- Quests are functional but do not yet drive a dense chain of map unlocks, recipes, and base growth.

## Parallel Task Lanes

Inventory and Warehouse:

- Add item locking in the warehouse UI. Status: done in pass 1.
- Add All Store behavior that respects locked slots. Status: done in pass 2, then moved to the backpack-transfer side of the warehouse screen in pass 53.
- Move warehouse capacity from a fixed export into save/base upgrade state. Status: done in pass 3.
- Add a player-facing Storage Expansion purchase surface or tab. Status: done in pass 4.
- Add warehouse expansion materials as item data and higher-tier base upgrade costs. Status: started in pass 5 with Plastic Barrel and Lv.2.
- Add `N` needed-material marking for quest/base needs. Status: expanded in pass 8 to active item quest requirements and unpurchased workbench upgrade materials.

Combat and Gear:

- Add weapon durability/repair data. Status: static item durability and tooltip/codex presentation started in pass 20; save-backed warehouse repair started in pass 22.
- Add combat-time durability wear. Status: basic equipped weapon wear on fired shots done in pass 27.
- Add player-facing low-durability warnings. Status: Raid HUD low/depleted durability status done in pass 28.
- Add low-durability combat consequences. Status: deterministic projectile spread done in pass 29; depleted/broken weapon fire block done in pass 35; damage and random jam rules still pending.
- Keep ammo simple. Status: ammo-specific wear, damage, penetration, spread, and recoil tuning were removed; ammo now stays compatibility/stack/catalog data only.
- Add armor penetration and armor-level damage reduction. Status: weapon-owned penetration, armor protection, shared mitigation service, and ammo-neutral damage validation covered.
- Expose recoil state through a visible crosshair/cursor UI. Status: done in pass 41 with a HUD CanvasLayer reticle driven by PlayerController recoil state.
- Add armor durability combat cutoff and wear. Status: zero-durability equipped body armor disables flat defense and ballistic protection in pass 36; armor wear-on-hit done in pass 37; gradual low-durability armor penalty still pending.
- Add attachment slot data to weapon items. Status: first runtime capacity modifier done in pass 42, first recoil/recovery grip modifier done in pass 43, first temporary visible equipment-slot bridge in passes 44-50, corrected in pass 51 so Mag/Grip/Muzzle/Scope/Stock/Tactic are weapon-owned hardpoints stored on the weapon stack, and validators retargeted in pass 52 so tests no longer pull the feature back into visible character equipment slots.
- Add weapon comparison/stat display. Depends on item tooltip work.

Base and Crafting:

- Add recipe data and needed-material planning. Status: started in pass 12 with one Workbench Lv.1 ammo recipe.
- Expand workbench into craft execution, blueprint research, repair, and dismantling services. Status: craft execution started in pass 13.
- Add blueprint research save data and route recipes by station. Status: service-level blueprint research started in pass 18.
- Add crafting material usage previews in stash/backpack tooltips. Depends on recipe model and tooltip model.

Quest and Map:

- Add a starter collection quest that requires extracted crafting material. Independent but should reuse existing QuestState.
- Add map unlock/intel flags. Depends on quest rewards.

UI and Localization:

- Replace remaining mojibake fallback text with localization keys.
- Keep item tooltip text and stat labels centralized in `data/localization/game_text.csv`.
- Keep UI layout validation for every player-facing panel.
- Prefer node-first stable screens, but allow custom-drawn inventory grids where grid math is the product surface.

## Active Slice

Workbench repair preparation:

- Keep recipe data and craft execution from passes 12 and 13. Status: done.
- Add more than one original Workbench template recipe so list behavior is validated against real data. Status: done.
- Add save-backed selected recipe ids by station. Status: done.
- Render recipe rows as player-clickable buttons inside the current 3D Base interaction panel. Status: done.
- Wire recipe button and keyboard/controller selection through `BaseInteractionController3D` to `BaseWorkbenchService.select_recipe()` and save data. Status: done.
- Validate service-level selection, selected craft execution, save round-trip, 3D panel recipe-list state, keyboard/controller row movement, and low-resolution panel fit. Status: done.
- Render Workbench station modes as a tab-like row owned by `BaseWorkbenchService` state and `BaseInteractionPanel` display code. Status: done.
- Use `BaseBlueprintService` for data-backed blueprint rows, consuming blueprint items from stash and persisting `researched_blueprints`. Status: done.
- Connect the Blueprints station mode to player-facing row/action controls in the 3D Workbench panel. Status: done in pass 19.
- Add static item durability fields and shared stack normalization for repairable items. Status: done in pass 20.
- Add Fix Station upgrade data and gate the Workbench Repair tab behind it. Status: done in pass 21.
- Add repair service skeleton with save-backed durability/cost validation. Status: done in pass 22 for warehouse stash gear.
- Preserve durable stack state across backpack, equipment, container, warehouse, raid loadout, and safe-pocket death return paths. Status: done in pass 23.
- Expand repair support from warehouse stash gear to carried backpack/equipment/safe-pocket gear through the same Workbench Repair service. Status: done in pass 24.
- Add source labels to Workbench Repair rows for duplicate damaged gear readability. Status: done in pass 25.
- Add Disassemble Station and Dismantle service skeleton with data-backed output rows and stash capacity checks. Status: done in pass 26.
- Add combat-time durability wear after repair execution and carried-gear persistence are stable. Status: done in pass 27 for basic fired-shot wear.
- Add player-facing low/depleted weapon durability warnings to the Raid HUD. Status: done in pass 28.
- Add low-durability spread consequences after the readable warning path is stable. Status: done in pass 29 for deterministic spread; no damage multiplier change yet.
- Keep ammo as compatibility/stack/catalog data instead of weapon-like stat carriers. Status: ammo-specific wear, damage, penetration, spread, and recoil tuning removed.
- Add armor penetration and armor-level damage reduction through weapon/armor data. Status: weapon-owned penetration, armor protection, shared ballistic mitigation, and ammo-neutral validation covered.
- Block depleted equipped weapon fire after low-durability spread and HUD depleted status are stable. Status: done in pass 35; blocked shots preserve loaded ammo and repairable durability state.
- Disable equipped armor protection at zero durability using the same durable-stack state used by repair and raid loss. Status: done in pass 36.
- Add armor durability wear-on-hit now that zero-durability armor no longer protects. Status: done in pass 37; the hit that breaks armor still uses pre-hit protection and the next hit gets no armor protection.
- Preserve worn armor durability in death/drop results after lethal hit wear. Status: validated in pass 38 through `RaidSession.build_result()`.
- Prioritize depleted weapon durability over empty-ammo HUD status for broken guns. Status: done in pass 39; validation covers 0 durability with 0 loaded ammo.
- Add first sustained-fire recoil handling. Status: done in pass 40 and simplified to weapon/attachment-owned recoil with recoverable aim offset state.
- Expose sustained-fire recoil as a visible reticle/cursor offset after the player recoil state is stable. Status: done in pass 41 with `RecoilReticle` as a draw-only HUD sibling.
- Make the first crafted attachment affect combat state instead of staying tooltip-only. Status: done in pass 42 with Extended Magazine-S capacity bonus, `WeaponAttachmentService`, model-backed 12-round reload, and shared tooltip row.
- Add grip-style attachment recoil tuning after the reticle surface and attachment service are stable. Status: done in pass 43 with Balanced Grip-S vertical/horizontal recoil multipliers, recovery multiplier, loot entry, tooltip rows, and player recoil-state bridge.
- Replace the temporary visible weapon-mod equipment slots with weapon-owned hardpoints so attachments stop pretending to be character gear. Status: corrected in pass 51 by hiding `weapon_*` from inventory/base stash equipment surfaces, persisting installed mods inside the weapon stack, and migrating old direct slots into the active weapon.
- Add weapon-authored compatibility slot lists so pistols/rifles can declare which mod categories they support instead of relying only on attachment tags. Status: done in pass 45 for Pistol-S Mag/Grip support and service-level rejection for melee or single-slot temporary weapons.
- Add first muzzle attachment after weapon compatibility lists exist. Status: data/item effect done in pass 46, then ownership corrected in pass 51 so Compact Muzzle-S installs into a weapon hardpoint instead of a visible equipment slot.
- Add first sight/scope attachment after choosing its template effect surface. Status: data/item effect done in pass 47, then ownership corrected in pass 51 so Reflex Sight-S installs into a weapon hardpoint instead of a visible equipment slot.
- Surface supported weapon mod categories in shared weapon tooltips. Status: done in pass 48 by reading `weapon_attachment_slots` through `ItemStackTooltipPresenter` and localized equipment-slot labels.
- Add first stock attachment through existing recoil/recovery fields. Status: data/item effect done in pass 49, then ownership corrected in pass 51 so Stabilizing Stock-S installs into a weapon hardpoint instead of a visible equipment slot.
- Add first tactic/laser attachment through existing spread fields. Status: data/item effect done in pass 50, then ownership corrected in pass 51 so Targeting Laser-S installs into a weapon hardpoint instead of a visible equipment slot.
- Correct user-reported inventory direction before adding more attachment features. Status: done in pass 51 for Pistol-S weapon-mounted `weapon_mods`, basic left-click mod panel opening, backpack-to-weapon install/remove bridge, hidden `weapon_*` equipment slots in inventory/base stash, and hidden container sort button; pass 52 rewrote attachment validators around this corrected direction; pass 53 corrected the warehouse screen so the left side is backpack transfer rather than a duplicated equipment UI; pass 54 corrected the post-raid Continue wording/validation so extraction returns to base without forcing the warehouse page open; pass 55 started shared backpack/warehouse UI ownership by moving common grid geometry and hit testing into `InventoryGridMetrics`; pass 56 moved shared L/N cell badges into `InventoryEquipmentPainter` so warehouse item-state decoration is no longer hand-drawn inside stash logic; pass 57 improved the Pistol-S weapon-mod panel readability with localized slot/empty/installed text while keeping mods weapon-owned; pass 58 added installed-mod effect summaries inside the opened weapon panel using existing attachment modifier data; pass 59 removed remaining warehouse-style sorting responsibility from the raid/container loot UI; pass 60 cleaned the raid-result fallback text and added a source-level mojibake guard so Continue remains a base-return action, not a warehouse-opening action; pass 61 removed the hidden SortButton node from the container loot scene and added scene/source mojibake guards; pass 62 cleaned stale base-station "connected" wording from localization and panel fallbacks so facilities read as player actions rather than prototype wiring; pass 63 removed obsolete `ui.container.sorted_*` localization keys and validator-locked them out while preserving warehouse/backpack sorting; pass 64 corrected the Workbench station hint/body so locked repair and dismantle modes are described as station-gated instead of immediately available; pass 65 updated completed-system item descriptions for Level 1 Armor and Warehouse Key, and added text-quality guards against stale future wording.

## Next Candidates

1. Continue shared UI ownership only when the next extraction is behavior-neutral and backed by validators.
2. Add richer weapon stat comparison only after the underlying weapon stat model has a stable read API.
3. Continue shared UI ownership only when the next extraction is behavior-neutral and backed by validators.
4. Add richer weapon stat comparison only after the underlying weapon stat model has a stable read API.
5. Keep auditing item descriptions, but only update items whose referenced systems are already implemented and validated.
