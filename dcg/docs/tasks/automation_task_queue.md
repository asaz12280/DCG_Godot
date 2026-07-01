# Project DCG Automation Task Queue

Last updated: 2026-07-01

This file is the sequential task queue for Codex-driven development. Earlier tasks have higher priority. The automation rule is simple: start from the first task that is not marked complete, finish its acceptance criteria, run its validation, then move to the next task.

## Automation Rules

1. Do not skip ahead unless every earlier task is already complete or its acceptance criteria are already satisfied by the current codebase.
2. A task is complete only when its acceptance criteria and validation checks pass.
3. If a task is blocked, stop and record the blocker in this file or `docs/tasks/progress_log.md`; do not silently work around it by starting a later feature.
4. Keep each implementation narrow. Do not add extra systems, extra maps, extra weapons, or final art unless the active task asks for it.
5. Preserve the current boundaries: gameplay state belongs to gameplay models/services, UI displays and commands state, and item/content data should stay data-driven.
6. Add or update a `tools/validate_*.gd` script whenever a task introduces a new gameplay domain or persistence rule.
7. After each completed task, update `docs/tasks/progress_log.md` with Completed and Verified notes.
8. After every three numbered tasks, run the Project Health Check before starting the next numbered task. This means after 任務三、六、九、十二、十五、十八、二十一、二十四、二十七、三十.
9. New UI screens and reusable panels should be Godot node-first. Prefer `.tscn` scenes, `Control` nodes, containers, `Label`, `Button`, `PanelContainer`, `ScrollContainer`, `GridContainer`, and theme resources before building whole panels in code.
10. Script-created UI is allowed for dynamic repeated children, temporary debug UI, or custom drawing that is genuinely hard to express with nodes, but the task must record why it is acceptable.
11. If a health check finds small architecture or UI maintainability issues, fix them before continuing. If the issue is too large for the current slice, record it as technical debt in `docs/tasks/progress_log.md` and do not hide it.
12. UI tasks are not complete just because the code runs. Any task that creates or changes player-facing UI must pass the UI Layout Quality Check in `docs/design/ui_layout_quality_guide.md`.

## Project Health Check

Run this after every three completed numbered tasks.

Health check trigger points:

- After 任務三, before 任務四.
- After 任務六, before 任務七.
- After 任務九, before 任務十.
- After 任務十二, before 任務十三.
- After 任務十五, before 任務十六.
- After 任務十八, before 任務十九.
- After 任務二十一, before 任務二十二.
- After 任務二十四, before 任務二十五.
- After 任務二十七, before 任務二十八.
- After 任務三十, before any post-slice content expansion.

Health checklist:

- Responsibility boundaries: gameplay/domain scripts must not absorb unrelated UI, save, economy, quest, or scene-flow logic.
- UI ownership: UI reads models/services and emits user intent; UI must not become the authoritative owner of persistent gameplay state.
- Godot node-first UI: new stable screens and panels should be `.tscn` scenes using Godot UI nodes and containers. Avoid building entire reusable interfaces only through code when node composition can do the job.
- UI layout quality: inspect base panels, buttons, spacing, alignment, visual hierarchy, readability, and responsive fit using `docs/design/ui_layout_quality_guide.md`. A UI that only works technically but looks cramped, uneven, or confusing is not healthy.
- Script size and focus: if a script grows beyond roughly 300-350 lines or mixes multiple responsibilities, split it into focused helpers before adding more behavior.
- Data-driven content: items, loot tables, enemies, quests, upgrades, and map settings should be resources/data rather than hard-coded branches.
- Coupling scan: avoid direct references from domain systems to specific UI node paths. Use methods, signals, models, or autoload services.
- Save safety: schema changes must preserve old-slot safety or clearly migrate defaults.
- Localization: new player-facing text should use localization keys or a clearly temporary fallback.
- Scene health: gameplay scenes should load headless, and new scenes should not depend on editor-only state.
- Validation health: new systems should have `tools/validate_*.gd`, and old validation should still pass.

Health check actions:

- Fix small issues immediately.
- Add or update validation if the issue can recur.
- For UI issues, fix layout, spacing, button sizing, text fit, or node structure before adding new features.
- Record larger issues in `docs/tasks/progress_log.md` with a clear follow-up.
- Only continue to the next numbered task after the health check is complete or the blocker is recorded.

