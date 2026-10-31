# Mad Medicine 自动同步（PowerShell 版，无需 Node.js）
# 监听网页文件改动 → 停止改动 5 秒后自动 git 提交并推送 → GitHub Pages 自动重新发布
$ErrorActionPreference = 'Continue'
$ROOT = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ROOT

# 只监听需要发布的文件，临时文件不会被自动提交
$WATCH_FILES = @(
  'index.html',
  'design-evolution.html',
  'system-analysis.html',
  'interaction-life-design.html',
  'theatre-interaction-analysis.html',
  'MAD-MEDICINE_设计演进对比说明.html',
  'gameplay-demo.mp4',
  'reference-figures.mp4',
  'README.md'
)
$WATCH_DIRS = @('assets', 'exports')
$DEBOUNCE_SEC = 5

function Stamp { Get-Date -Format 'HH:mm:ss' }

function Is-Watched($rel) {
  $n = ($rel -replace '/', '\')
  foreach ($d in $WATCH_DIRS) { if ($n -like "$d\*" -or $n -eq $d) { return $true } }
  foreach ($f in $WATCH_FILES) { if ($n -ieq $f) { return $true } }
  return $false
}

function Sync {
  try {
    $targets = $WATCH_FILES + $WATCH_DIRS
    & git add -- @targets 2>&1 | Out-Null
    $pending = & git status --porcelain -- @targets
    if (-not $pending) { return }
    $msg = 'auto: 自动同步 ' + (Get-Date -Format 'yyyy/M/d HH:mm:ss')
    & git commit -m $msg 2>&1 | Out-Null
    & git push origin main 2>&1 | Out-Null
    if ($LASTEXITCODE -ne 0) {
      # 远端若有他人提交，先 rebase 再推一次
      & git pull --rebase origin main 2>&1 | Out-Null
      & git push origin main 2>&1 | Out-Null
    }
    if ($LASTEXITCODE -eq 0) {
      Write-Host ("[{0}] 已发布到 GitHub Pages（网页端 / 手机端约 1 分钟后生效）" -f (Stamp))
    } else {
      Write-Host ("[{0}] 推送失败，请检查网络或 GitHub 登录凭据" -f (Stamp))
    }
  } catch {
    Write-Host ("[{0}] 同步失败：{1}" -f (Stamp), $_.Exception.Message)
  }
}

$watcher = New-Object System.IO.FileSystemWatcher
$watcher.Path = $ROOT
$watcher.IncludeSubdirectories = $true
$watcher.NotifyFilter = [System.IO.NotifyFilters]::FileName -bor [System.IO.NotifyFilters]::LastWrite -bor [System.IO.NotifyFilters]::Size
$watcher.EnableRaisingEvents = $true

Write-Host '正在监听以下文件，保存即自动发布：'
foreach ($f in ($WATCH_FILES + $WATCH_DIRS)) {
  if (Test-Path (Join-Path $ROOT $f)) { Write-Host "  - $f" }
}
Write-Host ''
Write-Host '保持本窗口开启即可；按 Ctrl+C 停止。'
Write-Host ''

Sync  # 启动时若还有未提交的改动，先同步一次

while ($true) {
  $r = $watcher.WaitForChanged([System.IO.WatcherChangeTypes]::All, 1000)
  if ($r.TimedOut) { continue }
  if (-not (Is-Watched $r.Name)) { continue }
  Write-Host ("[{0}] 检测到改动（{1}），停止改动 {2} 秒后自动提交…" -f (Stamp), $r.Name, $DEBOUNCE_SEC)
  # 防抖：等到安静期结束（期间的新改动会被一并吞掉）
  Start-Sleep -Seconds $DEBOUNCE_SEC
  while ($true) {
    $r2 = $watcher.WaitForChanged([System.IO.WatcherChangeTypes]::All, 500)
    if ($r2.TimedOut) { break }
  }
  Sync
}
