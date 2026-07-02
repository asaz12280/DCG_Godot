# Project DCG Player Visibility V2 Task Queue

Last updated: 2026-07-02

## Purpose

This queue replaces `player_visibility_task_queue.md` for the next automation phase. The earlier queue improved visible UI, but the target flow has changed: Base must become a 3D space, containers need visible capacity slots, pistol/ammo must be found and equipped, reload must be visible, and shooting must use visible 3D projectiles.

## Automation Rules

1. Start from the first task whose status is not `完成`, unless an independent task is explicitly listed as safe to run in parallel and its dependencies are complete.
2. Parallel work is allowed only when files and responsibilities do not overlap.
3. Do not add content volume: no second raid map, no new weapon list, no new enemy type, no final art pass.
4. Use current No.5 pistol and No.7 ammo for weapon/ammo proof.
5. Use Godot node-first UI for stable panels.
6. All player-visible text must be Traditional Chinese.
7. After every three completed tasks, run a Project Health Check before continuing.
8. If a task requires architectural cleanup, prefer decoupling over adding more bridging logic.
9. Update `docs/tasks/progress_log.md` after every completed task.
10. Commit and push completed slices to the current backup branch when validation passes.

## Parallel Work Policy

- Base scene work may run in parallel with container inventory model work.
- UI tab panels may run in parallel with projectile visuals after `UIManager` boundaries are checked.
- Equipment/reload/projectile tasks should not run in parallel until `EquipmentModel` exists.
- Container transfer and backpack/equipment transfer should not run in parallel if they touch the same inventory APIs.
- Health checks and validation tasks are serial gates.

## Health Check Scope

Each Project Health Check must inspect:

- Player flow reachability.
- 3D Base vs 2D panel responsibility.
- Inventory vs equipment vs weapon boundaries.
- Container inventory vs player backpack boundaries.
- UIManager ownership of active panels.
- Traditional Chinese text quality.
- Node-first UI layout at 1280x720 and 1920x1080.
- Save/load safety.
- Scene loadability.
- Validation coverage.

## Tasks

## 任務一：重寫玩家可視化方向文件

狀態：完成

目標：把新的玩家可視化方向寫入專案文件，取代「2D Base 即基地」的錯誤方向。

完成條件：
- `docs/design/player_visibility_v2_direction.md` 存在。
- 任務清單明確要求 3D Base、箱子容量格、裝備手槍、裝填、3D 子彈。

驗證：
- 人工檢查文件內容。

## 任務二：建立專案健康檢查基準

狀態：完成

目標：先盤點目前 Base、Loot、Inventory、Equipment、Weapon、Quest、UIManager 的耦合狀況。

完成條件：
- 新增或更新 health check 驗證工具。
- 產出目前錯誤耦合清單與保護規則。

驗證：
- `validate_gameplay_architecture.gd`
- `validate_player_visibility_v2_health.gd`

## 任務三：建立 3D Base 場景雛形

狀態：完成

目標：選難度後進入簡單 3D 基地，而不是全螢幕 2D Base 面板。

完成條件：
- 新增 3D Base scene。
- 有地板、牆面/邊界、玩家、相機、基礎互動點位置。
- 不使用最終美術。

驗證：
- `validate_base_3d_scene.gd`
- Base 3D scene headless startup。

## 任務四：建立 Base 互動點

狀態：完成

目標：在 3D Base 中放置倉庫、任務板、工作台、出擊門。

完成條件：
- 玩家靠近互動點會看到繁中提示。
- 按互動鍵能開啟對應面板或開始出擊。

驗證：
- `validate_base_interactions.gd`

## 任務五：拆分舊 BaseScreen 職責

狀態：完成

目標：舊 BaseScreen 改為可被 3D Base 呼叫的功能面板，不再承擔整個基地場景。

完成條件：
- Base UI display、stash rows、quest display、workbench display、Base actions 有清楚邊界。
- 3D Base flow 不直接塞入舊 BaseScreen 大腳本。

驗證：
- `validate_base_screen.gd`
- `validate_base_flow.gd`
- `validate_base_screen_responsibilities.gd`
- V2 health check。

## 任務六：建立 ContainerInventoryModel

狀態：完成

目標：箱子有自己的容量格子與物品堆疊，不直接把物品塞進玩家背包。

完成條件：
- 支援容量、格子、堆疊、移除、序列化。
- 不依賴 UI。