## UI Layout Quality Check

Use `docs/design/ui_layout_quality_guide.md` for the detailed checklist. This check is required for every UI-facing task and every Project Health Check.

Minimum review items:

- The screen has clear visual hierarchy: purpose, content, primary action, secondary action.
- Base panels have consistent padding and margins.
- Buttons are readable, consistently sized, and aligned.
- Row/section spacing looks intentional.
- Text does not clip or overflow in Traditional Chinese, Simplified Chinese, Japanese, or English keys used by the screen.
- The layout works at `1280x720` and `1920x1080`.
- No important controls overlap or sit too close to screen edges.
- Stable UI is built from Godot nodes/scenes when possible, not entirely hard-coded in script.
- The UI still looks acceptable with placeholder art and leaves room for later art replacement.

Pass condition:

- The UI should look clean enough that final art can be added later without rebuilding the layout.
- If the UI looks uneven, cramped, confusing, or visually accidental, the task is not complete.

## Standard Validation Set

Run these after tasks that touch shared gameplay, UI, save, items, or scene wiring:

```powershell
& 'C:\Users\User\Desktop\Godot_v4.7-stable_win64.exe' --headless --path .\dcg --script res://tools/validate_item_catalog.gd
& 'C:\Users\User\Desktop\Godot_v4.7-stable_win64.exe' --headless --path .\dcg --script res://tools/validate_ui_foundation.gd
& 'C:\Users\User\Desktop\Godot_v4.7-stable_win64.exe' --headless --path .\dcg --script res://tools/validate_inventory_drag_rules.gd
& 'C:\Users\User\Desktop\Godot_v4.7-stable_win64.exe' --headless --path .\dcg --script res://tools/validate_gameplay_architecture.gd
& 'C:\Users\User\Desktop\Godot_v4.7-stable_win64.exe' --headless --path .\dcg --script res://tools/validate_combat_domain.gd
& 'C:\Users\User\Desktop\Godot_v4.7-stable_win64.exe' --headless --path .\dcg --script res://tools/validate_difficulty_system.gd
& 'C:\Users\User\Desktop\Godot_v4.7-stable_win64.exe' --headless --path .\dcg --script res://tools/validate_save_slots.gd
& 'C:\Users\User\Desktop\Godot_v4.7-stable_win64.exe' --headless --path .\dcg --script res://tools/validate_save_slot_panel.gd
& 'C:\Users\User\Desktop\Godot_v4.7-stable_win64.exe' --headless --path .\dcg --script res://tools/validate_audio_settings.gd
& 'C:\Users\User\Desktop\Godot_v4.7-stable_win64.exe' --headless --path .\dcg --script res://tools/validate_pause_menu.gd
& 'C:\Users\User\Desktop\Godot_v4.7-stable_win64.exe' --headless --path .\dcg --quit-after 1
& 'C:\Users\User\Desktop\Godot_v4.7-stable_win64.exe' --headless --path .\dcg res://scenes/gameplay/player_test_world_3d.tscn --quit-after 1
```

## Task Status Legend

- `未開始`: no known implementation.
- `進行中`: implementation started but acceptance criteria not fully verified.
- `完成`: acceptance criteria and validation passed.
- `封鎖`: cannot continue without a decision or external fix.

## 任務一：建立自動化基準線

狀態：完成

目標：確認目前專案可以作為後續自動化開發的穩定起點。

工作內容：

- 跑完 Standard Validation Set。
- 若有非本任務引入的舊錯誤，分清楚是阻擋性錯誤還是舊的非致命訊息。
- 確認 `docs/design/early_development_plan.md` 與本文件存在。
- 確認 `docs/design/ui_layout_quality_guide.md` 存在，後續 UI 任務都要遵守。
- 確認本文件的 Project Health Check 規則存在，後續每三個任務都要執行。
- 在 `docs/tasks/progress_log.md` 加上基準線驗證紀錄。

完成條件：

- 主選單可 headless 啟動。
- gameplay 測試場景可 headless 啟動。
- 既有核心驗證腳本通過，或明確記錄非阻擋舊訊息。

驗證：

- Standard Validation Set。

## 任務二：建立 `StashModel`

狀態：完成

目標：建立永久倉庫資料模型，讓撤離後的物資有地方保存。

工作內容：

