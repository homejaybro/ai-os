---
name: env-setup
description: ai-os 專案遇到這些情況時讀：新電腦要裝工具（Node、Git、CodeGraph、ai-os 外掛）、新階段開工前檢查套件與工具更新、開案初始化的版控規範、依技術棧追加 MCP、工具失效要降級、存檔把關（hook）行為異常。
---

# 環境與版控

## 〇、新電腦環境安裝

ai-os 外掛（自動載入規則、每回合提醒、存檔把關）只在 Windows 有效。Mac／Linux／WSL 上不執行也不報錯，每次 commit 前要自己確認驗證跑過。外掛本身的安裝與更新見外掛 GitHub 倉庫的 `README.md`。

### 檢查與安裝（開案、或下載既有倉庫後做；全都有就不提）

1. 檢查（有版本號就是裝好了）：`node --version`（需 v18 以上）、`git --version`、`codegraph --version`。
2. 有缺 → 一次列出缺哪些、各一句白話用途，問一次「要我幫你裝嗎？會用 Windows 內建的 winget，等於同意這些軟體的授權條款；中途 Windows 跳出『是否允許變更』請按『是』」。使用者不同意 → 給第 4 步的手動網址；沒裝好不往下做。
3. 同意後依序跑（每個指令前先刷新 PATH：`$env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User')`）：

| 工具 | 指令 |
|---|---|
| Node.js | `winget install -e --id OpenJS.NodeJS.LTS --accept-package-agreements --accept-source-agreements` |
| Git | `winget install -e --id Git.Git --accept-package-agreements --accept-source-agreements` |
| CodeGraph（Node 裝好後）| `npm install -g @colbymchenry/codegraph` |

