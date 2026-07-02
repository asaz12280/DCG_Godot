# Project DCG Player Visibility V2 Direction

Last updated: 2026-07-02

## Purpose

This direction supersedes the earlier player-visibility phase where Base was treated as a 2D screen. The user's updated target is a player-visible, Duckov-like early loop:

1. Start game and choose difficulty.
2. Enter a small 3D Base space, not a full-screen 2D Base panel.
3. Use Base interaction points for stash, quests, workbench, and raid start.
4. Enter the first raid.
5. Open a loot container that has visible capacity slots.
6. Move No.5 pistol and No.7 ammo from the container into the backpack.
7. Equip the pistol from backpack into an equipment slot.
8. Reload with `R`, or auto-start reload when left-clicking with an empty magazine and compatible ammo.
9. Show a reload progress bar.
10. Fire visible 3D projectile bullets.
11. Extract, see results, and return to the 3D Base.

## Corrected Design Decisions

- The 2D Base screen is no longer the complete Base experience. It can be reused as a panel opened from 3D Base interaction points.
- The player should not start with an always-ready pistol. The pistol must come from loot, be equipped, and be loaded with ammo before shooting.
- Loot containers should not directly push all rolled loot into the backpack. A container has its own visible inventory grid and capacity.
- Raid HUD should stay compact. Detailed quests belong in the top menu Quest tab.
- Top menu tabs are player-facing navigation: backpack, quests, character status, map, and item codex.

## Coupling Rules

- `PlayerController3D` owns movement and input routing only. It should not hard-code starter weapons, ammo, loot, quests, or Base flow.
- `InventoryModel` owns item stacks in a container-like grid. It should not know about equipped weapon behavior.
- `EquipmentModel` owns equipped slots. It should not draw UI or decide loot contents.
- `WeaponController3D` owns firing, reload state, ammo consumption, projectile spawning, and combat signals. It should read the currently equipped weapon/ammo through a small API, not through backpack UI.
- `LootContainer3D` owns container state and opening interaction. It should not directly own player backpack UI.
- `ContainerInventoryUI` displays and transfers container items. It should emit user intent and call inventory/container APIs, not roll loot by itself.
- `UIManager` owns active UI state, focus, mouse mode, and input blocking.
- Stable UI panels should be `.tscn`/`Control`/Container based. Script-created UI is limited to dynamic rows, temporary indicators, or validation helpers.

## Completion Standard

A task is not complete just because a script exists. It is complete only when:

- The feature is reachable through normal play.
- The feature is visible to the player.
- The feature uses readable Traditional Chinese text.
- The implementation keeps responsibility boundaries clean.
- A focused validation script or headless scene check proves the player-visible behavior.

