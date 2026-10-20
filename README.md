# AI OS

Claude Code 外掛：讓 Claude 用同一套規則開發專案——先問清楚再做、碰到刪資料／上線／扣款一定先問你、做完要附實際測試結果、每次回覆告訴你下一步。規則只有一份，改一次所有專案都套用。

## 安裝（新電腦或另一個 Claude 帳號）

需要：Windows、已安裝 Claude Code（桌面版或終端機版）、Git。
這是私人倉庫：安裝的電腦要能用有權限的 GitHub 帳號存取它（第一次可能跳出 GitHub 登入）。要給別的 GitHub 帳號用，先在倉庫的 Settings → Collaborators 邀請對方，或把倉庫改成公開。

**桌面版**
1. 左下角進入「自訂」→「外掛程式」。
2. 按右上角「新增」，選加入外掛市集，輸入 `homejaybro/ai-os`。
3. 在清單裡找到 **AI OS**，安裝。
4. 在外掛市集的設定裡開啟**自動更新**（之後規則有改，會自己更新）。
5. 把 Claude Code 關掉重開。

**終端機版**（任一資料夾執行）
```bash
claude plugin marketplace add homejaybro/ai-os
claude plugin install ai-os@jay-ai-os
```

裝好後在對話輸入 `/`，看得到 `ai-os:` 開頭的指令就成功了。

## 使用

| 想做什麼 | 怎麼做 |
|---|---|
| 開新專案 | 開一個空資料夾，跟 Claude 說「開案」（或輸入 `/ai-os:start-project`）|
| 既有專案改用這套規則 | 在那個專案輸入 `/ai-os:adopt` |
| 加新功能 | 直接描述，或輸入 `/ai-os:brainstorming` |
| 暫停使用 | 「自訂」→「外掛程式」→ AI OS 右邊「⋮」→ 停用 |

建議另外安裝的工具（Node.js、RTK、CodeGraph）與用法，開好專案後問 Claude「新電腦要裝什麼」即可。

## 更新規則

在放這個倉庫的電腦上，用 Claude Code 開啟這個資料夾，直接說要改什麼（例如「讓回報再短一點」）。Claude 會照 `CLAUDE.md` 的維修規則修改、測試、上傳。其他電腦開了自動更新會自己拿到新版；沒開的話到「外掛程式」頁按更新。改動在**下一個新對話**生效。

## 限制

目前只支援 Windows：自動載入規則、每回合提醒、存檔前檢查都是 PowerShell 腳本，在 Mac 上不會作用也不會報錯。
