# Project DCG Dev Slice 0.2 Enemy-First Task Queue

Last updated: 2026-07-03

## Purpose

This task queue replaces the broad Dev Slice 0.2 planning order with an enemy-first order.

The immediate player-facing problem is that after entering the raid, the player does not clearly encounter a 3D enemy that tracks and attacks. Therefore, enemy presence, chase behavior, attack behavior, and combat feedback are the highest-priority items.

This queue still follows the earlier rule: increase feature categories, not content quantity. Do not add a second raid map, do not add many enemy types, and do not add large weapon/item volume. Add one complete representative enemy experience first.

## Automation Rules

1. Start from the first task whose status is not `完成`.
2. Do not skip enemy tasks to work on later UI or base tasks.
3. Every task must be player-visible, not only script-visible.
4. Every task must include or update a focused `tools/validate_*.gd` check where practical.
5. After every three feature tasks, run the Project Health Check task before continuing.
6. UI must be Traditional Chinese and Godot node-first where stable.
7. Preserve current V2 flow: 3D Base -> Raid -> container grid -> backpack/equipment/reload/projectile -> extraction/result -> 3D Base.
8. Do not hardwire weapons, ammo, loot, or quest state directly into unrelated systems.
9. If a task exposes wrong coupling, decouple before adding more bridge logic.
10. When a completed slice is verified, update `docs/tasks/progress_log.md`.
11. Non-linear work is allowed when tasks do not conflict. If dependencies are complete and the tasks touch different files, domains, and responsibility boundaries, AI may work on them in parallel to improve efficiency.

## Non-Linear Parallel Work Policy

AI may run a non-linear workflow only when all of these conditions are true:

1. The enemy-first gates are not bypassed. Tasks one to three must be completed before later gameplay categories can be marked complete.
2. The tasks do not edit the same scene, script, resource, validation file, or UI panel.
3. The tasks belong to different ownership domains, such as Enemy, Base, UI, Quest, Loot, Equipment, Save, or Documentation.
4. The earlier task is not a direct dependency of the later task.
5. Each parallel task has its own validation path.
6. If a merge conflict, behavior conflict, or responsibility conflict appears, stop parallel work and return to the lowest-numbered blocked task.
7. Project Health Check tasks remain serial gates and cannot be skipped or parallelized.

Safe examples:

- Enemy scene placement can run in parallel with Dev Slice 0.2 documentation cleanup if they do not touch the same files.
- Raid briefing UI can run in parallel with base station readability after enemy chase/attack gates are working.
- Map panel UI can run in parallel with locked container planning if neither task changes shared inventory APIs.
- Armor effect validation can run in parallel with UI text audit only if no shared equipment UI file is edited by both tasks.

Unsafe examples:

- Enemy chase and enemy attack should not run in parallel if both edit the same enemy controller.
- Container transfer and locked container behavior should not run in parallel if both edit container inventory APIs.
- Weapon projectile hit and enemy damageable should not run in parallel if both alter the same damage event contract.
- Any task that changes UIManager focus, TAB, ESC, or mouse mode should be serial until runtime HUD validation passes.

## Dev Slice 0.2 Player-Visible Target

The player should be able to:

1. Enter Raid from 3D Base.
2. Immediately understand there is danger in the map.
3. See at least one 3D monster/enemy in the raid.
4. Have that enemy detect, chase, and attack the player.
5. Fight back with the equipped pistol after finding, equipping, and reloading it.
6. See clear pistol firing VFX: muzzle spark, short firing ray/tracer, visible 3D projectile trajectory, and impact VFX when the bullet hits an enemy or object.
7. See clear hit, damage, death, and loot feedback.
8. Continue the extraction loop without losing TAB backpack, ESC pause, crosshair, or result return flow.

## Task List

### 任務一：Raid 場景放入可見 3D 敵人

狀態：完成

優先度：最高

