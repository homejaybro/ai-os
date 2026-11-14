# 閘門自我測試：在暫存 git repo 裡實跑 verify-gate.ps1，確認各情境行為正確。
# 用法：在外掛的 scripts 資料夾執行 powershell -NoProfile -ExecutionPolicy Bypass -File gate-test.ps1
# 全過 exit 0；有任何一項不符 exit 1。⚠️ 須存 UTF-8 with BOM。

[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$gate = Join-Path $PSScriptRoot 'verify-gate.ps1'
$mark = Join-Path $PSScriptRoot 'mark-verify.ps1'
$tmp  = Join-Path ([IO.Path]::GetTempPath()) ('gate-test-' + [guid]::NewGuid())
New-Item -ItemType Directory -Path $tmp | Out-Null
Push-Location $tmp
$fail = 0

function Run-Gate([string]$cmd) {
    $json = @{ tool_name = 'Bash'; tool_input = @{ command = $cmd } } | ConvertTo-Json -Compress
    ($json | powershell -NoProfile -ExecutionPolicy Bypass -File $gate) -join ''
}
function Run-Mark([string]$cmd, [bool]$bg = $false) {
    $json = @{ tool_name = 'Bash'; tool_input = @{ command = $cmd; run_in_background = $bg } } | ConvertTo-Json -Compress
    $json | powershell -NoProfile -ExecutionPolicy Bypass -File $mark | Out-Null
}
function CheckMark([string]$name, [string]$cmd, [bool]$expectMark, [bool]$bg = $false) {
    Remove-Item '_管理/.verify-marker' -ErrorAction SilentlyContinue
    Run-Mark $cmd $bg
    $marked = Test-Path '_管理/.verify-marker'
    if ($marked -eq $expectMark) { Write-Host "PASS  $name" }
    else { Write-Host "FAIL  $name（預期 $(if ($expectMark) {'寫標記'} else {'不寫標記'})）"; $script:fail++ }
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
    Check '4c 用 ; 串接 build 與 commit（build 失敗也會 commit）→ 擋下' 'npm run build; git commit -m x' $true
    Check '4d 驗證接管線再 && commit → 擋下' 'npm test | tail -5 && git commit -m x' $true
    Check '4b 同串先 node --test 再 commit → 放行'  'node --test && git commit -m x'           $false
    Check '5 非 commit 指令 → 放行'                'git status'                               $false
    Check '7 跑 gate-test 不能替專案程式碼背書 → 擋下' 'powershell -File gate-test.ps1 && git commit -m x' $true
    Check '11 同串裝測試套件再 commit 不算驗證 → 擋下' 'npm install -D jest && git commit -m x' $true
    Check '12 同串 --if-present 再 commit 不算驗證 → 擋下' 'npm test --if-present && git commit -m x' $true
    Check '13 git commit -am 也要驗證 → 擋下'        'git commit -am x'                         $true

    # 標記：真的跑驗證才寫
    CheckMark 'M1 npm test → 寫標記'                 'npm test'                                 $true
    CheckMark 'M2 cd 後 npx playwright test → 寫標記' 'cd web && npx playwright test'           $true
    CheckMark 'M3 裝測試套件 → 不寫'                 'npm install -D vitest'                    $false
    CheckMark 'M4 看版本 → 不寫'                     'pytest --version'                         $false
    CheckMark 'M5 提到工具名的其他指令 → 不寫'       'cat jest.config.js'                       $false
    CheckMark 'M6 驗證接管線 → 不寫'                 'npm test | tail -5'                       $false
    CheckMark 'M7 背景執行 → 不寫'                   'npm test'                                 $false $true
    CheckMark 'M8 commit 訊息提到 pytest → 不寫'     'git commit -m "pytest passed"'            $false
    CheckMark 'M9 環境變數前綴 → 寫標記'             'CI=1 npm test'                            $true
    CheckMark 'M10 npm --prefix → 寫標記'            'npm --prefix web test'                    $true
    CheckMark 'M11 pnpm exec tsc → 寫標記'           'pnpm exec tsc --noEmit'                   $true
    CheckMark 'M12 虛擬環境 python -m pytest → 寫標記' '.venv/Scripts/python -m pytest'         $true
    CheckMark 'M13 RTK 前綴 → 寫標記'                'rtk npm run build'                        $true
    CheckMark 'M14 npm test 參數剛好是 add → 寫標記' 'npm test -- add'                          $true
    CheckMark 'M15 只列出測試 → 不寫'                'npx playwright test --list'               $false
    CheckMark 'M16 tsc -v → 不寫'                    'npx tsc -v'                               $false
    CheckMark 'M17 結尾 & 背景 → 不寫'               'npm test &'                               $false

    # 主線：驗證過、標記比程式碼新 → 放行
    Start-Sleep -Milliseconds 1100
    Run-Mark 'npm run build'
    Check '14 驗證過後 commit → 放行'                'git commit -m x'                          $false
    Start-Sleep -Milliseconds 1100
    'y' | Set-Content a.js; git add a.js
    Check '15 驗證後又改程式碼 → 擋下'               'git commit -m x'                          $true

    git rm -q --cached a.js
    Check '9 同串 git add 未驗證程式碼再 commit → 擋下' 'git add a.js; git commit -m x'           $true

    'doc' | Set-Content n.md
    git add n.md
    Check '6 只有文件的 commit → 放行'              'git commit -m docs'                       $false
    New-Item -ItemType Directory -Force -Path '_產出/草圖' | Out-Null
    '<html></html>' | Set-Content '_產出/草圖/a.html'
    git add '_產出/草圖/a.html'
    Check '16 只有 _產出 的成品 → 放行'             'git commit -m sketch'                     $false
    git rm -q --cached '_產出/草圖/a.html'

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
