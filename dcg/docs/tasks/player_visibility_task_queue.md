# Project DCG Player Visibility Task Queue

Last updated: 2026-07-02

## Purpose

This queue replaces the previous automation focus after the user's hands-on check.

The first 30 tasks built many underlying systems, but the current player-visible experience only clearly proves:

- Difficulty selection / new game entry.
- Extraction zone countdown and result transition.
- Loot containers can produce items.

The next automation phase must not add new content volume. It must make the existing systems visible, understandable, reachable, and playable through the normal player flow.

## Current Progress Analysis

### What Is Player-Visible Now

- The game starts at the main menu.
- The player can choose difficulty.
- The player can enter a raid-like test scene.
- Loot containers can be searched.
- The extraction zone countdown works.
- Extraction opens a result panel.

### What Exists But Is Not Clearly Player-Visible

- The Base screen exists as `res://scenes/base/base_screen.tscn`, but the player does not clearly recognize it as the base phase.
- The Base UI has stash, money, workbench, quest, sell, and start-raid elements, but most visible text is still English or corrupted localization.
- The raid scene has HUD, result panel, loot containers, extraction zone, and a combat target, but it does not clearly communicate the loop objective.
- The player has starter inventory and weapon controller logic, but the pistol and shooting feedback are not obvious to the player.
- Scavenger data and scene exist, but the current raid scene does not clearly place an obvious enemy in the player's route.
- Quest, upgrade, sell, death-loss, enemy drop, and save/load rules exist at system level, but they are not proven by normal visible play.

### Main Diagnosis

The project is not blocked by missing raw systems first. It is blocked by missing player-facing integration.

Future automation must treat a task as incomplete if the feature only passes a validation script but cannot be seen, understood, or reached by a player using the normal game flow.

## Automation Rules For This Queue

1. Do not add new maps, new item batches, new weapons, new enemy types, new quest chains, or final art.
2. Use existing content only: current Base screen, Refuge Outskirts test raid, Scavenger, pistol, loot containers, stash, workbench upgrade, and existing quests.
3. Earlier tasks have higher priority. Start from the first task whose status is not `完成`.
4. A task is complete only when:
   - The player can see the feature in the normal flow.
   - The player can understand it through Traditional Chinese UI text.
   - The player can interact with it when applicable.
   - The validation script or runtime check confirms it.
5. Any UI task must follow `docs/design/ui_layout_quality_guide.md`.
6. Stable UI should remain Godot node-first with `.tscn`, `Control`, containers, labels, buttons, and theme/style helpers.
7. Script-created UI is allowed only for dynamic rows, temporary indicators, or debug-only visuals.
8. After every three completed tasks, run Project Health Check.
9. Update `docs/tasks/progress_log.md` after each completed task.
10. If a feature is system-complete but not player-visible, it is not complete for this queue.

## Project Health Check Trigger Points

- After 可視化任務三, before 可視化任務四.
- After 可視化任務六, before 可視化任務七.
- After 可視化任務九, before 可視化任務十.
- After 可視化任務十二, before 可視化任務十三.
- After 可視化任務十五, before any renewed Dev Slice approval.

Health check must inspect:

- Player flow reachability.
- Traditional Chinese text quality.
- UI layout spacing and hierarchy.
- Godot node-first UI ownership.
- Scene loadability.
- Gameplay responsibility boundaries.
- Save safety.
- Validation coverage.
- Whether automation accidentally added content volume instead of making existing systems visible.

## Standard Validation Set

Run these after tasks touching shared UI, scene flow, save, combat, or raid state:

```powershell
& 'C:\Users\User\Desktop\Godot_v4.7-stable_win64.exe' --headless --path .\dcg --script res://tools/validate_item_catalog.gd
& 'C:\Users\User\Desktop\Godot_v4.7-stable_win64.exe' --headless --path .\dcg --script res://tools/validate_ui_foundation.gd
& 'C:\Users\User\Desktop\Godot_v4.7-stable_win64.exe' --headless --path .\dcg --script res://tools/validate_gameplay_architecture.gd
& 'C:\Users\User\Desktop\Godot_v4.7-stable_win64.exe' --headless --path .\dcg --script res://tools/validate_save_slots.gd
& 'C:\Users\User\Desktop\Godot_v4.7-stable_win64.exe' --headless --path .\dcg --script res://tools/validate_base_flow.gd
& 'C:\Users\User\Desktop\Godot_v4.7-stable_win64.exe' --headless --path .\dcg --script res://tools/validate_three_raid_loop.gd
& 'C:\Users\User\Desktop\Godot_v4.7-stable_win64.exe' --headless --path .\dcg --quit-after 1
& 'C:\Users\User\Desktop\Godot_v4.7-stable_win64.exe' --headless --path .\dcg --quit-after 1 res://scenes/gameplay/player_test_world_3d.tscn
```

## 可視化任務一：重新標記 Dev Slice 狀態

狀態：完成

目標：把目前狀態從「自動驗收通過」改成「系統驗證通過，但玩家可見驗收未通過」。

工作內容：