驗證：
- `validate_container_inventory_model.gd`

## 任務七：建立箱子內容 UI

狀態：完成

目標：像參考圖五一樣，打開箱子後顯示箱子名稱、容量例如 `2/4`、物品格子。

完成條件：
- Stable UI 使用 `.tscn`/Control/Container。
- 1280x720 和 1920x1080 不溢出。
- 所有可見文字為繁中。

驗證：
- `validate_container_inventory_ui.gd`
- `validate_ui_text_quality.gd`

## 任務八：改造箱子開啟流程

狀態：完成

目標：靠近箱子按鍵開啟內容 UI，不直接拾取全部物品。

完成條件：
- LootContainer3D 只負責開啟、生成/持有箱子內容與狀態。
- ContainerInventoryUI 顯示內容。
- UIManager 管理開關與輸入阻擋。

驗證：
- `validate_loot_container.gd`
- `validate_container_open_flow.gd`

## 任務九：箱子物品轉移到背包

狀態：完成

目標：玩家可以把箱子物品移到背包，箱子容量與背包容量都會更新。

完成條件：
- 支援點擊或拖曳轉移。
- 背包滿時有清楚回饋。
- 箱子已取走的格子會變空。

驗證：
- `validate_container_transfer.gd`

## 任務十：把 No.5 手槍與 No.7 子彈放入早期箱子

狀態：完成

目標：使用現有 No.5 手槍與 No.7 子彈驗證流程，不新增大量物品。

完成條件：
- 早期箱子可見手槍與子彈。
- 名稱與圖鑑一致。

驗證：
- `validate_container_transfer.gd`
- `validate_item_catalog.gd`

## 任務十一：建立 EquipmentModel

狀態：完成

目標：裝備欄獨立於背包，支援主武器、副武器、近戰、護甲等欄位。

完成條件：
- EquipmentModel 不依賴 UI。
- 可裝備/卸下合法 item。
- 不合法 item 不能放入錯誤欄位。

驗證：
- `validate_equipment_model.gd`

## 任務十二：背包物品可裝備

狀態：完成

目標：玩家能把背包中的手槍放到裝備欄。

完成條件：
- 背包 UI 顯示手槍在背包。
- 裝備後裝備欄顯示手槍。
- 背包與裝備資料一致。

驗證：
- `validate_inventory_equipment_flow.gd`

## 任務十三：解除玩家預設手槍耦合

狀態：完成

目標：Player 不再出生就固定有可射擊手槍；WeaponController 改讀 EquipmentModel。

完成條件：
- 未裝備武器時不能射擊。
- 裝備手槍後 WeaponController 顯示目前武器。

驗證：
- `validate_weapon_equipment_binding.gd`

## 任務十四：建立 Ammo/Magazine 裝彈資料

狀態：完成

目標：子彈、彈匣、備用彈藥和武器狀態分開管理。

完成條件：
- 手槍彈匣容量明確。
- No.7 子彈可被手槍使用。
- 彈藥數不再只是 WeaponController 假數字。

驗證：
- `validate_ammo_reload_model.gd`

## 任務十五：R 鍵裝填

狀態：完成

目標：玩家按 `R` 可裝填子彈。

完成條件：
- 有相容彈藥時開始裝填。
- 無彈藥時顯示回饋。
- 裝填完成後彈匣數量更新。

驗證：
- `validate_reload_flow.gd`

## 任務十六：空彈左鍵自動裝填

狀態：完成

目標：左鍵射擊時如果彈匣空且背包有彈藥，觸發裝填而不是無反應。

完成條件：
- 空彈左鍵能啟動裝填。
- 裝填中不能射擊。

驗證：
- `validate_reload_flow.gd`

## 任務十七：建立裝填時間條 UI

狀態：完成

目標：裝填過程中玩家能看到進度條。

完成條件：
- Reload progress visible。
- 裝填完成/取消狀態清楚。
- 不遮擋主要畫面。

驗證：
- `validate_reload_ui.gd`

## 任務十八：建立 3D 子彈 Projectile

狀態：完成

目標：射擊時生成可見 3D 子彈模型，從槍口或玩家方向射出。

完成條件：
- Projectile 有簡單 3D mesh。
- 能沿瞄準方向飛行。
- 不永久殘留。

驗證：
- `validate_projectile_3d.gd`