工作內容：
- 在目前第一張 Raid 場景中放入至少一個 3D 敵人。
- 敵人必須是玩家正常出擊後可以看見或遇到的，不是測試場景孤立物件。
- 使用簡單 3D 怪物外型即可，可用 placeholder mesh，但必須清楚不是箱子或道具。

完成條件：
- 玩家從出擊點進入 Raid 後，能在地圖上遇到 3D 敵人。
- 敵人有清楚名稱或狀態提示，例如 `敵人`、`警戒中`、`追蹤中`。
- 不新增第二張 Raid 地圖。

驗證：
- 新增或更新 `tools/validate_enemy_visible_in_raid.gd`。
- Gameplay scene headless startup。

### 任務二：3D 敵人基礎狀態與生命

狀態：完成

優先度：最高

工作內容：
- 敵人需要有生命、受傷、死亡狀態。
- 敵人 3D 物件需要有可辨識血條或狀態提示。
- 敵人死亡後不可繼續追蹤或攻擊。

完成條件：
- 玩家能看出敵人活著、受傷、死亡。
- 敵人死亡狀態不會阻塞撤離流程。

驗證：
- `validate_enemy_damageable_3d.gd`
- `validate_combat_domain.gd`

### 任務三：敵人偵測玩家並追蹤

狀態：完成

優先度：最高

工作內容：
- 敵人進入偵測範圍後會轉向玩家。
- 敵人會向玩家移動追蹤。
- 敵人追蹤狀態需要玩家看得出來。

完成條件：
- 玩家靠近敵人後，敵人會主動追玩家。
- 敵人不會站在原地完全無反應。
- 敵人追蹤邏輯不能寫在 UI 內。

驗證：
- `validate_enemy_chase_player.gd`
- Gameplay scene headless startup。

### 任務四：Project Health Check A

狀態：完成

優先度：最高

檢查內容：
- Enemy、Damageable、Combat、Raid、UIManager 責任邊界。
- 敵人是否真正放在玩家可抵達的 Raid 流程中。
- 是否有把敵人邏輯硬塞進 Player 或 UI。
- Scene loadability。
- Validation health。

完成條件：
- 任務一至三通過。
- 若發現小型耦合問題，先修掉再繼續任務五。

驗證：
- `validate_player_visibility_v2_health.gd`
- 新增 `validate_enemy_architecture_health.gd` 或補強既有 health validator。

### 任務五：敵人近距離攻擊玩家

狀態：完成

優先度：最高

工作內容：
- 敵人追到一定距離後會攻擊玩家。
- 攻擊會造成玩家生命下降。
- 攻擊需要有冷卻時間，避免每幀連續扣血。

完成條件：
- 玩家被敵人追上後會受到傷害。
- HUD 生命值會下降。
- 攻擊不是純文字假效果。

驗證：
- `validate_enemy_attack_player.gd`
- `validate_player_damage_flow.gd`

### 任務六：敵人攻擊前提示與受擊回饋

狀態：完成

優先度：高

工作內容：
- 敵人攻擊前有簡單提示，例如短暫停頓、顏色變化、警戒文字或攻擊條。
- 玩家受傷時有可見回饋。
- 不做最終動畫，只做清楚可讀的 placeholder feedback。

完成條件：
- 玩家能理解自己為什麼受傷。
- 敵人攻擊不是毫無提示地扣血。

驗證：
- `validate_combat_feedback_visibility.gd`

### 任務七：玩家可以反擊並殺死敵人

狀態：完成

優先度：高

工作內容：
- 確認玩家用 No.5 手槍射出的 3D projectile 可以打到敵人。
- 敵人受到足夠傷害後死亡。
- 死亡後有掉落或至少有清楚死亡狀態。
- 補上手槍射擊特效鏈：開火時有槍口火花、短暫火花射線或曳光提示，3D 子彈沿彈道移動，碰到敵人或物體時產生命中特效。