- 更新 `docs/tasks/dev_slice_0_1_acceptance.md`。
- 記錄玩家實測只明確看到 difficulty、extraction zone、loot container。
- 建立玩家可見驗收 checklist。
- 明確禁止進入內容擴充。

完成條件：

- 文件清楚區分 system validation 與 player-visible acceptance。
- 後續 AI 不會誤判 Dev Slice 0.1 已可開始擴充內容。

驗證：

- 新增或更新 `validate_dev_slice_acceptance.gd`，檢查 player-visible pending gate。

## 可視化任務二：修復繁中 UI 文字基礎

狀態：完成

目標：讓玩家看得懂目前所有早期流程。

工作內容：

- 修復 `data/localization/game_text.csv` 中 Base、Raid HUD、Raid Result、Difficulty、Loot、Enemy、Quest、Workbench 的 `zh_TW` 文字。
- 修復明顯亂碼或仍顯示英文的玩家可見字串。
- 不新增內容，只翻譯現有 key。

完成條件：

- 選難度、基地、Raid HUD、撤離、結算、任務、工作台、箱子/拾取、敵人名稱都能顯示繁中。
- UI 不因中文變長而爆版。

驗證：

- `validate_ui_text_quality.gd`。
- 新增或更新可檢查繁中 key 的 validation。

## 可視化任務三：讓 Base 成為明確可辨識的基地畫面

狀態：完成

目標：玩家選完難度後，能明確知道自己來到基地，而不是誤以為卡在結算或普通 UI。

工作內容：

- 確認主選單 -> 難度 -> Base 的正常流程。
- Base 標題改為明確中文，例如「基地」。
- Base 增加清楚分區：倉庫、金錢、任務、工作台、開始出擊。
- Base 狀態文字要說明下一步，例如「整理物資後開始下一場 Raid」。

完成條件：

- 新玩家選難度後第一眼知道這是基地。
- 有明顯「開始出擊」按鈕。
- 不新增 3D 基地場景，先使用現有 Base UI。

驗證：

- `validate_base_screen.gd`。
- `validate_base_flow.gd`。
- 1280x720 / 1920x1080 layout check。

## 可視化任務四：結算畫面接回基地並可見化物資轉移

狀態：完成

目標：玩家撤離後能看懂本局結果，並知道物資已進倉庫。

工作內容：

- Raid Result 全中文化。
- 明確顯示「撤離成功 / 死亡」。
- 明確顯示「帶回物品」「遺失物品」「金錢變化」。
- 按鈕文字改為「回到基地」。
- 回基地後 stash 立刻顯示剛撤離的物品。

完成條件：

- 玩家能肉眼確認撤離物資進入基地倉庫。
- 死亡時能肉眼確認物品遺失。

驗證：

- `validate_raid_result_panel.gd`。
- `validate_extraction_flow.gd`。
- `validate_three_raid_loop.gd`。

## 可視化任務五：Raid HUD 顯示玩家當下目標

狀態：完成

目標：進入 Raid 後，玩家知道現在要做什麼。

工作內容：

- HUD 中文化。
- 顯示當前目標：「搜索物資」「小心敵人」「前往撤離點」。
- 顯示撤離區提示與倒數。
- 顯示血量、體力、武器/彈藥狀態。

完成條件：

- 玩家不看文件也知道 Raid 目標。
- HUD 不遮住主要玩法區。

驗證：

- `validate_raid_hud.gd`。
- `validate_ui_text_quality.gd`。

## 可視化任務六：讓手槍與射擊回饋可見

狀態：未開始

目標：玩家能確認自己有武器，且左鍵射擊真的有反應。

工作內容：

- 確認玩家出生時持有現有 pistol/starter loadout。
- HUD 顯示目前武器與彈藥。
- 增加最小可見射擊回饋：槍口閃光、射線、命中閃爍或命中文字。
- 不新增新武器，只讓現有手槍可見。

完成條件：

- 玩家按左鍵時能看到射擊反應。
- 命中目標或敵人時有明顯回饋。

驗證：

- `validate_combat_domain.gd`。
- 新增或更新射擊可視化 validation。

## 可視化任務七：把 Scavenger 放進玩家可遇到的 Raid 路線

狀態：未開始

目標：玩家正常遊玩時看得到敵人。

工作內容：

- 使用現有 `scavenger_3d.tscn`。
- 把 Scavenger 放在現有地圖的合理位置。
- 用明顯 placeholder 外觀或頭上名稱標示「拾荒者」。
- 不新增敵人種類。

完成條件：

- 玩家從出生點前往箱子或撤離點時能遇到敵人。
- 敵人不是只存在驗證腳本或資料檔。

驗證：

- `validate_enemy_def.gd`。
- `validate_enemy_ai.gd`。
- 新增或更新場景中敵人存在檢查。

## 可視化任務八：讓敵人戰鬥與玩家受傷死亡可見

狀態：未開始

目標：玩家能理解敵人會攻擊，自己會受傷與死亡。

工作內容：

- 敵人接近/攻擊要有可見回饋。
- 玩家受傷時 HUD 血量下降。
- 玩家死亡時進入死亡結算。
- 死亡結算顯示遺失物品。

完成條件：