## 任務十九：Projectile 命中處理

狀態：未開始

目標：Projectile 命中敵人或物件時產生命中回饋並套用傷害。

完成條件：
- 命中 damageable 會扣血。
- 命中後 projectile 消失。
- 有可見命中回饋。

驗證：
- `validate_projectile_hit.gd`
- `validate_combat_domain.gd`

## 任務二十：Projectile 未命中處理

狀態：未開始

目標：子彈飛到距離上限或撞牆後消失。

完成條件：
- 不會累積無限 projectile。
- 未命中有簡單可見回饋或消失規則。

驗證：
- `validate_projectile_3d.gd`

## 任務二十一：射擊回饋 HUD

狀態：未開始

目標：HUD 顯示目前武器、彈匣、備用彈藥、裝填中狀態。

完成條件：
- 未裝備、空彈、裝填中、可射擊四種狀態可讀。
- 繁中顯示。

驗證：
- `validate_raid_hud.gd`
- `validate_reload_ui.gd`

## 任務二十二：修正 Raid HUD 大面板問題

狀態：未開始

目標：HUD 不像大面板遮住畫面，詳細任務移到任務頁籤。

完成條件：
- Raid HUD 只保留簡潔戰鬥/目標摘要。
- 不遮擋主要視野。

驗證：
- `validate_raid_hud.gd`
- 1280x720 / 1920x1080 fit check。

## 任務二十三：任務清單移入 Top Menu 第二頁籤

狀態：未開始

目標：任務列表收納在 Top Menu 的任務頁籤，不散落在錯誤位置。

完成條件：
- 第二頁籤可開啟任務列表。
- 顯示收集/擊殺任務與狀態。

驗證：
- `validate_top_menu_panels.gd`
- `validate_quest_flow.gd`

## 任務二十四：角色狀態頁籤

狀態：未開始

目標：Top Menu 第三頁籤顯示生命、體力、負重、裝備、武器彈藥。

完成條件：
- 資訊來自玩家/裝備模型。
- 不複製遊戲狀態。

驗證：
- `validate_top_menu_panels.gd`

## 任務二十五：地圖頁籤早期版

狀態：未開始

目標：Top Menu 第四頁籤顯示目前區域、撤離方向、基地/出擊狀態。

完成條件：
- 可開啟。
- 文字繁中可讀。
- 不需要完整大地圖。

驗證：
- `validate_top_menu_panels.gd`

## 任務二十六：圖鑑一致性檢查

狀態：未開始

目標：No.5 手槍、No.7 子彈在箱子、背包、裝備欄、圖鑑名稱一致。

完成條件：
- 顯示名稱一致。
- 圖鑑 catalog number 正確。

驗證：
- `validate_item_catalog.gd`
- `validate_codex_item_consistency.gd`

## 任務二十七：3D Base 到 Raid 裝備帶入

狀態：未開始

目標：從 3D Base 出擊時，玩家帶著目前背包與裝備進入 Raid。

完成條件：
- 背包、裝備、彈藥狀態可帶入。
- 不是 raid scene 自動硬塞裝備。

驗證：
- `validate_base_to_raid_loadout.gd`

## 任務二十八：Raid 結算回 3D Base

狀態：未開始

目標：撤離或死亡後結算，再回到 3D Base 查看物品、任務、金錢、裝備狀態。

完成條件：
- 結算後返回 3D Base。
- 狀態更新可見。

驗證：
- `validate_raid_return_to_base_3d.gd`
- `validate_three_raid_loop.gd`

## 任務二十九：刪除錯誤捷徑

狀態：未開始

目標：移除或停用直接給槍、直接開箱入背包、2D Base 當完整基地等錯誤流程。

完成條件：
- 錯誤捷徑不再由正常玩家流程觸發。
- 保留必要測試 helper，但標示清楚。

驗證：
- V2 health check。
- `validate_player_visible_v2_slice.gd`

## 任務三十：玩家可見 V2 Smoke Test

狀態：未開始

目標：驗證完整可見流程。

完成條件：
- 進 3D Base。
- 出擊。
- 開箱看到容量格。
- 拿 No.5 手槍與 No.7 子彈。
- 裝備手槍。
- R 裝填並看到進度條。
- 射出 3D 子彈。
- 撤離。
- 回到 3D Base。

驗證：
- `validate_player_visible_v2_slice.gd`
- Standard Validation Set。