完成條件：
- 玩家能透過找槍、裝備、裝填、射擊，殺死敵人。
- 敵人死亡後停止追蹤與攻擊。
- 玩家能看見射擊瞬間、子彈飛行軌跡、命中敵人或命中物體後的效果。
- 特效可以使用 placeholder mesh/particle/light，但必須是 3D 空間內可見，不只是在 UI 顯示文字。

驗證：
- `validate_projectile_hit_enemy.gd`
- `validate_pistol_fire_vfx.gd`
- `validate_weapon_equipment_binding.gd`
- `validate_reload_flow.gd`

### 任務八：Project Health Check B

狀態：完成

優先度：高

檢查內容：
- WeaponController 是否仍只處理武器、裝填、projectile。
- EnemyDamageable 是否沒有依賴 UI。
- PlayerController 是否沒有硬塞敵人生成。
- Projectile hit 是否沒有回退成 hitscan 假子彈。

完成條件：
- 任務五至七通過。
- 發現錯誤耦合先修復。

驗證：
- `validate_player_visibility_v2_health.gd`
- `validate_projectile_3d.gd`
- `validate_pistol_fire_vfx.gd`

### 任務九：敵人掉落或戰鬥獎勵

狀態：完成

優先度：高

工作內容：
- 敵人死亡後產生一個可拾取戰利品，或將掉落放入小型掉落容器。
- 掉落內容只做一種代表樣本，不擴大量。
- 掉落必須走現有拾取/背包流程。

完成條件：
- 玩家殺死敵人後能得到可見獎勵。
- 掉落不直接寫入倉庫或結算。

驗證：
- `validate_enemy_loot_drop.gd`
- `validate_inventory_drag_rules.gd`

### 任務十：敵人擊殺任務可見化

狀態：完成

優先度：高

工作內容：
- 讓現有擊殺任務能和實際 Raid 內的 3D 敵人連動。
- 任務進度放在 Top Menu 任務頁，不放回大型左上 HUD。
- 擊殺後任務進度更新。

完成條件：
- 玩家殺死敵人後，在任務頁能看到進度變化。
- 任務與敵人不要互相硬引用場景路徑。

驗證：
- `validate_quest_kill_enemy_flow.gd`
- `validate_top_menu_panels.gd`

### 任務十一：敵人造成死亡與結果畫面

狀態：完成

優先度：高

工作內容：
- 玩家被敵人打死後進入死亡結果流程。
- 結果畫面顯示失去物品或死亡狀態。
- 玩家能從結果回到 3D Base。

完成條件：
- 死亡和撤離有清楚不同結果。
- 死亡流程不閃退、不卡死。

驗證：
- `validate_enemy_player_death_result.gd`
- `validate_raid_loss_rules.gd`
- `validate_raid_return_to_base_3d.gd`

### 任務十二：Project Health Check C

狀態：完成

優先度：高

檢查內容：
- Enemy -> Quest -> Result 的事件流是否乾淨。
- Death/loss 是否仍由 Raid/Result 系統負責。
- 敵人掉落是否仍走 Loot/Inventory。
- UI 是否只顯示，不持有任務或敵人狀態。

完成條件：
- 任務九至十一通過。
- 發現高風險耦合時先重構。

驗證：
- `validate_enemy_architecture_health.gd`
- `validate_player_visibility_v2_health.gd`

### 任務十三：出擊前簡報 UI

狀態：完成

優先度：中高

工作內容：
- 玩家從 3D Base 出擊門進入 Raid 前，先看到本場簡報。
- 簡報顯示地圖、目標、危險、撤離提醒。
- 特別提醒本場有敵人威脅。

完成條件：
- 玩家在進 Raid 前知道會遇敵。
- 簡報 UI 全繁中。

驗證：
- `validate_raid_briefing_ui.gd`
- UI fit 1280x720 / 1920x1080。

### 任務十四：Raid 地圖資訊頁補強

狀態：完成

優先度：中高

工作內容：
- Top Menu 地圖頁顯示撤離方向、危險區、箱子區。
- 不做第二張地圖，不做精準小地圖。
- 只做資訊足夠的 2D 面板。

