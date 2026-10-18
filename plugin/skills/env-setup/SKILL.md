---
name: env-setup
description: ai-os 專案遇到這些情況時讀：新電腦要裝工具（Node、Git、RTK、CodeGraph、ai-os 外掛）、開案初始化的版控規範、依技術棧追加 MCP、工具失效要降級、commit 閘門（存檔把關 hook）行為異常或要維護。
---

# 環境與版控

> 遇到這些情境才讀：⓪新電腦或工具沒裝 ①開案初始化（版控規範）②開案後設定技術棧 MCP ③工具失效需降級 ④維護 commit 閘門 hook。

---

## 〇、新電腦環境安裝

> ⚠️ **commit 閘門目前只在 Windows 有效**（PowerShell 腳本）。Mac／Linux／WSL 上不會執行也不會報錯，每次 commit 前要自己確認驗證跑過。

先用下列指令檢查，有版本號就代表裝好了；缺哪個再照表安裝：
```powershell
node --version      # 需 v18 以上
git --version
claude --version
rtk --version       # 若顯示的不是 Rust Token Killer，代表裝到同名的別套工具
codegraph --version
```

| 工具 | 用途 | 安裝 |
|---|---|---|
| Node.js（v18+）| 執行 Claude Code、CodeGraph | [nodejs.org](https://nodejs.org) 下載 LTS 版 |
| Git | 版本控制 | [git-scm.com](https://git-scm.com) |
| Claude Code | AI 開發環境 | `npm install -g @anthropic-ai/claude-code`，第一次執行 `claude` 會引導登入 |
| RTK | 過濾指令輸出的雜訊、省 context | 從 [github.com/rtk-ai/rtk/releases](https://github.com/rtk-ai/rtk/releases) 下載最新版 Windows 檔（`rtk-x86_64-pc-windows-msvc.zip`），解壓到 `%USERPROFILE%\.local\bin` 並加進使用者 PATH；**再跑一次 `rtk init -g`**——Bash 指令的 RTK hook 靠全域設定，ai-os 專案的 `.claude/settings.json` 只處理 PowerShell 指令 |
| CodeGraph | 查程式碼依賴關係 | `npm install -g @colbymchenry/codegraph`；每個新專案 `git init` 後跑一次 `codegraph init -i`（開案流程已包含）|

依技術棧追加：Python 專案要 Python 3.10+（安裝時勾選 Add to PATH，內含 pip／venv）；用 Supabase 時要 `npm install -g supabase`。

**裝 ai-os 外掛**（共用規則、技能、子 Agent、commit 閘門都在裡面）：把 ai-os 資料夾放到使用者家目錄下的 `ai-os`（從 GitHub 下載或從舊電腦複製；放在家目錄的 `ai-os` 最好，文件裡的路徑都照這個寫），然後：
```bash
claude plugin marketplace add ~/ai-os
claude plugin install ai-os@jay-ai-os
```
重開 Claude Code 後，`/plugin` 裡應看到 ai-os 已啟用。

---

## 一、開案初始化：版本控制規範

### 新專案初始化必做
1. `git init -b main`（框架腳手架若已建立，確認即可）
2. **`.gitignore`：開案時已從外掛複製一份**（含機密／依賴／建置產出／測試產出／Claude Code／CodeGraph 索引／系統 IDE）。依 STACK_RULES 在末段「專案自訂」追加技術棧特有排除
3. `git status` 確認機密檔（`.env*`、`_secrets/`）**沒有出現在待追蹤清單**後，才執行第一次 commit

### 應 commit（初始化 commit 必須包含）
```
CLAUDE.md  .claude/  .mcp.json  .gitignore
_管理/  _產出/  _開發檔案/  .github/  playwright.config.ts  程式碼目錄  技術棧設定檔
```
> `.github/` 與 `playwright.config.ts` 要進 repo，否則 CI（push main 自動跑 Playwright）不會啟用。
> `.mcp.json` 要進 repo，否則 CodeGraph MCP 不會被載入（見第二節）。

### 不追蹤（已寫入 `.gitignore`）
機密（`.env*`，`.env.example` 例外保留／`_secrets/`）、依賴目錄（`node_modules/`／`.venv/`）、建置產出（`.next/`／`dist/`）、測試產出（`test-results/`／`playwright-report/`）、`.claude/worktrees/`、`.claude/settings.local.json`、`_管理/.verify-marker`（commit 閘門的執行期產物）、`_管理/全分支diff.txt`（審查暫存）、`.codegraph/`、系統與 IDE 檔。

> **改 `.gitignore` 的陷阱**：不支援行尾註解——`#` 只有在行首才是註解。寫成 `.claude/worktrees/    # 說明` 會讓整串變成字面 pattern 而完全失效。改完實測：`git check-ignore -v -- <該路徑>`，有輸出才代表規則生效。

---

## 二、MCP 設定位置與依技術棧追加

| 設定檔 | 作用 |
|---|---|
| **`.mcp.json`（專案根目錄）** | **定義**專案層 MCP server ← 開案時已寫入 CodeGraph，追加 MCP 也加在這裡 |
| `.claude/settings.json` | 自動放行的指令、PowerShell 的 RTK hook、`enableAllProjectMcpServers`（自動核准 `.mcp.json` 的 server）。`mcpServers` 寫在這裡不會生效 |

> **驗證方式**：在專案內輸入 `/mcp`，codegraph 應出現在清單中。

### 依技術棧追加的 MCP（加到 `.mcp.json` 的 `mcpServers`）

開案時依 STACK_RULES 判斷需要哪些並加入；預設只含 CodeGraph（RTK 走 hook 不是 MCP）：

| MCP | 主要使用者 | 用途 | 適用棧 |
|---|---|---|---|
| Supabase | 主 Agent／`ai-os:builder` | 執行 SQL、查 schema、產型別（⚠️ 只連 dev project）| Supabase |
| Context7 | 主 Agent／`ai-os:builder` | 即時拉版本文件，防廢棄 API 幻覺 | 多數 JS/TS 棧 |
| Playwright | `ai-os:tester` | 操作瀏覽器驗證 UI 行為（MCP 即時 + 腳本回歸兩模式）| Web 前端 |
| Vercel | 主 Agent | 查部署、build/runtime log、env | Vercel 部署 |

> **加完 Playwright MCP 後**：確認外掛 `agents/tester.md` frontmatter 的工具白名單涵蓋實際的工具名稱前綴（以 `.mcp.json` 安裝為 `mcp__playwright__*`，以 plugin 安裝為 `mcp__plugin_playwright_playwright__*`）。白名單對不上時 tester 會默默只寫腳本、不即時驗收。

### 環境變數與金鑰隔離（通用規則，不限特定服務）

任何串接第三方服務的金鑰／連線字串（資料庫、金流、email/簡訊/推播、外部 AI API），STACK_RULES 建檔時要註明 **dev/test/prod 各自的取得方式**。

執行任何會產生真實副作用的操作前（送出 API 請求、跑 migration、發送通知、扣款），若無法從當下 context 判斷目前用的是哪個環境的金鑰，**停下回報，不假設是安全的**（共用規則「紅線」第 7 項）。新增技術棧時只需在 STACK_RULES 註明對應服務的 dev/test 金鑰位置。

### 非 MCP 的兩項工具

| 工具 | 怎麼啟用 |
|---|---|
| **Chrome 整合** | 需安裝 [Claude in Chrome 擴充套件](https://chromewebstore.google.com/detail/claude/fcoeoabgfenejglbffodgkkbkcdhcgfn)，啟動加 `--chrome` 或 session 內輸入 `/chrome` |
| **GitHub Actions CI** | 開案時已附 `.github/workflows/test.yml`（push／PR main 自動跑 typecheck → unit test → build → Playwright；typecheck 與 unit test 用 `--if-present`，沒有對應 npm script 就略過，指令依 STACK_RULES 調整）。開案初始化會補好 `playwright.config.ts` 的 `webServer` 與 CI 需要的測試用環境變數；骨架完成前 CI 會紅，屬正常 |

---

## 三、工具降級方案

工具無法執行時按下表降級，核心規則不受影響，只影響效率：

| 工具不可用 | 降級做法 | 效率影響 |
|---|---|---|
| RTK | 直接執行指令 | token 節省失效 |
| CodeGraph | 改用 Grep 查依賴 | 依賴查詢變慢 |
| Supabase MCP | 產 SQL 後請使用者手動在 Dashboard 執行 | 需人工介入 |
| Context7 | 遇 API 問題手動查官方文件 | 廢棄 API 風險上升 |
| Playwright MCP | 改寫測試腳本執行（`npx playwright test`）| 無法即時瀏覽器驗證，仍有腳本回歸保護 |
| Chrome 整合 | 改用 Playwright MCP 或手動開瀏覽器 | — |
| Vercel MCP | 開瀏覽器進 Dashboard | 需切換視窗 |

工具可以降級，原則不可以：CodeGraph 掛了改用 Grep 查誰在用（原則一照做）；Playwright MCP 掛了改跑腳本（驗證證據照樣要附實跑結果）。

---

## 四、commit 閘門（hook）維護須知

> ⚠️ **閘門僅 Windows PowerShell 生效**。Mac／Linux／WSL 環境不執行、且不報錯——需人工在 commit 前確認驗證已跑。

**行為摘要**：只有「成功結束」的驗證指令才算數（Claude Code 只在指令成功時觸發記錄用的 hook，失敗的 build／測試不會留下紀錄，commit 照樣被擋）；不解析輸出內容；嚴格模式（改碼 → 跑測試 → 又改一行必須重跑）；`git push` 不攔。**只管 ai-os 專案**：repo 根目錄沒有 `_管理/常駐/此次任務.md` 就直接放行，所以不會干擾其他專案（包括 ai-os 外掛自己的資料夾）。

兩支腳本加一支自我測試，都在外掛的 `${CLAUDE_PLUGIN_ROOT}/scripts/`，掛在外掛的 `hooks/hooks.json`：

| 腳本 | 事件 | 作用 |
|---|---|---|
| `mark-verify.ps1` | PostToolUse (Bash／PowerShell，背景執行) | 偵測到驗證類指令 → 寫專案的 `_管理/.verify-marker` |
| `verify-gate.ps1` | PreToolUse (Bash／PowerShell) | `git commit` 前檢查標記是否比最新 staged 程式碼檔更新 |
| `gate-test.ps1` | — | 在暫存 repo 實跑各情境的自我測試 |

### 改這些腳本時的陷阱

1. **必須存成 UTF-8 with BOM**。Windows PowerShell 5.1 讀 `.ps1` 預設用 ANSI，UTF-8 無 BOM 的中文會變亂碼並造成解析失敗（腳本整個不執行 → 閘門默默失效）。存檔後確認 BOM：
   ```powershell
   $p = "$HOME\ai-os\plugin\scripts\verify-gate.ps1"
   $c = Get-Content -Raw -Encoding UTF8 $p
   [System.IO.File]::WriteAllText($p, $c, (New-Object System.Text.UTF8Encoding($true)))
   ```
2. **`[Console]::OutputEncoding` 要設 UTF-8**（`verify-gate.ps1` 開頭已設），否則擋下訊息的中文會變亂碼。
3. **新增技術棧要到 `mark-verify.ps1` 與 `verify-gate.ps1` 追加驗證指令 pattern**。沒加的話，該棧的測試跑了也不被認可 → 每次 commit 都被擋。
4. **`hooks.json` 用 `${CLAUDE_PLUGIN_ROOT}` 指到腳本**，腳本內要 `Set-Location (git rev-parse --show-toplevel)`，否則 cwd 不在專案根時會解析失敗 → 默默放行。
5. **兩支腳本都要設 `[Console]::InputEncoding` 為 UTF-8**，否則指令或路徑含中文時讀成亂碼、JSON 解析失敗（2026-10-18 實測 mark-verify 因此漏寫標記）。**讀 stdin 後也要先去掉開頭 BOM**（`$raw.TrimStart([char]0xFEFF)`），否則 JSON 解析失敗 → 默默放行（2026-10-18 實測：gate-test 5 項該擋的全部放行）。腳本出錯時會寫進 `%TEMP%\ai-os-gate-error.log`，閘門行為可疑時先看這個檔。
6. **hook 的 `matcher` 要同時涵蓋 `Bash` 與 `PowerShell`**。Windows 上 Claude 常改用 PowerShell 工具跑指令，只寫 `Bash` 會讓閘門整個不作用且沒有錯誤（2026-10-10 實測）。

### 已知的設計取捨（不是 bug）

| 行為 | 原因 |
|---|---|
| `npm run build && git commit` 連鎖指令被放行 | hook 在整串執行**前**判斷，此時驗證尚未跑；偵測到同串含驗證指令即放行 |
| stage 之後又動工作區導致 commit 被擋 | 閘門用 index 時間判斷已 stage 的快照，以保守為準。正解是重跑驗證 |
| 豁免採目錄級（`_管理/`／`.claude/`／`.github/` 下一律放行）| 這些目錄只放文件與設定。例外：`.ps1/.sh/.py/.js/.ts` 等可執行腳本即使在豁免目錄下仍視為程式碼 |
| 每次指令都會啟動 PowerShell 跑閘門（約 0.3 秒）| 刻意不用 hook 的 `if` 欄位過濾：`if: "Bash(git *)"` 抓不到 `rtk proxy git commit` 這類包裝寫法。標記腳本設 `async: true` 在背景跑。RTK hook：Bash 由全域 `~/.claude/settings.json` 負責（`rtk init -g`），ai-os 專案的 `.claude/settings.json` 只掛 PowerShell，避免 Bash 指令被處理兩次 |

### 改完必測

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME/ai-os/plugin/scripts/gate-test.ps1"
```
要「全部通過」。涵蓋：未驗證的程式碼 commit 擋下、commit 訊息裡的驗證字樣不算驗證、`git push` 與非 commit 指令放行、只有文件的 commit 放行、同串先 build 再 commit 放行、`git add` 與 commit 寫在同一串仍擋下、不是 ai-os 專案就放行。

手動測單一情境（在一個有 `_管理/常駐/此次任務.md` 的臨時 git repo 裡，把 JSON 餵給腳本）：
```powershell
'{"tool_name":"Bash","tool_input":{"command":"git commit -m \"x\""}}' | powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME/ai-os/plugin/scripts/verify-gate.ps1"
```
輸出含 `"deny"` ＝ 擋下；無輸出 ＝ 放行。

---

## 五、自動放行的指令（減少權限確認）

ai-os 專案 `.claude/settings.json` 的 `permissions.allow`（開案時從外掛複製）預先放行常用的安全指令（git 的查看／add／commit／push／tag、npm run／test、tsc、playwright test、codegraph）。**刻意不放行**：`git checkout`、`git branch`、`git stash`（可能丟掉未保存的修改或分支）、`rm`、`--force`。放行不影響 commit 閘門。要增減清單直接改該檔；要讓之後的新專案也套用，改外掛 `templates/project/.claude/settings.json`。