- 新增 `scripts/base/stash_model.gd`。
- 支援加入物品、移除物品、合併堆疊、查詢總物品、序列化、反序列化。
- 使用 item resource path 作為可保存識別。
- 不依賴 UI 節點。
- 新增 `tools/validate_stash_model.gd`。

完成條件：

- Stash 可以加入 `ItemDef` 並合併相同可堆疊物品。
- Stash 可以轉成可寫入 JSON 的 Dictionary/Array。
- Stash 可以從 Dictionary/Array 還原。

驗證：

- `validate_stash_model.gd` 通過。
- `validate_item_catalog.gd` 通過。

## 任務三：擴充存檔格式為 Save Schema v1

狀態：完成

目標：讓 save slot 不只保存場景和難度，也保存早期遊戲進度。

工作內容：

- 擴充 `SaveGameManager` 的 slot data。
- 增加 `version`、`money`、`stash`、`base_upgrades`、`quests` 欄位。
- 保留舊 slot metadata 讀取相容性。
- 新增或更新 save/load round-trip 驗證。

完成條件：

- 新存檔包含 schema version。
- 儲存後重新讀取可還原 difficulty、money、stash、base upgrade、quest 欄位。
- 空槽與舊格式不會讓 UI 崩潰。

驗證：

- `validate_save_slots.gd` 更新後通過。
- `validate_stash_model.gd` 通過。

## 任務四：建立最小 Base Screen

狀態：完成

目標：讓玩家在 raid 之外有一個可回到的基地/倉庫畫面。

工作內容：

- 新增 `scenes/base/base_screen.tscn`。
- 新增 `scripts/base/base_screen.gd`。
- Base UI 以 `.tscn` 和 Godot `Control` 節點/容器為主，腳本只負責資料綁定、按鈕事件、狀態刷新。
- 顯示目前 save slot、難度、money、stash 清單。
- 提供 Start Raid 按鈕。
- 先不做完整基地美術，使用簡單 UI。

完成條件：

- Base screen 可以獨立載入。
- Base screen 可顯示空 stash 與有內容的 stash。
- Start Raid 按鈕可以切換到目前 gameplay 測試場景。
- Base screen 不是整個用程式動態畫出來的 reusable UI；穩定版布局應存在於 `.tscn` 節點中。
- Base screen 通過 UI Layout Quality Check，至少確認 panel padding、button spacing、文字可讀性、1280x720/1920x1080 fit。

驗證：

- 新增 `tools/validate_base_screen.gd`。
- Main menu headless 啟動通過。

## 任務五：調整新遊戲與讀取流程進入 Base

狀態：完成

目標：讓主選單流程從「直接進 gameplay」改成「建立/讀取 save -> 進 Base」。

工作內容：

- Start Game 選難度後建立 save slot。
- 新遊戲成功後進入 `base_screen.tscn`。
- Load Save 繼續時進入 Base。
- Base 的 Start Raid 再進 gameplay。

完成條件：

- 新局會建立或覆寫指定 save slot。
- 讀取既有 slot 後進 Base。
- Base 可以開始 raid。

驗證：

- `validate_save_slots.gd` 通過。
- `validate_base_screen.gd` 通過。
- 主選單 headless 啟動通過。

## 任務六：建立 `RaidSession`

狀態：完成

目標：建立一次 raid 的權威狀態管理者。

工作內容：

- 新增 `scripts/raid/raid_session.gd`。
- 支援開始 raid、取得狀態、標記撤離、標記死亡、建立結果資料。
- 狀態至少包含 `active`、`extracted`、`dead`、`elapsed_time`。
- 先不做複雜地圖資料。

完成條件：

- RaidSession 可以在測試中開始、成功、失敗。
- 同一次 raid 不會同時是 extracted 與 dead。
- 可以輸出 result dictionary。

驗證：

- 新增 `tools/validate_raid_session.gd`。

## 任務七：建立 Extraction Zone

狀態：完成

目標：讓玩家可以在地圖中完成撤離。

工作內容：

- 新增 `scripts/raid/extraction_zone_3d.gd`。
- 新增簡單 `ExtractionZone` 節點到 gameplay 測試場景。
- 玩家進入範圍後開始倒數。
- 倒數完成後通知 RaidSession。
- 顯示最小提示文字或 HUD 訊息。

完成條件：