完成條件：
- 玩家知道敵人大概在哪些區域、撤離往哪裡。

驗證：
- `validate_top_menu_map_panel.gd`
- `validate_ui_text_quality.gd`

### 任務十五：Raid 目標提示整理

狀態：完成

優先度：中高

工作內容：
- 保留小型 HUD，不恢復大型左上角任務面板。
- HUD 僅提示最重要狀態：生命、彈藥、裝填、簡短目標。
- 詳細任務留在 Top Menu。

完成條件：
- 畫面不被大面板遮住。
- 玩家仍知道要搜刮、避敵、撤離。

驗證：
- `validate_raid_hud_minimal_goal.gd`
- `validate_reload_ui.gd`

### 任務十六：Project Health Check D

狀態：完成

優先度：中高

檢查內容：
- UIManager 是否仍管理 TAB、ESC、滑鼠模式、焦點。
- Raid HUD 是否保持簡潔。
- 出擊簡報與地圖頁是否沒有控制 gameplay state。
- 繁中與 UI layout quality。

完成條件：
- 任務十三至十五通過。

驗證：
- `validate_base_3d_runtime_hud.gd`
- `validate_ui_text_quality.gd`
- `validate_player_visibility_v2_health.gd`

### 任務十七：基地功能站可讀性整理

狀態：完成

優先度：中

工作內容：
- 倉庫、工作台、任務板、出擊門、服務站都要有清楚提示。
- 每個功能站只做自己責任內的事。
- 玩家不用猜哪個物件能互動。

完成條件：
- 3D Base 中所有核心功能站清楚可見。

驗證：
- `validate_base_station_readability.gd`
- `validate_base_interactions.gd`

### 任務十八：新增一種基地服務站

狀態：未開始

優先度：中

工作內容：
- 優先做醫療站。
- 玩家可支付金錢或使用資源回復生命。
- 不做多種傷勢或複雜治療。

完成條件：
- 玩家在基地能理解並使用醫療站。

驗證：
- `validate_base_medical_station.gd`
- Save/load validation。

### 任務十九：護甲效果可視化

狀態：未開始

優先度：中

工作內容：
- 讓一件輕型護甲可以裝備到護甲格。
- 裝備後降低敵人攻擊造成的傷害，或顯示防護效果。
- UI 顯示護甲效果。

完成條件：
- 玩家能看懂護甲不是裝飾。

驗證：
- `validate_equipment_armor_effect.gd`
- `validate_enemy_attack_player.gd`

### 任務二十：Project Health Check E

狀態：未開始

優先度：中

檢查內容：
- Base service 是否沒有直接改 Raid 狀態。
- Armor effect 是否由 Equipment/Stats 處理。
- UI 是否沒有持有權威生命資料。
- Save/load 是否安全。

完成條件：
- 任務十七至十九通過。

驗證：
- `validate_player_visibility_v2_health.gd`
- `validate_save_slots.gd`

### 任務二十一：特殊物資來源一種

狀態：未開始

優先度：中

工作內容：
- 新增一個上鎖箱或任務箱。
- 需要鑰匙或條件才能開。
- 打開後仍使用容器格 UI。

完成條件：
- 玩家在 Raid 中看到不同於普通箱子的物資來源。

驗證：
- `validate_locked_container_flow.gd`
- `validate_container_inventory_ui.gd`

### 任務二十二：地點互動任務一種

狀態：未開始

優先度：中

工作內容：
- 任務要求玩家到指定地點互動。
- 互動後更新任務進度。
- 完成狀態在 Top Menu 任務頁顯示。

完成條件：
- 任務不只剩搜集和擊殺。

驗證：
- `validate_location_quest_flow.gd`
- `validate_top_menu_panels.gd`

### 任務二十三：撤離與死亡結果差異補強

狀態：未開始

優先度：中

工作內容：
- 成功撤離畫面顯示帶回物品。
- 死亡結果顯示失去物品。
- 結果畫面回到 3D Base。

