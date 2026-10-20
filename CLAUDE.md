# ai-os 外掛維修規則

這裡是 ai-os 外掛本體（`plugin/`）。外掛從此資料夾原地載入：改動在**所有 ai-os 專案的下一個新對話**生效。設計理由見 `設計說明.md`。

## 檔案位置

- 共用規則：`plugin/rules.md`（由 `scripts/load-rules.ps1` 在開對話時送入）
- 技能：`plugin/skills/`；子 Agent：`plugin/agents/`
- hook 與腳本：`plugin/hooks/hooks.json`、`plugin/scripts/`
- 新專案骨架：`plugin/templates/project/`；格式範本：`plugin/templates/forms/`

## 改之前

- 讀 `設計說明.md` 的相關段落。要推翻其中刻意的取捨時，先派一個獨立 agent 對照設計說明與官方文件評估。
- 只有這三種情況問使用者：改變他的使用體驗（停下來問的頻率、回報方式、紅線範圍、第一版做多少）；不可逆或花錢；你與評估 agent 意見不一致（各給一句理由讓他選）。其餘照評估結論做，回報時一句話交代。

## 容易改壞的地方

- `rules.md` 去掉註解後要少於 10,000 字（hook 上限，超過會被截斷）。
- `.ps1` 一律存 UTF-8 with BOM；讀 stdin 要設 UTF-8 並去掉 BOM。
- 三支 hook 腳本的判斷條件要一致：有 `_管理/常駐/此次任務.md`、且沒有 `_開發檔案/scripts/hooks/verify-gate.ps1`。
- 路徑寫法：不寫任何只存在某台電腦的路徑（換電腦、換帳號要能用）。技能、子 Agent、腳本內用 `${CLAUDE_PLUGIN_ROOT}`；`templates/project/` 會被複製進專案，裡面不寫外掛路徑，用技能名稱（如 `ai-os:brainstorming`）指過去。改完跑一次掃描確認沒有本機路徑殘留。
- 子 Agent 設了 `omitClaudeMd`，看不到共用規則，紅線要寫在自己的檔內。
- 改名稱或路徑後，全資料夾搜尋舊字串，0 殘留。
- 不改桌面舊範本，也不改各專案的檔案來修外掛的問題。

## 改完要做

1. `claude plugin validate ./plugin`
2. 動到 `scripts/` → 跑 `powershell -NoProfile -ExecutionPolicy Bypass -File plugin/scripts/gate-test.ps1`，要「全部通過」
3. 動到規則、技能或範本 → 在臨時資料夾複製 `templates/project/` 建一個 ai-os 專案，用 `claude -p` 實測行為，測完刪除
4. `git commit`，第一行用白話說「這版改了什麼」，然後 `git push`（其他電腦靠 GitHub 上的版本更新）
5. 安裝方式、指令名稱或使用方式有變 → 同步改 `README.md`

## 回報

用「做完了」格式，寫明影響哪些專案、開新對話才生效；最後一行是「你要做的事」。

## 寫法

規則、技能、範本的每一行都要「拿掉會讓 Claude 做錯」才留：用字精準、不重複、不寫理由（理由放 `設計說明.md`）。改完重讀一次，刪掉可刪的。