4. 刷新 PATH 後重跑第 1 步確認。仍抓不到、或沒有 winget → 給手動網址：Node.js [nodejs.org](https://nodejs.org)（LTS 版）、Git [git-scm.com](https://git-scm.com)。
5. 有裝任何東西 → 請使用者把 Claude Code 完全關掉重開，在同一個資料夾開新對話、把剛才的需求再說一次（Claude Code 要重開才抓得到新工具）。

依技術棧追加：Python 專案要 Python 3.10+（安裝時勾選 Add to PATH）；用 Supabase 時要 `npm install -g supabase`。

## 一、開案初始化：版本控制規範

步驟在 `_管理/開案確認.md`「初始化執行步驟」。首次 commit 要包含：
```
CLAUDE.md  .claude/  .mcp.json  .gitignore
_管理/  _產出/  _開發檔案/  程式碼目錄  技術棧設定檔
（網站專案另含）.github/  playwright.config.ts
```
`.github/` 沒進 repo，自動測試不會啟用；`.mcp.json` 沒進 repo，CodeGraph MCP 不會載入。

### .gitignore 的陷阱
`#` 只有在行首才是註解，不支援行尾註解——`.claude/worktrees/    # 說明` 會整串變成字面 pattern 而失效。改完實測 `git check-ignore -v -- <該路徑>`，有輸出才代表生效。

## 二、MCP 設定位置與依技術棧追加

| 設定檔 | 作用 |
|---|---|
| `.mcp.json`（專案根目錄）| 定義專案層 MCP server；開案時已寫入 CodeGraph，追加 MCP 也加在這裡 |
| `.claude/settings.json` | 自動放行與每次要問的指令、`enableAllProjectMcpServers`。`mcpServers` 寫在這裡不會生效 |

驗證：在專案內輸入 `/mcp`，codegraph 應在清單中。

### 依技術棧追加的 MCP（加到 `.mcp.json` 的 `mcpServers`）

開案時依 STACK_RULES 判斷需要哪些；預設只含 CodeGraph：

| MCP | 主要使用者 | 用途 | 適用棧 |
|---|---|---|---|
| Supabase | 主 Agent／`ai-os:builder` | 執行 SQL、查 schema、產型別（只連 dev project）| Supabase |
| Context7 | 主 Agent／`ai-os:builder` | 即時拉版本文件，防廢棄 API | 多數 JS/TS 棧 |
| Playwright | `ai-os:tester` | 操作瀏覽器驗證 UI 行為 | Web 前端 |
| Vercel | 主 Agent | 查部署、build/runtime log、env | Vercel 部署 |

### 環境變數與金鑰隔離

任何串接第三方服務的金鑰／連線字串（資料庫、金流、email/簡訊/推播、外部 AI API），金鑰一律不寫死、由環境變數決定；資料庫何時分測試庫見共用規則「資料安全的固定做法」，金流等第三方服務任何階段都要有測試金鑰；STACK_RULES 註明各自的取得方式。

執行會產生真實副作用的操作前（送出 API 請求、跑 migration、發送通知、扣款），無法從當下 context 判斷用的是哪個環境的金鑰 → 停下回報，不假設是安全的（紅線第 7 項）。

### 非 MCP 的兩項工具

| 工具 | 怎麼啟用 |
|---|---|
| Chrome 整合 | 使用者要你操作他自己的 Chrome 時才需要：安裝 [Claude in Chrome 擴充套件](https://chromewebstore.google.com/detail/claude/fcoeoabgfenejglbffodgkkbkcdhcgfn)，session 內輸入 `/chrome` |
| GitHub 自動測試 | 網站專案開案時附 `.github/workflows/test.yml`（push／PR 到主線自動跑 typecheck → unit test → build → Playwright）。開案初始化會補好 `playwright.config.ts` 的 `webServer` 與需要的測試用環境變數；骨架完成前會紅，屬正常 |

## 三、工具降級方案

| 工具不可用 | 降級做法 |
|---|---|
| CodeGraph | 改用 Grep 查依賴 |
| Supabase MCP | 改用 Supabase CLI 執行（如 `supabase db push`）；CLI 也不能用才請使用者在 Dashboard 貼上執行 |
| Context7 | 遇 API 問題手動查官方文件 |
| Playwright MCP | 改跑測試腳本（`npx playwright test`）|
| AskUserQuestion（選擇題視窗）| 改成文字，一次一題、附建議答案 |
| Chrome 整合 | 改用 Playwright MCP 或手動開瀏覽器 |
| Vercel MCP | 開瀏覽器進 Dashboard |

工具可以降級，原則不可以：CodeGraph 掛了照樣用 Grep 查誰在用；Playwright MCP 掛了驗證證據照樣要附實跑結果。

## 四、存檔把關（hook）

行為：只有成功結束、而且真的在跑驗證的指令才算數（裝套件、看版本、`--if-present` 不算；失敗的 build／測試不留紀錄，commit 照樣被擋）；不解析輸出內容；嚴格模式（改碼 → 跑測試 → 又改一行必須重跑）；`git push` 不攔；`_產出/` 的成品不算程式碼。repo 根目錄沒有 `_管理/常駐/此次任務.md`，或有 `_開發檔案/scripts/hooks/verify-gate.ps1`（舊範本專案，自帶把關）→ 直接放行。

腳本都在 `${CLAUDE_PLUGIN_ROOT}/scripts/`，掛在外掛的 `hooks/hooks.json`：

| 腳本 | 事件 | 作用 |
|---|---|---|
| `mark-verify.ps1` | PostToolUse (Bash／PowerShell，背景執行) | 偵測到驗證類指令 → 寫專案的 `_管理/.verify-marker` |
| `verify-gate.ps1` | PreToolUse (Bash／PowerShell) | `git commit` 前檢查標記是否比最新 staged 程式碼檔更新 |

### 存檔把關異常時

1. 腳本出錯會寫進 `%TEMP%\ai-os-gate-error.log`，行為可疑時先看這個檔。
2. 某個技術棧的測試指令不被認可、每次 commit 都被擋 → 不要繞過（包括自己寫 `_管理/.verify-marker`），回報使用者：可先把該指令寫進 `package.json` 的 `test` script、改用 `npm test` 執行；長期要到外掛倉庫的 `mark-verify.ps1`、`verify-gate.ps1` 追加該指令的 pattern（不在專案裡改）。

### 已知的設計取捨（不是 bug）

| 行為 | 原因 |
|---|---|
| `npm run build && git commit` 連鎖指令被放行 | hook 在整串執行前判斷；同串含驗證指令即放行 |
| stage 之後又動工作區導致 commit 被擋 | 保守判斷，正解是重跑驗證 |
| `_管理/`／`_產出/`／`.claude/`／`.github/` 下一律放行 | 例外：`.ps1/.sh/.py/.js/.ts` 等可執行腳本仍視為程式碼 |
| 每次指令都會啟動 PowerShell 跑把關（約 0.3 秒）| 不用 hook 的 `if` 欄位過濾：抓不到 `xxx git commit` 這類包裝寫法 |
| 背景執行的驗證指令不算數 | 背景一啟動就回報成功，測試其實還沒跑完 |

## 五、自動放行的指令

專案 `.claude/settings.json` 的 `permissions.allow` 預先放行常用的安全指令（git 的查看／add／commit／push／tag／merge、開分支、`git stash push/pop/list`、npm run／test／outdated／audit／update、tsc、playwright test、codegraph）。刻意不放行：`git checkout --`（丟棄修改）、`git branch -D`、`git reset`、`git clean`、`git stash drop/clear`、`rm`。`git push --force`／`-f`、`npm run deploy*`、`npm run *reset*` 放在 `permissions.ask`，每次都問。要增減清單直接改該檔；要讓之後的新專案也套用，到外掛倉庫改 `templates/project/.claude/settings.json`。

## 六、套件與工具更新（新階段開工前）

時機：新階段的決策總表核准後、動工前，每階段一次；開案後的第一版不做（剛裝好）。工作區有未存檔的修改時先收尾再做。

1. 套件：依 STACK_RULES 的套件管理工具檢查。npm → `npm outdated`、`npm audit`；pip → `pip list --outdated`（有 `pip-audit` 就一起跑）；其他工具用對應指令。
   - 安全修補與不跨大版本的更新：自己做（npm → `npm audit fix`、`npm update`，不加 `--force`）→ 跑全部測試 → 通過就 commit「更新套件（安全修補與小版本）」；失敗就還原套件清單與鎖定檔（`git checkout -- package.json package-lock.json` 後 `npm install`），報告時一句話帶過。
   - 跨大版本（可能要改程式）或修補漏洞必須跨大版本的：列給使用者，每項一句好處、一句風險，問一次。同意後一次升一個，每個都跑全部測試，失敗就還原那一個並說明。
2. 工具：`winget upgrade` 裡有 Node.js、Git，或 `npm outdated -g @colbymchenry/codegraph` 有新版 → 列出來問一次。同意後跑 `winget upgrade -e --id <ID> --accept-package-agreements --accept-source-agreements`、`npm install -g @colbymchenry/codegraph@latest`，再照第〇節第 4、5 步確認並請使用者重開。Node.js 跨大版本時，同意後先跑全部測試確認專案還能用。
3. 都沒有可更新的 → 不提。