完成條件：
- 玩家知道死亡和撤離差在哪。

驗證：
- `validate_raid_result_panel.gd`
- `validate_raid_loss_rules.gd`

### 任務二十四：Project Health Check F

狀態：未開始

優先度：中

檢查內容：
- Locked container 是否走 LootContainer/ContainerInventory。
- Location quest 是否不直接操作 UI。
- Result/loss 是否仍由 RaidResult/RaidLossRules 管理。

完成條件：
- 任務二十一至二十三通過。

驗證：
- `validate_player_visibility_v2_health.gd`

### 任務二十五：短基地升級線

狀態：未開始

優先度：中低

工作內容：
- 做一條很短的工作台或基地升級線。
- 升級消耗木頭、電線、金錢。
- 升級後下一場有一個可見差異。

完成條件：
- 玩家能感覺戰利品有長期用途。

驗證：
- `validate_base_progression.gd`
- `validate_three_raid_loop.gd`

### 任務二十六：Dev Slice 0.2 繁中與 UI 版面檢查

狀態：未開始

優先度：中低

工作內容：
- 檢查新增 UI 是否全繁中。
- 檢查按鈕、間距、底版、視覺階層。
- 檢查 1280x720 / 1920x1080。

完成條件：
- UI 不只可運行，也要可讀、好看、不卡畫面。

驗證：
- `validate_ui_text_quality.gd`
- `validate_ui_layout_quality_0_2.gd`

### 任務二十七：Dev Slice 0.2 玩家可見 Smoke Test

狀態：未開始

優先度：中低

工作內容：
- 建立完整自動驗證：3D Base -> 簡報 -> Raid -> 遇敵 -> 被追蹤/攻擊 -> 反擊 -> 搜刮 -> 任務 -> 撤離/死亡 -> 回 Base。
- 特別驗證敵人不是只存在於測試場景。

完成條件：
- 玩家可見 0.2 流程完整通過。

驗證：
- `validate_player_visible_0_2_slice.gd`
- Standard Validation Set。

### 任務二十八：Project Health Check G

狀態：未開始

優先度：中低

檢查內容：
- 全系統責任邊界。
- UI node-first 狀態。
- Save/load safety。
- Enemy/Quest/Result 事件流。
- Validation coverage。

完成條件：
- 任務二十五至二十七通過。

驗證：
- `validate_player_visibility_v2_health.gd`
- `validate_enemy_architecture_health.gd`

### 任務二十九：三場連續遊玩驗證

狀態：未開始

優先度：中低

工作內容：
- 模擬或手動檢查三場循環。
- 第一場成功撤離。
- 第二場被敵人擊殺。
- 第三場帶著基地升級效果再次出擊。

完成條件：
- 三場後倉庫、金錢、任務、基地狀態不壞。

驗證：
- `validate_three_raid_loop_0_2.gd`
- Main scene and Raid scene launch。

### 任務三十：Dev Slice 0.2 完成報告與備份

狀態：未開始

優先度：中低

工作內容：
- 更新 `docs/tasks/progress_log.md`。
- 更新 Dev Slice 0.2 完成報告。
- 若工作區乾淨且驗證通過，提交並推送到目前備份分支。

完成條件：
- 30 項任務狀態清楚。
- 驗證結果清楚。
- GitHub 備份完成或清楚記錄未備份原因。

驗證：
- `git status -sb`
- Remote branch hash verification after push。

## Priority Summary

最高優先必須先完成：

1. Raid 內看得到 3D 敵人。
2. 敵人會追蹤玩家。
3. 敵人會攻擊玩家並造成傷害。
4. 玩家能反擊並殺死敵人。
5. 手槍開火、子彈彈道、命中敵人或物體都有可見 3D 特效。
6. 敵人死亡、掉落、任務、死亡結果都能進入現有遊戲循環。

完成上述前，不應該優先做大量 UI、美術、第二地圖或內容擴量。
