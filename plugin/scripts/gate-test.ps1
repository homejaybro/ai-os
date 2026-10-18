# 閘門自我測試：在暫存 git repo 裡實跑 verify-gate.ps1，確認各情境行為正確。
# 用法：powershell -NoProfile -ExecutionPolicy Bypass -File "$HOME/ai-os/plugin/scripts/gate-test.ps1"
# 全過 exit 0；有任何一項不符 exit 1。⚠️ 須存 UTF-8 with BOM。

[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$gate = Join-Path $PSScriptRoot 'verify-gate.ps1'
$tmp  = Join-Path ([IO.Path]::GetTempPath()) ('gate-test-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tmp | Out-Null
Push-Location $tmp
$fail = 0

function Run-Gate([string]$cmd) {
    $json = @{ tool_name = 'Bash'; tool_input = @{ command = $cmd } } | ConvertTo-Json -Compress
    ($json | powershell -NoProfile -ExecutionPolicy Bypass -File $gate) -join ''
}
function Check([string]$name, [string]$cmd, [bool]$expectDeny) {
    $out = Run-Gate $cmd
    $denied = $out -match '"deny"'
    if ($denied -eq $expectDeny) { Write-Host "PASS  $name" }
    else { Write-Host "FAIL  $name（預期 $(if ($expectDeny) {'擋下'} else {'放行'})）"; $script:fail++; Write-Host "      診斷：repo=$(git rev-parse --show-toplevel 2>&1) 暫存=$((git diff --cached --name-only 2>&1) -join ',') 輸出長度=$($out.Length)" }
}

try {
    git init -q
    git config user.email t@t.t; git config user.name t
    'x' | Set-Content a.js
    git add a.js

    # 還不是 ai-os 專案（沒有 _管理/常駐/此次任務.md）
    Check '0 不是 ai-os 專案 → 放行'                 'git commit -m x'                          $false

    New-Item -ItemType Directory -Force -Path '_管理/常駐' | Out-Null
    'x' | Set-Content '_管理/常駐/此次任務.md'

    Check '1 未驗證的程式碼 commit → 擋下'          'git commit -m x'                          $true
    Check '2 帶 skip-verify 也不能繞過 → 擋下'      'git commit -m "x [skip-verify]"'          $true
    Check '3 git push → 放行'                       'git push origin main'                     $false
    Check '4 同指令串先 build 再 commit → 放行'     'npm run build && git commit -m x'         $false
    Check '5b commit 訊息寫 playwright test 不算驗證 → 擋下' 'git commit -m "新增 playwright test 設定"' $true
    Check '5c commit 訊息含 majestic 不算驗證 → 擋下' 'git commit -m "majestic update"' $true
    Check '5 非 commit 指令 → 放行'                 'git status'                               $false
    Check '7 跑 gate-test 不能替專案程式碼背書 → 擋下' 'powershell -File gate-test.ps1 && git commit -m x' $true

    git rm -q --cached a.js
    Check '9 同串 git add 未驗證程式碼再 commit → 擋下' 'git add a.js; git commit -m x'           $true

    'doc' | Set-Content n.md
    git add n.md
    Check '6 只有文件的 commit → 放行'              'git commit -m docs'                       $false

    # 舊範本複製開的專案自帶閘門 → 外掛不插手（交給專案自己的閘門）
    git add a.js
    New-Item -ItemType Directory -Force -Path '_開發檔案/scripts/hooks' | Out-Null
    'x' | Set-Content '_開發檔案/scripts/hooks/verify-gate.ps1'
    Check '10 舊範本專案（自帶閘門）→ 外掛放行'     'git commit -m x'                          $false
}
finally {
    Pop-Location
    Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}

if ($fail -gt 0) { Write-Host "共 $fail 項失敗"; exit 1 }
Write-Host '全部通過'
exit 0
