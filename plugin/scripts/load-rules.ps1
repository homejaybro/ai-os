# SessionStart hook：在 ai-os 專案開對話時，把共用規則（rules.md）送進對話
#
# 為什麼不用專案 CLAUDE.md 的 @<外掛路徑>/rules.md 匯入：匯入外部檔案要使用者在確認框核准，
# 但 Claude 桌面版不會跳出這個確認框（2026-10-19 實測：hasClaudeMdExternalIncludesWarningShown 一直是 false），
# 匯入因此永遠不生效。hook 送進來的內容不需要核准，也只在 ai-os 專案觸發。
# matcher 設 startup|clear|compact：開新對話、/clear、壓縮後都重送；resume 時對話紀錄裡已經有，不重送。
# 失敗行為：任何錯誤都不 throw（exit 0），錯誤寫進 %TEMP%\ai-os-gate-error.log；確定是 ai-os 專案時另送一段提示，叫 Claude 先告知使用者規則沒載入。⚠️ 須存 UTF-8 with BOM。

try {
    [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
    $proj = $env:CLAUDE_PROJECT_DIR
    if (-not $proj) { $proj = (Get-Location).Path }
    if (-not (Test-Path -LiteralPath (Join-Path $proj '_管理/常駐/此次任務.md'))) {
        # 空資料夾（只有 .git、.claude 也算）：提醒 Claude 新開發走開案、改既有倉庫先接上規則，不用等使用者講出「開案」
        $items = @(Get-ChildItem -LiteralPath $proj -Force -ErrorAction Stop | Where-Object { $_.Name -notin @('.git', '.claude', 'desktop.ini', 'Thumbs.db') })
        if ($items.Count -gt 0) { exit 0 }
        $hint = '這是空資料夾，裝有 ai-os 外掛（給新專案用的開發規則）。依使用者第一則訊息判斷：' +
                '①要開發新的東西（網站、App、工具、腳本等），不論有沒有說「開案」→ 先用 ai-os:start-project 技能，不直接寫程式。' +
                '②要修改既有的 GitHub 倉庫 → 先照 ai-os:env-setup 技能第〇節「檢查與安裝」做完（要重開就停），再把它下載到這個資料夾本身（git clone <網址> .；資料夾不是全空時改用 git init、git remote add origin <網址>、git pull origin <預設分支>），不要開案；' +
                '下載後有 _管理/常駐/此次任務.md → 讀完 ${CLAUDE_PLUGIN_ROOT}/rules.md 全文並照它做，做完提醒使用者之後開新對話規則會自動載入；' +
                '沒有 → 告訴使用者這個倉庫不歸 ai-os 管，可以直接改，或輸入 /ai-os:adopt 改由 ai-os 管理，讓他選。' +
                '③其他（問問題、看檔案、使用者說不用開案）→ 照常回答。'
        $hint = $hint.Replace('${CLAUDE_PLUGIN_ROOT}', (Resolve-Path (Join-Path $PSScriptRoot '..')).Path)
        @{
            hookSpecificOutput = @{
                hookEventName     = 'SessionStart'
                additionalContext = $hint
            }
        } | ConvertTo-Json -Depth 5 -Compress
        exit 0
    }
    # E-2：用舊範本複製開的專案有自己的規則書（CLAUDE.md）與閘門，不再送新規則，避免兩套規則打架
    if (Test-Path -LiteralPath (Join-Path $proj '_開發檔案/scripts/hooks/verify-gate.ps1')) { exit 0 }
    $isAiOs = $true

    $rulesPath = Join-Path $PSScriptRoot '..\rules.md'
    $rules = [IO.File]::ReadAllText($rulesPath, [Text.Encoding]::UTF8)
    $rules = [regex]::Replace($rules, '<!--[\s\S]*?-->\s*', '')   # 給維護者的註解不送

    $ctx = "這個資料夾是 AI OS 專案（有 _管理/常駐/此次任務.md）。以下是 AI OS 共用規則，由 ai-os 外掛在開對話時載入，" +
           "內容即 ai-os 外掛的 rules.md，作用等同本專案的 CLAUDE.md：`n`n" + $rules

    @{
        hookSpecificOutput = @{
            hookEventName     = 'SessionStart'
            additionalContext = $ctx
        }
    } | ConvertTo-Json -Depth 5 -Compress
} catch {
    try { Add-Content -Path (Join-Path $env:TEMP 'ai-os-gate-error.log') -Value "$(Get-Date -Format o) load-rules: $_" -Encoding utf8 } catch { }
    # 確定是 ai-os 專案才提醒：規則沒載入時，開頭先告訴使用者，避免無規則地開工
    if ($isAiOs) {
        try {
            @{
                hookSpecificOutput = @{
                    hookEventName     = 'SessionStart'
                    additionalContext = '⚠️ ai-os 共用規則載入失敗，本次對話沒有規則。回覆的第一句先告訴使用者「規則沒載入，建議關掉重開對話；仍失敗我可以幫你讀錯誤紀錄（%TEMP%\ai-os-gate-error.log）」；規則恢復前，不做資料庫、部署、刪除類操作，其餘再回答他的問題。'
                }
            } | ConvertTo-Json -Depth 5 -Compress
        } catch { }
    }
}
exit 0
