# PostToolUse hook：偵測到「驗證類指令」執行過，就寫下標記檔
#
# 搭配 verify-gate.ps1 實現「驗證過才能說完成」的技術層閘門。
# 本腳本只記錄「跑過了」，不解析輸出——解析各技術棧輸出
# 脆弱且會誤擋。PostToolUse 只在指令成功（exit 0）時觸發，所以失敗的驗證本來就不會留下標記（2026-10-18 實測）。
#
# 失敗行為：任何錯誤都靜默 exit 0（PostToolUse 本身無法阻擋，且不應干擾流程）。
#
# Test-Verify 必須與 verify-gate.ps1 的同名函式一字不差（新增技術棧兩邊一起加）。

try {
    # D-2（2026-10-18）：必須與 verify-gate.ps1 一樣用 UTF-8 讀 stdin。沒設的話，指令或路徑含中文時
    #      會被以 console codepage 讀成亂碼、吃掉引號 → JSON 解析失敗 → 標記沒寫（錯誤 log 實測抓到）
    try { [Console]::InputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }
    try { [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }   # 否則 git rev-parse 回傳的中文路徑變亂碼
    $raw = [Console]::In.ReadToEnd()
    if ($raw) { $raw = $raw.TrimStart([char]0xFEFF) }   # 去掉 BOM（同 verify-gate.ps1 的 D-1）
    if (-not $raw) { exit 0 }

    $data = $raw | ConvertFrom-Json
    $cmd = $data.tool_input.command
    if (-not $cmd) { exit 0 }

    # 背景執行：工具一啟動就回報成功，測試其實還沒跑完 → 不算
    if ($data.tool_input.run_in_background) { exit 0 }

    # 去掉引號內文字再比對（git commit -m "pytest passed"、echo "run jest" 不能算驗證）
    $cmdNoQuotes = [regex]::Replace($cmd, '"[^"]*"|''[^'']*''', '')

    # H2（2026-11-14）：每段（&& 分隔）要「以驗證工具開頭」才算；裝套件、看版本、--if-present 不算
    function Test-Verify([string]$s) {
        $s = $s.Trim()
        if ($s -match '(^|\s)(install|add|uninstall|i|ci)(\s|$)|--version|--help|--if-present') { return $false }
        $s = $s -replace '^(npx\s+|python3?\s+-m\s+|py\s+-m\s+|uv\s+run\s+)', ''
        return $s -match ('^((npm|yarn|pnpm)\s+(run\s+)?(build|test|lint|typecheck|check)\b|tsc\b|playwright\s+test\b' +
                          '|vitest\b|jest\b|mocha\b|node\s+--test\b|pytest\b|py_compile\b|mypy\b|ruff\b|flake8\b' +
                          '|cargo\s+(build|test|check|clippy)\b|go\s+(build|test|vet)\b|dotnet\s+(build|test)\b' +
                          '|mvn\s+(compile|test)\b|gradle\s+(build|test)\b)')
    }

    # 用 ; | 串接或多行時，整串成功不代表驗證成功（npm test | tail 失敗也算成功）→ 不寫標記
    if ($cmdNoQuotes -match '[;|\r\n]') { exit 0 }

    if (@($cmdNoQuotes -split '&&' | Where-Object { Test-Verify $_ }).Count -gt 0) {
        # B-2（v3.13）：切到 repo 根，否則 cwd 在子目錄時標記會寫錯位置
        $root = (git rev-parse --show-toplevel 2>$null)
        if ($LASTEXITCODE -eq 0 -and $root) { Set-Location -LiteralPath $root }

        # E-1（改成外掛後）：只在 ai-os 專案寫標記，不在別的專案留下檔案
        $dir = '_管理'
        if (-not (Test-Path -LiteralPath '_管理/常駐/此次任務.md')) {
            $pd = $env:CLAUDE_PROJECT_DIR   # E-4：ai-os 專案是大倉庫的子資料夾
            if (-not ($pd -and (Test-Path -LiteralPath (Join-Path $pd '_管理/常駐/此次任務.md')))) { exit 0 }
            Set-Location -LiteralPath $pd
        }
        if (Test-Path -LiteralPath '_開發檔案/scripts/hooks/verify-gate.ps1') { exit 0 }   # E-2：舊範本專案自帶閘門，不插手
        Set-Content -Path (Join-Path $dir '.verify-marker') `
                    -Value (Get-Date -Format 'o') -Encoding utf8
    }
} catch {
    # 不干擾正常流程，但把錯誤寫進暫存資料夾的 log
    try { Add-Content -Path (Join-Path $env:TEMP 'ai-os-gate-error.log') -Value "$(Get-Date -Format o) mark-verify: $_" -Encoding utf8 } catch { }
}

exit 0
