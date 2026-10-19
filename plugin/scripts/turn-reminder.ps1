# UserPromptSubmit hook：ai-os 專案每次使用者送出訊息時，附一行收尾提醒
#
# 為什麼：共用規則只在開對話時送一次（load-rules.ps1），對話一長就容易被稀釋；
# 2026-10-19 實測 invest 新規則對話 9 回合中只有 3 回合有「你要做的事」、1 回合有「做完了」。
# 這一行很短（約 80 字），每回合都在最新位置，讓收尾規則不會被忘記。
# 判斷條件與 load-rules.ps1 相同：有 _管理/常駐/此次任務.md、沒有舊範本自帶的閘門。⚠️ 須存 UTF-8 with BOM。

try {
    [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
    $proj = $env:CLAUDE_PROJECT_DIR
    if (-not $proj) { $proj = (Get-Location).Path }
    if (-not (Test-Path -LiteralPath (Join-Path $proj '_管理/常駐/此次任務.md'))) { exit 0 }
    if (Test-Path -LiteralPath (Join-Path $proj '_開發檔案/scripts/hooks/verify-gate.ps1')) { exit 0 }

    $ctx = 'AI OS 收尾規則：這一回合結束時的最後一則文字，一件事做完就用「## 做完了」完成回報並給一個「下一步建議」；' +
           '還在做或在等使用者時，最後一行寫「你要做的事」。'
    @{
        hookSpecificOutput = @{
            hookEventName     = 'UserPromptSubmit'
            additionalContext = $ctx
        }
    } | ConvertTo-Json -Depth 5 -Compress
} catch {
    try { Add-Content -Path (Join-Path $env:TEMP 'ai-os-gate-error.log') -Value "$(Get-Date -Format o) turn-reminder: $_" -Encoding utf8 } catch { }
}
exit 0