- 玩家進入撤離區後可以觸發撤離成功。
- 玩家離開區域會取消或暫停撤離倒數。
- 撤離不依賴背包 UI 是否開啟。

驗證：

- 新增 `tools/validate_extraction_flow.gd`。
- gameplay scene headless 啟動通過。

## 任務八：建立 Raid Result Data

狀態：完成

目標：定義 raid 結果資料，讓 UI 和 save 都使用同一份結果。

工作內容：

- 新增 `scripts/raid/raid_result.gd` 或明確 result dictionary schema。
- 結果包含 `outcome`、`extracted_items`、`lost_items`、`kept_safe_pocket_items`、`money_delta`、`duration`。
- RaidSession 使用這個格式。

完成條件：

- 成功撤離可以產生 extracted result。
- 死亡可以產生 death result。
- result 可序列化，不直接保存 Node reference。

驗證：

- `validate_raid_session.gd` 更新後通過。

## 任務九：建立 Raid Result Panel

狀態：完成

目標：讓玩家在撤離或死亡後看到明確結算。

工作內容：

- 新增 `scenes/ui/raid_result_panel.tscn`。
- 新增 `scripts/ui/raid_result_panel.gd`。
- Result UI 以 Godot `Control` 節點和容器組成，腳本只負責套資料與按鈕事件。
- 可顯示成功/死亡、帶出物品、失去物品、money 變動。
- 提供 Continue to Base 按鈕。
- 先用簡單 Control UI，不做美術精修。

完成條件：

- Result panel 可以用假資料顯示。
- Continue to Base 可以回到 Base。
- UI 不直接修改 stash；只呼叫結果套用流程。
- 穩定版 Result panel 的主要節點結構存在於 `.tscn`，不是整個面板由腳本硬編碼建立。
- Result panel 通過 UI Layout Quality Check，帶出/失去物品列表、主按鈕、返回動線都要清楚。

驗證：

- 新增 `tools/validate_raid_result_panel.gd`。
- `validate_ui_foundation.gd` 通過。

## 任務十：完成撤離成功物資轉移

狀態：完成

目標：撤離成功後把玩家 raid 物品存入永久 stash。

工作內容：

- Raid 成功時讀取玩家 backpack inventory。
- 把可帶出的物品加入 `StashModel`。
- 清理 raid inventory 或開始下一場時重建。
- 保存 slot。

完成條件：

- 玩家撿到物品並撤離後，Base stash 會出現該物品。
- 重新讀取 save 後 stash 還存在。
- 不透過 UI 硬塞資料。

驗證：

- 新增或更新 `tools/validate_extraction_flow.gd`。
- `validate_save_slots.gd` 通過。
- gameplay scene headless 啟動通過。

## 任務十一：完成死亡與遺失規則

狀態：完成

目標：讓 raid 有失敗成本，建立撤離類遊戲的核心張力。

工作內容：

- 定義玩家死亡或 raid fail 時的 loss rule。
- 背包物品死亡時遺失。
- 安全口袋物品可保留，若安全口袋資料尚未完整，先保留規則接口。
- 死亡後進 Result panel。

完成條件：

- Death result 可列出 lost items。
- 死亡不會把 backpack 物品加入 stash。
- Safe pocket 保留規則有測試覆蓋或明確 TODO。

驗證：

- `validate_extraction_flow.gd` 更新後通過。
- `validate_gameplay_architecture.gd` 通過。

## 任務十二：建立 LootTable Resource

狀態：完成

目標：讓 loot 來源資料化，避免每個場景手塞固定物品。

工作內容：

- 新增 `scripts/loot/loot_table.gd`。
- 新增 `scripts/loot/loot_table_entry.gd` 或等效 typed Resource。
- 每筆 entry 包含 item path、min/max quantity、weight、optional tags。
- 新增 `data/loot_tables/refuge_outskirts_common.tres`。

完成條件：

- LootTable 可以 roll 出 1 個或多個有效 item stack。
- 無效 item path 會被驗證抓出。
- 空 table 會被驗證抓出。

驗證：

- 新增 `tools/validate_loot_tables.gd`。
- `validate_item_catalog.gd` 通過。

## 任務十三：建立 LootContainer3D

狀態：完成

目標：讓地圖上的箱子/容器可以提供隨機 loot。

工作內容：

