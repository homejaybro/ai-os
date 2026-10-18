# PostToolUse hook：偵測到「驗證類指令」執行過，就寫下標記檔
#
# 搭配 verify-gate.ps1 實現「原則四（Evidence over claims）」的技術層閘門。
# 本腳本只記錄「跑過了」，不解析輸出——解析各技術棧輸出
# 脆弱且會誤擋。PostToolUse 只在指令成功（exit 0）時觸發，所以失敗的驗證本來就不會留下標記（2026-10-18 實測）。
#
# 失敗行為：任何錯誤都靜默 exit 0（PostToolUse 本身無法阻擋，且不應干擾流程）。
#
# ── v3.14 補洞（2026-07-30，須與 verify-gate.ps1 同步維護）──────
# 這支腳本與 verify-gate.ps1 判斷「是否為 git 指令」的邏輯必須保持一致：
# 任何在 git 前面加前綴的 wrapper（如 `rtk proxy git commit`）都會讓 git
# 不在指令開頭或分隔符之後 → 若沿用舊的位置錨點 regex，這條排除判斷會
# 失效，導致 commit message 裡的驗證類字樣（如「pytest passed」）被
# 誤判成真的跑過驗證 → 偽造出通行證（B-4 的原始漏洞以新繞過手法重演）。
# → 拿掉位置錨點，只要求 git 這個詞出現在指令任何位置。

try {
    # D-2（2026-10-18）：必須與 verify-gate.ps1 一樣用 UTF-8 讀 stdin。沒設的話，指令或路徑含中文時
    #      會被以 console codepage 讀成亂碼、吃掉引號 → JSON 解析失敗 → 標記沒寫（錯誤 log 實測抓到）
    try { [Console]::InputEncoding = New-Object System.Text.UTF8Encoding($false) } catch { }
    $raw = [Console]::In.ReadToEnd()
    if ($raw) { $raw = $raw.TrimStart([char]0xFEFF) }   # 去掉 BOM（同 verify-gate.ps1 的 D-1）
    if (-not $raw) { exit 0 }

    $data = $raw | ConvertFrom-Json
    $cmd = $data.tool_input.command
    if (-not $cmd) { exit 0 }

    # B-4（v3.13）＋ C-1（v3.14）：commit message 提到 pytest／build／test 會偽造出通行證
    #   例：git commit -m "chore: add pytest config" → 標記被寫下 → 下一次 commit 直接放行
    #   例：rtk proxy git commit -m "pytest passed" → 若用位置錨點 regex 會漏抓（見上方補洞說明）
    #   git 指令一律不視為驗證動作，不管前面加了什麼包裝指令
    if ($cmd -match '\bgit\b') { exit 0 }

    # 去掉引號內文字再比對（echo "run jest" 這類不能算驗證）
    $cmdNoQuotes = [regex]::Replace($cmd, '"[^"]*"|''[^'']*''', '')

    # 驗證類指令（跨技術棧；新增技術棧時在此追加）
    $verifyPattern = '(npm|yarn|pnpm)\s+(run\s+)?(build|test|lint|typecheck|check)' +
                     '|(^|\s|&&\s*)tsc(\s|$)' +
                     '|playwright\s+test|\bvitest\b|\bjest\b|\bmocha\b' +
                     '|\bpytest\b|\bpy_compile\b|\bmypy\b|\bruff\b|\bflake8\b' +
                     '|cargo\s+(build|test|check|clippy)' +
                     '|go\s+(build|test|vet)' +
                     '|dotnet\s+(build|test)' +
                     '|mvn\s+(compile|test)|gradle\s+(build|test)'

    if ($cmdNoQuotes -match $verifyPattern) {
        # B-2（v3.13）：切到 repo 根，否則 cwd 在子目錄時標記會寫錯位置
        $root = (git rev-parse --show-toplevel 2>$null)
        if ($LASTEXITCODE -eq 0 -and $root) { Set-Location -LiteralPath $root }

        # E-1（改成外掛後）：只在 ai-os 專案寫標記，不在別的專案留下檔案
        $dir = '_管理'
        if (-not (Test-Path -LiteralPath '_管理/常駐/此次任務.md')) { exit 0 }
        Set-Content -Path (Join-Path $dir '.verify-marker') `
                    -Value (Get-Date -Format 'o') -Encoding utf8
    }
} catch {
    # 不干擾正常流程，但把錯誤寫進暫存資料夾的 log
    try { Add-Content -Path (Join-Path $env:TEMP 'ai-os-gate-error.log') -Value "$(Get-Date -Format o) mark-verify: $_" -Encoding utf8 } catch { }
}

exit 0
