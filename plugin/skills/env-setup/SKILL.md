---
name: env-setup
description: ai-os 專案遇到這些情況時讀：新電腦要裝工具（Node、Git、RTK、CodeGraph、ai-os 外掛）、開案初始化的版控規範、依技術棧追加 MCP、工具失效要降級、commit 閘門（存檔把關 hook）行為異常。
---

# 環境與版控

## 〇、新電腦環境安裝

ai-os 外掛（自動載入規則、每回合提醒、commit 閘門）只在 Windows 有效。Mac／Linux／WSL 上不執行也不報錯，每次 commit 前要自己確認驗證跑過。外掛本身的安裝與更新見外掛 GitHub 倉庫的 `README.md`。

先檢查，有版本號就代表裝好了；缺哪個再照表安裝：
```powershell
node --version      # 需 v18 以上
git --version
claude --version
rtk --version       # 顯示的不是 Rust Token Killer ＝裝到同名的別套工具
codegraph --version
```

| 工具 | 安裝 |
|---|---|
| Node.js（v18+）| [nodejs.org](https://nodejs.org) 下載 LTS 版 |
| Git | [git-scm.com](https://git-scm.com) |
| Claude Code | `npm install -g @anthropic-ai/claude-code`，第一次執行 `claude` 會引導登入 |
| RTK | 從 [github.com/rtk-ai/rtk/releases](https://github.com/rtk-ai/rtk/releases) 下載最新版 `rtk-x86_64-pc-windows-msvc.zip`，解壓到 `%USERPROFILE%\.local\bin` 並加進使用者 PATH；再跑一次 `rtk init -g`（Bash 指令的 RTK hook 靠全域設定，專案的 `.claude/settings.json` 只處理 PowerShell）|
| CodeGraph | `npm install -g @colbymchenry/codegraph`；每個新專案 `git init` 後跑一次 `codegraph init -i` |

依技術棧追加：Python 專案要 Python 3.10+（安裝時勾選 Add to PATH）；用 Supabase 時要 `npm install -g supabase`。

## 一、開案初始化：版本控制規範

### 新專案初始化必做
1. `git init -b main`（框架腳手架若已建立，確認即可）
2. `.gitignore` 開案時已從外掛複製；依 STACK_RULES 在末段「專案自訂」追加技術棧特有排除
3. `git status` 確認機密檔（`.env*`、`_secrets/`）沒有出現在待追蹤清單，才做第一次 commit

### 應 commit（初始化 commit 必須包含）
```
CLAUDE.md  .claude/  .mcp.json  .gitignore
_管理/  _產出/  _開發檔案/  .github/  playwright.config.ts  程式碼目錄  技術棧設定檔
```
`.github/`、`playwright.config.ts` 沒進 repo，CI 不會啟用；`.mcp.json` 沒進 repo，CodeGraph MCP 不會載入。

### .gitignore 的陷阱
`#` 只有在行首才是註解，不支援行尾註解——`.claude/worktrees/    # 說明` 會整串變成字面 pattern 而失效。改完實測 `git check-ignore -v -- <該路徑>`，有輸出才代表生效。

## 二、MCP 設定位置與依技術棧追加

| 設定檔 | 作用 |
|---|---|
| `.mcp.json`（專案根目錄）| 定義專案層 MCP server；開案時已寫入 CodeGraph，追加 MCP 也加在這裡 |
| `.claude/settings.json` | 自動放行的指令、PowerShell 的 RTK hook、`enableAllProjectMcpServers`。`mcpServers` 寫在這裡不會生效 |

驗證：在專案內輸入 `/mcp`，codegraph 應在清單中。

### 依技術棧追加的 MCP（加到 `.mcp.json` 的 `mcpServers`）

開案時依 STACK_RULES 判斷需要哪些；預設只含 CodeGraph（RTK 走 hook 不是 MCP）：

| MCP | 主要使用者 | 用途 | 適用棧 |
|---|---|---|---|
| Supabase | 主 Agent／`ai-os:builder` | 執行 SQL、查 schema、產型別（只連 dev project）| Supabase |
| Context7 | 主 Agent／`ai-os:builder` | 即時拉版本文件，防廢棄 API | 多數 JS/TS 棧 |
| Playwright | `ai-os:tester` | 操作瀏覽器驗證 UI 行為 | Web 前端 |
| Vercel | 主 Agent | 查部署、build/runtime log、env | Vercel 部署 |

加完 Playwright MCP 後：確認外掛 `agents/tester.md` frontmatter 的工具白名單涵蓋實際的工具名稱前綴（以 `.mcp.json` 安裝為 `mcp__playwright__*`，以 plugin 安裝為 `mcp__plugin_playwright_playwright__*`），否則 tester 會默默只寫腳本、不即時驗收。

### 環境變數與金鑰隔離

任何串接第三方服務的金鑰／連線字串（資料庫、金流、email/簡訊/推播、外部 AI API），STACK_RULES 要註明 dev/test/prod 各自的取得方式。

執行會產生真實副作用的操作前（送出 API 請求、跑 migration、發送通知、扣款），無法從當下 context 判斷用的是哪個環境的金鑰 → 停下回報，不假設是安全的（紅線第 7 項）。

### 非 MCP 的兩項工具

| 工具 | 怎麼啟用 |
|---|---|
| Chrome 整合 | 安裝 [Claude in Chrome 擴充套件](https://chromewebstore.google.com/detail/claude/fcoeoabgfenejglbffodgkkbkcdhcgfn)，啟動加 `--chrome` 或 session 內輸入 `/chrome` |
| GitHub Actions CI | 開案時已附 `.github/workflows/test.yml`（push／PR main 自動跑 typecheck → unit test → build → Playwright；typecheck 與 unit test 沒有對應 npm script 就略過，指令依 STACK_RULES 調整）。開案初始化會補好 `playwright.config.ts` 的 `webServer` 與 CI 需要的測試用環境變數；骨架完成前 CI 會紅，屬正常 |

## 三、工具降級方案

| 工具不可用 | 降級做法 |
|---|---|
| RTK | 直接執行指令 |
| CodeGraph | 改用 Grep 查依賴 |
| Supabase MCP | 產 SQL 後請使用者手動在 Dashboard 執行 |
| Context7 | 遇 API 問題手動查官方文件 |
| Playwright MCP | 改跑測試腳本（`npx playwright test`）|
| Chrome 整合 | 改用 Playwright MCP 或手動開瀏覽器 |
| Vercel MCP | 開瀏覽器進 Dashboard |

工具可以降級，原則不可以：CodeGraph 掛了照樣用 Grep 查誰在用；Playwright MCP 掛了驗證證據照樣要附實跑結果。

## 四、commit 閘門（hook）

行為：只有成功結束的驗證指令才算數（失敗的 build／測試不留紀錄，commit 照樣被擋）；不解析輸出內容；嚴格模式（改碼 → 跑測試 → 又改一行必須重跑）；`git push` 不攔。repo 根目錄沒有 `_管理/常駐/此次任務.md`，或有 `_開發檔案/scripts/hooks/verify-gate.ps1`（舊範本專案，自帶閘門）→ 直接放行。

腳本都在 `${CLAUDE_PLUGIN_ROOT}/scripts/`，掛在外掛的 `hooks/hooks.json`：

| 腳本 | 事件 | 作用 |
|---|---|---|
| `mark-verify.ps1` | PostToolUse (Bash／PowerShell，背景執行) | 偵測到驗證類指令 → 寫專案的 `_管理/.verify-marker` |
| `verify-gate.ps1` | PreToolUse (Bash／PowerShell) | `git commit` 前檢查標記是否比最新 staged 程式碼檔更新 |

### 閘門異常時

1. 腳本出錯會寫進 `%TEMP%\ai-os-gate-error.log`，閘門行為可疑時先看這個檔。
2. 某個技術棧的測試指令不被認可、每次 commit 都被擋 → 不要繞過，回報使用者：要到外掛的 `mark-verify.ps1`、`verify-gate.ps1` 追加該指令的 pattern（在外掛倉庫改，不在專案裡改）。

### 已知的設計取捨（不是 bug）

| 行為 | 原因 |
|---|---|
| `npm run build && git commit` 連鎖指令被放行 | hook 在整串執行前判斷；同串含驗證指令即放行 |
| stage 之後又動工作區導致 commit 被擋 | 閘門保守判斷，正解是重跑驗證 |
| `_管理/`／`.claude/`／`.github/` 下一律放行 | 例外：`.ps1/.sh/.py/.js/.ts` 等可執行腳本仍視為程式碼 |
| 每次指令都會啟動 PowerShell 跑閘門（約 0.3 秒）| 不用 hook 的 `if` 欄位過濾：`if: "Bash(git *)"` 抓不到 `rtk proxy git commit`。RTK hook：Bash 由全域設定負責，專案 `.claude/settings.json` 只掛 PowerShell，避免處理兩次 |

## 五、自動放行的指令

專案 `.claude/settings.json` 的 `permissions.allow` 預先放行常用的安全指令（git 的查看／add／commit／push／tag、npm run／test、tsc、playwright test、codegraph）。刻意不放行：`git checkout`、`git branch`、`git stash`、`rm`、`--force`。要增減清單直接改該檔；要讓之後的新專案也套用，改外掛 `templates/project/.claude/settings.json`。