- 新增 `scripts/loot/loot_container_3d.gd`。
- 容器綁定 LootTable。
- 玩家靠近並互動可取得 roll 出來的物品。
- 早期可直接加入背包，不必做完整 container UI。

完成條件：

- 容器可以 roll loot 並加入玩家 inventory。
- 已開啟的容器不會重複無限領取，除非設計為可刷新。
- 容器不依賴 InventoryEquipmentUI。

驗證：

- 新增 `tools/validate_loot_container.gd`。
- `validate_gameplay_architecture.gd` 通過。

## 任務十四：把 Refuge Outskirts 測試場景改成第一張可玩 raid map

狀態：完成

目標：把目前 test world 升級成可完成一次 raid 的小地圖。

工作內容：

- 保留目前玩家、HUD、TopMenu、Inventory、Codex、Pause。
- 加入 2-3 個 LootContainer3D。
- 加入 ExtractionZone。
- 加入清楚的 placeholder 區域標記。
- 更新場景命名或新增正式 map scene，避免破壞測試場景可用性。

完成條件：

- 地圖有 spawn、loot、撤離。
- 玩家能從地圖完成撤離。
- 場景 headless 啟動通過。

驗證：

- `validate_extraction_flow.gd` 通過。
- `validate_loot_container.gd` 通過。
- gameplay scene headless 啟動通過。

## 任務十五：補齊手槍基礎射擊規則

狀態：完成

目標：讓戰鬥從單純造成傷害進化到可調整的武器行為。

工作內容：

- 在 `WeaponController3D` 加入 fire cooldown。
- 加入簡單 ammo/reserve ammo 規則，或先接玩家 inventory 裡的 9mm ammo。
- 加入 hit/miss 回饋接口。
- 不做完整改槍系統。

完成條件：

- 手槍不能無限每幀開火。
- 有 ammo 時可射擊，ammo 不足時不能射擊。
- 武器仍可對 `Damageable3D` 造成傷害。

驗證：

- 更新 `tools/validate_combat_domain.gd`。

## 任務十六：建立玩家受傷與死亡事件

狀態：完成

目標：讓敵人可以真正威脅玩家，並讓死亡接上 raid result。

工作內容：

- 讓 player health 可以被 DamageEvent 扣除。
- 加入死亡 signal 或 callback。
- 玩家死亡通知 RaidSession。
- HUD 正確反映血量。

完成條件：

- 測試中玩家受到傷害會扣血。
- 血量歸零只觸發一次死亡。
- 死亡會進入 death result flow。

驗證：

- 新增或更新 `tools/validate_player_damage.gd`。
- `validate_combat_domain.gd` 通過。

## 任務十七：建立 EnemyDef 與 Scavenger 場景

狀態：完成

目標：建立第一個資料化敵人。

工作內容：

- 新增 `scripts/ai/enemy_def.gd`。
- 新增 `data/enemies/scavenger.tres`。
- 新增 `scenes/enemies/scavenger_3d.tscn`。
- 敵人有 health、move speed、damage、detect radius、loot table。
- 使用 placeholder mesh/material。

完成條件：

- Scavenger scene 可載入。
- EnemyDef 欄位完整且可驗證。
- 敵人有 Damageable3D 或等效受傷元件。

驗證：

- 新增 `tools/validate_enemy_def.gd`。
- gameplay scene headless 啟動通過。

## 任務十八：建立 Scavenger AI v1

狀態：完成

目標：讓第一個敵人具備最小可玩行為。

工作內容：

- 新增 `scripts/ai/enemy_controller_3d.gd`。
- 狀態：Idle、Alert、Chase、Attack、Dead。
- 可偵測玩家、靠近玩家、攻擊玩家。
- 暫時不做 cover、隊伍戰術、複雜尋路。

完成條件：

- 玩家進入範圍後敵人會追擊。
- 敵人進入攻擊距離後會造成傷害。
- 敵人死亡後停止行為。

驗證：

- 新增 `tools/validate_enemy_ai.gd`。
- `validate_player_damage.gd` 通過。

## 任務十九：加入敵人掉落

狀態：完成

目標：讓戰鬥與 loot loop 連接。

工作內容：

- 敵人死亡後根據 LootTable 掉落物品或直接給 player 可拾取物。
- 早期可生成既有 `LootPickup3D`。
- 掉落位置靠近敵人死亡位置。

