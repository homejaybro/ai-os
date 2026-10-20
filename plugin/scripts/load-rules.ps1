# SessionStart hook：在 ai-os 專案開對話時，把共用規則（rules.md）送進對話
#
# 為什麼不用專案 CLAUDE.md 的 @<外掛路徑>/rules.md 匯入：匯入外部檔案要使用者在確認框核准，
# 但 Claude 桌面版不會跳出這個確認框（2026-10-19 實測：hasClaudeMdExternalIncludesWarningShown 一直是 false），
# 匯入因此永遠不生效。hook 送進來的內容不需要核准，也只在 ai-os 專案觸發。
# matcher 設 startup|clear|compact：開新對話、/clear、壓縮後都重送；resume 時對話紀錄裡已經有，不重送。
# 失敗行為：任何錯誤都不送（exit 0），錯誤寫進 %TEMP%\ai-os-gate-error.log。⚠️ 須存 UTF-8 with BOM。

try {
    [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
    $proj = $env:CLAUDE_PROJECT_DIR
    if (-not $proj) { $proj = (Get-Location).Path }
    if (-not (Test-Path -LiteralPath (Join-Path $proj '_管理/常駐/此次任務.md'))) { exit 0 }
    # E-2：用舊範本複製開的專案有自己的規則書（CLAUDE.md）與閘門，不再送新規則，避免兩套規則打架
    if (Test-Path -LiteralPath (Join-Path $proj '_開發檔案/scripts/hooks/verify-gate.ps1')) { exit 0 }

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
}
exit 0