- 玩家能從畫面理解「被攻擊 -> 扣血 -> 死亡 -> 結算」。

驗證：

- `validate_player_damage.gd`。
- `validate_extraction_flow.gd` death case。
- `validate_three_raid_loop.gd` death case。

## 可視化任務九：敵人死亡與掉落可見化

狀態：未開始

目標：玩家擊殺 Scavenger 後，看得到掉落物並能拾取。

工作內容：

- 敵人死亡時有明顯消失、倒下、或死亡標記。
- 掉落物使用現有掉落系統。
- 掉落物有中文互動提示。
- 拾取後能進入背包/撤離結算/倉庫流程。

完成條件：

- 玩家可完成「擊殺敵人 -> 拾取掉落 -> 撤離 -> 倉庫可見」。

驗證：

- `validate_enemy_loot_drop.gd`。
- `validate_loot_container.gd` or pickup validation。
- `validate_three_raid_loop.gd` raid three path。

## 可視化任務十：讓任務在 Base 中可理解與可完成

狀態：未開始

目標：玩家看得到任務，知道目標，且完成後能領獎。

工作內容：

- Base 任務區中文化。
- 顯示收集任務與擊殺任務進度。
- 顯示「可回報 / 已完成 / 進行中」。
- 回報任務後顯示獎勵與存檔結果。

完成條件：

- 玩家至少能理解並完成一個收集任務和一個擊殺任務。

驗證：

- `validate_quest_model.gd`。
- `validate_quest_flow.gd`。
- `validate_base_screen.gd`。

## 可視化任務十一：讓工作台升級在 Base 中可理解

狀態：未開始

目標：玩家知道工作台需要什麼、自己缺什麼、升級後得到什麼。

工作內容：

- Base 工作台區中文化。
- 顯示需求材料、目前擁有數量、金錢需求。
- 升級按鈕狀態要清楚。
- 升級成功後顯示效果，例如「下次出擊備用彈藥 +1」。

完成條件：

- 玩家能看懂為什麼能升級或不能升級。
- 升級成功後狀態可見。

驗證：

- `validate_base_progression.gd`。
- `validate_base_screen.gd`。
- `validate_three_raid_loop.gd` raid one upgrade path。

## 可視化任務十二：讓出售雜物與金錢變化可見

狀態：未開始

目標：玩家能確認 stash 裡的雜物可以賣，且錢有增加。

工作內容：

- Base 出售按鈕中文化。
- Stash 中可出售物品要有清楚名稱。
- 出售後顯示金錢變化與剩餘物品。

完成條件：

- 玩家能完成「撤離帶回雜物 -> 回基地出售 -> 金錢增加」。

驗證：

- `validate_vendor_sell.gd`。
- `validate_base_screen.gd`。

## 可視化任務十三：整理第一張 Raid 地圖的可讀性

狀態：未開始

目標：不加新內容，只讓現有地圖更像一張可玩的早期 raid map。

工作內容：

- 用現有 placeholder 標示出生點、箱子區、敵人區、撤離點。
- 修正英文 Label3D，例如 Extraction Zone。
- 加入方向提示或顏色提示。
- 保持簡單，不做正式美術。

完成條件：

- 玩家進入地圖後能看懂大概路線。
- 箱子、敵人、撤離點都不會像隨機測試物。

驗證：

- 新增或更新 scene visibility validation。
- gameplay scene startup check。

## 可視化任務十四：建立玩家可見 Smoke Test

狀態：未開始

目標：讓 AI 不能只靠資料驗證通過，還必須驗證玩家流程可見。

工作內容：

- 新增 `tools/validate_player_visible_slice.gd`。
- 檢查主流程節點與可見文字：
  - Base 可見。
  - Start Raid 可見。
  - Raid HUD 可見。
  - Loot container 可見。
  - Scavenger 可見。
  - Extraction prompt 可見。
  - Result panel 可見。
  - 回基地按鈕可見。
- 檢查繁中模式下沒有主要英文 fallback。

完成條件：

- 驗證能抓出「系統存在但玩家看不到」的問題。

驗證：

- `validate_player_visible_slice.gd`。
- Standard Validation Set。

## 可視化任務十五：重新做 Dev Slice 0.1 玩家驗收

狀態：未開始

目標：確認目前不是只有系統可運行，而是玩家真的看得見完整早期循環。

工作內容：

- 從新遊戲開始跑完整流程：
  - 選難度。
  - 進基地。
  - 開始 Raid。
  - 搜箱。
  - 看見手槍與射擊回饋。
  - 看見並擊殺/被 Scavenger 攻擊。
  - 撤離或死亡。
  - 看懂結算。
  - 回基地看見 stash、money、quest、upgrade 變化。
- 更新 `dev_slice_0_1_acceptance.md`。
- 只有玩家可見驗收通過後，才允許再次討論內容擴充。

完成條件：

- 玩家可見驗收 checklist 全部通過。
- 使用者可以明確判斷這是否是想要的早期方向。

驗證：

- `validate_player_visible_slice.gd`。
- `validate_three_raid_loop.gd`。
- `validate_dev_slice_acceptance.gd`。
- 一輪實機或 editor runtime 檢查。