完成條件：

- 擊殺 Scavenger 後會生成掉落。
- 掉落可被玩家拾取並帶出。
- 掉落不會在同一敵人身上重複生成。

驗證：

- 更新 `validate_enemy_ai.gd` 或新增 `validate_enemy_loot_drop.gd`。
- `validate_loot_tables.gd` 通過。

## 任務二十：加入 Raid HUD 目標資訊

狀態：完成

目標：讓玩家知道目前 raid 要做什麼。

工作內容：

- 顯示撤離提示、簡單目標、raid 狀態。
- 顯示 ammo 或目前武器基本資訊。
- 與 `UIManager` 相容，不阻擋現有背包/圖鑑操作。
- 若新增穩定 HUD 面板，優先用 scene/node 組成；腳本只更新文字、數值、可見狀態。

完成條件：

- 玩家進地圖能看到「尋找物資並撤離」類目標。
- 進入撤離區能看到倒數或狀態。
- 開背包/圖鑑不破壞 HUD。
- Raid HUD 通過 UI Layout Quality Check，不遮擋核心 gameplay 視野，且文字/按鈕/提示在 1280x720 可讀。

驗證：

- 新增或更新 `tools/validate_raid_hud.gd`。
- `validate_ui_foundation.gd` 通過。

## 任務二十一：建立簡單金錢與出售流程

狀態：完成

目標：讓 loot 有第一層經濟用途。

工作內容：

- 在 Base screen 增加 money 顯示。
- 實作出售 vendor trash 或 Sell Selected/ Sell All Junk。
- 使用 `ItemDef.value`。
- 更新 save。

完成條件：

- Stash 中有可出售物品時可以換成 money。
- 出售後物品數量減少或移除。
- money 存檔後可還原。

驗證：

- 新增 `tools/validate_vendor_sell.gd`。
- `validate_save_slots.gd` 通過。

## 任務二十二：建立第一個 Workbench Upgrade

狀態：完成

目標：讓玩家有第一個使用撤離物資的長期目標。

工作內容：

- 新增 workbench upgrade 資料。
- 成本建議：wood、wire、cash。
- Base screen 顯示 upgrade 狀態與按鈕。
- 升級後給一個簡單效果，例如下一場 starter ammo +1 或解鎖簡單 recipe。

完成條件：

- 材料足夠可升級。
- 材料不足不可升級且有清楚狀態。
- 升級結果存檔。

驗證：

- 新增 `tools/validate_base_progression.gd`。
- `validate_vendor_sell.gd` 通過。

## 任務二十三：建立 Quest 資料模型

狀態：完成

目標：讓任務系統能以資料驅動方式擴充。

工作內容：

- 新增 `scripts/quests/quest_def.gd`。
- 新增 `scripts/quests/quest_state.gd` 或 save-friendly schema。
- 支援 collect/extract objective。
- 新增第一個任務：帶出 wood 或 wire。

完成條件：

- QuestDef 可以載入。
- Quest 狀態可以保存進 save。
- 提交任務可以給 reward。

驗證：

- 新增 `tools/validate_quest_model.gd`。

## 任務二十四：把第一個收集任務接到 Base

狀態：完成

目標：讓玩家在基地看到並完成第一個任務。

工作內容：

- Base screen 顯示任務名稱、目標、狀態。
- 任務 UI 以現有 Base scene 的節點/容器擴充，避免整套任務介面都由腳本硬編碼生成。
- 撤離帶回所需物品後可完成任務。
- 完成後給 money 或 item reward。

完成條件：

- 任務未完成、可完成、已完成三種狀態清楚。
- 完成狀態存檔。
- 任務不需要硬寫單一 UI 邏輯才能擴充。
- Quest UI 通過 UI Layout Quality Check，任務標題、目標、進度、獎勵、提交動作的視覺階層清楚。

驗證：

- 更新 `validate_quest_model.gd` 或新增 `validate_quest_flow.gd`。
- `validate_save_slots.gd` 通過。

## 任務二十五：建立第一個擊殺任務

狀態：完成

目標：讓戰鬥也能推動任務進度。

工作內容：

- Quest objective 支援 kill enemy id。
- 擊殺 Scavenger 後更新任務進度。
- Base screen 可提交或自動完成。

完成條件：

- 擊殺指定敵人會更新 quest progress。
- 進度可存檔。
- 死亡或撤離後進度規則明確。

驗證：

- `validate_quest_flow.gd` 通過。
- `validate_enemy_ai.gd` 通過。

## 任務二十六：完成三場 Raid Smoke Test

狀態：完成

目標：確認早期核心循環可以連續遊玩。

工作內容：

- 建立可自動或半自動驗證三場 raid 的測試流程。
- 第 1 場成功撤離。
- 第 2 場死亡。
- 第 3 場成功撤離並完成至少一個進度變化。

完成條件：

- 三場結果都符合預期。
- Stash/money/quest/base upgrade 在每場後狀態正確。
- Save/load 後狀態一致。

驗證：

- 新增 `tools/validate_three_raid_loop.gd`。
- Standard Validation Set。

## 任務二十七：早期 UI 與文字整理

狀態：未開始

目標：讓 Dev Slice 0.1 的資訊足夠清楚，不要求最終美術。

工作內容：

- 整理 Base、Raid HUD、Result、Quest 的文字。
- 補 localization keys。
- 檢查 1280x720 與 1920x1080 主要 UI 不溢出。
- 修正本任務碰到的 mojibake fallback。

完成條件：

- 主要流程文字可讀。
- 關鍵 UI 不重疊。
- 中文無明顯亂碼在新功能中出現。
- 依 `docs/design/ui_layout_quality_guide.md` 檢查 Base、Raid HUD、Result、Quest 的底版、按鈕、間距、對齊、文字 fit。

驗證：

- 新增或更新相關 UI validation。
- `validate_ui_foundation.gd` 通過。

## 任務二十八：早期平衡調整

狀態：未開始

目標：讓三場 raid 的節奏合理，先追求可玩而不是準確數值。

工作內容：

- 調整 player health/stamina。
- 調整 enemy health/damage。
- 調整 loot 數量和價值。
- 調整 extraction timer。
- 調整 upgrade cost。

完成條件：

- 第一張地圖可在 3-8 分鐘完成一次 raid。
- 玩家能理解風險，但不會被第一個敵人秒殺。
- 至少有一次「要不要多撿一點」的決策點。

驗證：

- `validate_three_raid_loop.gd` 通過。
- 手動或 runtime smoke test 記錄在 `progress_log.md`。

## 任務二十九：建立內容擴充規格

狀態：未開始

目標：在開始堆內容前，定義新增內容的資料格式和流程。

工作內容：

- 新增 `docs/design/content_authoring_guide.md`。
- 說明如何新增 item、loot table entry、enemy、quest、upgrade。
- 說明每種內容要跑哪些 validation。
- 不新增大量內容，只寫規格和一個範例。

完成條件：

- AI 可以依照文件新增一個物品或敵人而不破壞系統。
- 文件列出命名規則、資料位置、驗證命令。

驗證：

- `validate_item_catalog.gd`。
- `validate_loot_tables.gd`。
- `validate_enemy_def.gd`。
- `validate_quest_model.gd`。

## 任務三十：Dev Slice 0.1 驗收與鎖定擴充門檻

狀態：未開始

目標：確認早期版本是不是符合想要的方向，再決定是否開始加重複內容。

工作內容：

- 跑完整 validation。
- 玩或模擬三場 raid。
- 檢查提取、死亡、stash、money、upgrade、quest 都正確。
- 更新 `early_development_plan.md` 的 approval checklist。
- 在 `progress_log.md` 記錄是否通過 Dev Slice 0.1。

完成條件：

- 玩家可從新遊戲一路完成至少三場 raid。
- 成功撤離與死亡都產生正確結果。
- Save/load 正確。
- 至少一個 upgrade 和一個 quest 生效。
- 使用者確認方向符合預期。

驗證：

- Standard Validation Set。
- `validate_three_raid_loop.gd`。
- 需要一輪實機或 runtime UI 檢查。

## 完成 Dev Slice 0.1 後才允許排入的內容

這些項目暫時不要提前做：

- 第二張正式地圖。
- 大量武器清單。
- 武器配件/改槍 UI。
- 多 NPC 商人。
- 複雜基地建設樹。
- 天氣系統。
- 高階 AI 戰術。
- 最終角色與場景美術。
- Steam Workshop/mod 支援。
