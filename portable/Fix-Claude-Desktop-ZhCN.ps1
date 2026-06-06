# Claude Desktop zh-CN natural localization patcher
# Put this script next to:
#   - zh-CN.json
#   - frontend-zh-CN.json
# Usage:
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\Fix-Claude-Desktop-ZhCN.ps1
#   powershell -NoProfile -ExecutionPolicy Bypass -File .\Fix-Claude-Desktop-ZhCN.ps1 -ClaudePath "C:\path\to\Claude\app\resources"
param(
  [string]$ClaudePath,
  [switch]$ForceBundledLanguage
)
$ErrorActionPreference = 'Stop'

function Write-Step($Text) { Write-Host "`n==> $Text" -ForegroundColor Cyan }
function New-Utf8NoBomEncoding { [Text.UTF8Encoding]::new($false) }
function Backup-File($Path, $BackupDir) {
  if (Test-Path -LiteralPath $Path) {
    Copy-Item -LiteralPath $Path -Destination (Join-Path $BackupDir ([IO.Path]::GetFileName($Path))) -Force
  }
}
function Copy-BundledFileIfNeeded([string]$BundledPath, [string]$TargetPath, [switch]$Force) {
  if (!(Test-Path -LiteralPath $BundledPath)) { Write-Warning "Bundled language file not found: $BundledPath"; return }
  if ($Force -or !(Test-Path -LiteralPath $TargetPath)) {
    $dir = Split-Path -Parent $TargetPath
    if (!(Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    Copy-Item -LiteralPath $BundledPath -Destination $TargetPath -Force
    Write-Host "Deployed bundled language file: $TargetPath"
  }
}
function Update-JsonStrings([string]$Path, [hashtable]$Map) {
  if (!(Test-Path -LiteralPath $Path)) { Write-Warning "Not found: $Path"; return }
  $raw = [IO.File]::ReadAllText($Path, [Text.Encoding]::UTF8)
  $json = ConvertFrom-Json -InputObject $raw
  foreach ($key in $Map.Keys) {
    if ($json.PSObject.Properties.Name -contains $key) { $json.$key = $Map[$key] }
    else { Write-Warning "Missing i18n key $key in $Path" }
  }
  $out = $json | ConvertTo-Json -Depth 100
  [IO.File]::WriteAllText($Path, $out, (New-Utf8NoBomEncoding))
}
function Get-ResourceCandidate([string]$Path) {
  if ([string]::IsNullOrWhiteSpace($Path)) { return @() }
  $resolved = $Path.Trim('"')
  if (Test-Path -LiteralPath $resolved -PathType Leaf) { $resolved = Split-Path -Parent $resolved }
  @(
    $resolved,
    (Join-Path $resolved 'resources'),
    (Join-Path $resolved 'app\resources'),
    (Join-Path $resolved 'Claude\resources'),
    (Join-Path $resolved 'Claude\app\resources')
  ) | Where-Object { $_ -and (Test-Path -LiteralPath (Join-Path $_ 'ion-dist')) }
}
function Find-ClaudeResources([string]$ExplicitPath) {
  $candidates = @()
  $candidates += Get-ResourceCandidate $ExplicitPath

  $packageNames = @()
  $packageRegistry = 'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\Repository\Packages'
  if (Test-Path -LiteralPath $packageRegistry) {
    $packageNames += Get-ChildItem -LiteralPath $packageRegistry -ErrorAction SilentlyContinue |
      Where-Object { $_.PSChildName -like 'Claude_*__pzs8sxrjxfjjc' -or $_.PSChildName -like 'Claude_*_x64__pzs8sxrjxfjjc' } |
      Select-Object -ExpandProperty PSChildName
  }
  foreach ($name in ($packageNames | Sort-Object -Unique)) {
    $candidates += Get-ResourceCandidate (Join-Path 'C:\Program Files\WindowsApps' $name)
  }

  $commonRoots = @(
    (Join-Path $env:LOCALAPPDATA 'Programs\Claude'),
    (Join-Path $env:LOCALAPPDATA 'Claude'),
    (Join-Path $env:ProgramFiles 'Claude'),
    (Join-Path ${env:ProgramFiles(x86)} 'Claude')
  ) | Where-Object { $_ }
  foreach ($root in $commonRoots) {
    $candidates += Get-ResourceCandidate $root
    if (Test-Path -LiteralPath $root) {
      Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like 'app-*' -or $_.Name -like 'Claude*' } |
        ForEach-Object { $candidates += Get-ResourceCandidate $_.FullName }
    }
  }

  $valid = $candidates | Where-Object {
    $_ -and
    (Test-Path -LiteralPath (Join-Path $_ 'ion-dist\assets')) -and
    (Test-Path -LiteralPath (Join-Path $_ 'ion-dist'))
  } | Sort-Object -Unique
  return $valid | Select-Object -First 1
}
function Patch-TitleGeneration([string]$AssetsDir) {
  $patched = $false
  foreach ($file in (Get-ChildItem -LiteralPath $AssetsDir -Filter '*.js' -ErrorAction SilentlyContinue)) {
    $text = [IO.File]::ReadAllText($file.FullName, [Text.Encoding]::UTF8)
    $old = 'first_session_message:(e??t??"").trim().slice(0,2e3),title_style:n'
    $new = 'first_session_message:("请用简体中文为这次会话生成一个简短、自然的中文标题，不要使用英文，不要加引号。\n\n"+(e??t??"").trim()).slice(0,2e3),title_style:n'
    if ($text.Contains($old)) {
      [IO.File]::WriteAllText($file.FullName, $text.Replace($old,$new), (New-Utf8NoBomEncoding))
      Write-Host "Patched Chinese auto-title generation: $($file.Name)"
      $patched = $true
      break
    }
    if ($text.Contains('请用简体中文为这次会话生成一个简短、自然的中文标题')) { $patched = $true }
  }
  if (!$patched) { Write-Warning 'Could not patch title generation automatically; chunks may have changed.' }
}
function Patch-FallbackTitles([string]$AssetsDir) {
  $changed = $false
  foreach ($file in (Get-ChildItem -LiteralPath $AssetsDir -Filter '*.js' -ErrorAction SilentlyContinue)) {
    $text = [IO.File]::ReadAllText($file.FullName, [Text.Encoding]::UTF8)
    $next = $text.Replace('t.title||t.worktreeName||"General coding session"','t.title||t.worktreeName||"代码开发会话"')
    $next = $next.Replace('"General coding session"','"代码开发会话"')
    if ($next -ne $text) {
      [IO.File]::WriteAllText($file.FullName, $next, (New-Utf8NoBomEncoding))
      Write-Host "Patched fallback session title: $($file.Name)"
      $changed = $true
    }
  }
  if (!$changed) { Write-Host 'Fallback session title already patched or not present.' }
}
function Patch-StatsBookList([string]$AssetsDir) {
  $bookList = 'const sw=[{name:"茶馆",tokens:48e3},{name:"朝花夕拾",tokens:15e4},{name:"活着",tokens:18e4},{name:"球状闪电",tokens:27e4},{name:"围城",tokens:375e3},{name:"儒林外史",tokens:54e4},{name:"白鹿原",tokens:75e4},{name:"红楼梦",tokens:1095e3},{name:"三体",tokens:135e4},{name:"天龙八部",tokens:225e4}]'
  $changed = $false
  foreach ($file in (Get-ChildItem -LiteralPath $AssetsDir -Filter '*.js' -ErrorAction SilentlyContinue)) {
    $text = [IO.File]::ReadAllText($file.FullName, [Text.Encoding]::UTF8)
    if (!$text.Contains('totalTokens') -or !$text.Contains('FunFactoid')) { continue }
    $next = [Regex]::Replace($text, 'const sw=\[\{name:"[^"]+",tokens:[^\]]+\}\]', $bookList, 1)
    if ($next -ne $text) {
      [IO.File]::WriteAllText($file.FullName, $next, (New-Utf8NoBomEncoding))
      Write-Host "Patched stats book examples: $($file.Name)"
      $changed = $true
    }
  }
  if (!$changed) { Write-Host 'Stats book examples already patched or not present.' }
}
function Clear-ClaudeCache() {
  Get-Process Claude -ErrorAction SilentlyContinue | Stop-Process -Force
  Start-Sleep -Milliseconds 500
  $cacheRoots = @(
    (Join-Path $env:LOCALAPPDATA 'Packages\Claude_pzs8sxrjxfjjc\LocalCache\Roaming\Claude'),
    (Join-Path $env:APPDATA 'Claude')
  ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }
  foreach ($root in $cacheRoots) {
    $cacheDirs = @('Cache','Code Cache','GPUCache','DawnGraphiteCache','DawnWebGPUCache','Shared Dictionary\cache') | ForEach-Object { Join-Path $root $_ }
    foreach ($dir in $cacheDirs) {
      if (Test-Path -LiteralPath $dir) {
        Get-ChildItem -LiteralPath $dir -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Cleared: $dir"
      }
    }
  }
}

$RootZhMap = @{
  '9GRz7bC+rr'='配置第三方模型服务…'
}
$FrontendZhMap = @{
  '+Yw0QZgv1B'='模型服务设置'
  'on79ZcGd72'='配置第三方模型服务'
  '1qPkTh9fMa'='可随时在模型服务设置中添加连接器服务器、设置模型白名单或切换服务提供商。'
  'Amxb69AvfR'='选择 Claude Desktop 将模型请求发送到哪里。'
  'QQpUrtO7kr'='模型服务提供商'
  '6cmRKZgiFv'='模型网关端点的完整 URL。'
  '6T78KTXhBM'='自定义模型请求头'
  '0hPFsTuQ1X'='随每次模型请求发送给当前服务提供商的额外 HTTP 请求头。可用于租户路由、组织 ID、Bedrock Guardrails 等场景。'
  'aTTY7rU6Bh'='每个统计周期最多词元数'
  'FSyyISlTnS'='词元统计周期'
  '3iLLaW8pc5'='用于计算词元上限的滚动统计周期，最长 720 小时（30 天）。'
  'ozzKmITBMv'='按用户在本机统计的提醒阈值，统计范围为下方设置的时长。它不是服务端强制执行的配额。'
  '9mq4/xSGLy'='已达到词元上限（{windowHours} 小时内已用 {used, number} / {cap, number}）。请联系你的 IT 管理员。'
  'XyN2qD283R'='{tokens} 个词元'
  'DaSoh5uRAp'='<v>{n}</v> 个词元'
  'P6EE/aQ7SS'='词元'
  'V45V2dwaf/'='词元总量'
  '6dsLdmM4dK'='已压缩对话 · 节省 {tokens} 个词元'
  'lSTq/4s8Vx'='已压缩对话 · 原为 {tokens} 个词元'
  'MJeNpHWSBI'='`/usage` 会在当前会话中显示词元用量'
  'Qv5Jt+ZxYX'='按模型统计每日词元'
  'Stq39HkM0l'='你的词元用量约等于《{book}》的 {times} 倍。'
  'm4VXIz3JrC'='你的词元用量大约相当于一本《{book}》。'
  'M1xaCQwNr4'='连接模型服务提供商（{host}）的时间比预期更长。仍在尝试…'
  'Qe5TZgb1+q'='连接模型服务提供商需要一些时间…'
  'jDH/vSi1ah'='无法从 Claude 的工作区访问你的模型服务提供商（{host}）。'
  'XtXm3euW3d'='使用情况分析可帮助我们优先改进第三方模型服务。诊断报告上传也会被阻止。两者都不包含消息内容。'
  'ek/rdG0G9V'='崩溃和错误报告用于诊断模型服务设置中的具体故障。没有这些报告，支持处理会更慢。'
  'tgkg69DKCl'='你正在通过组织自己的模型服务提供商（{providerDisplayName}）运行 Claude。你的对话会发送给该提供商，而不是 Anthropic，并受你的组织与该提供商签订的协议约束。'
  'TDFJxA6e85'='用量统计'
  'tygEJXQ5Kc'='时间范围'
  '9uOFF3L8kp'='概览'
  'blWvagsLt7'='模型'
  'zQvVDJ+j59'='全部'
  'nZ1VHGrgR+'='30 天'
  '26tyS2WSDe'='7 天'
  'Z3EDd9nO/N'='会话数'
  'hMzcSqn09p'='消息数'
  'BqDdI890tk'='活跃天数'
  'Mn8BAEIrHk'='当前连续活跃'
  'C2KvkQvJR0'='最长连续活跃'
  'EfZAqeQJKz'='{n} 天'
  'oaW03ZISnE'='最活跃时段'
  'HcKBhf6Q5g'='常用模型'
  'wfhrnIhl3F'='每日活跃热力图'
  '6ISjoQ9Mkh'='输入'
  'kSMqM4htfo'='输出'
  'xNApr3Zf57'='缓存读'
  'tDirXwjVKd'='缓存写'
  'LSVniN62Ib'='本次会话用量'
  'MJ2jZQxQnT'='总计'
  '+EiT5beQUU'='暂无用量数据。套餐用量会在限制信息加载后显示，会话用量会在 Claude 首次回复后显示。'
  'z2/BwrFUvx'='该时间范围内没有模型用量'
}

Write-Step 'Locating Claude Desktop resources'
$resources = Find-ClaudeResources $ClaudePath
if (!$resources) { throw 'Claude Desktop resources folder not found. Re-run with -ClaudePath "path-to-Claude-or-resources".' }
$assets = Join-Path $resources 'ion-dist\assets\v1'
$frontendZh = Join-Path $resources 'ion-dist\i18n\zh-CN.json'
$rootZh = Join-Path $resources 'zh-CN.json'
Write-Host "Resources: $resources"

Write-Step 'Creating backup'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$backup = Join-Path $env:TEMP "claude-zh-cn-backup-$stamp"
New-Item -ItemType Directory -Force -Path $backup | Out-Null
Backup-File $frontendZh $backup
Backup-File $rootZh $backup
Get-ChildItem -LiteralPath $assets -Filter '*.js' -ErrorAction SilentlyContinue | Where-Object {
  $content = [IO.File]::ReadAllText($_.FullName, [Text.Encoding]::UTF8)
  $content.Contains('General coding session') -or $content.Contains('generate_title_and_branch') -or $content.Contains('first_session_message:')
} | ForEach-Object { Backup-File $_.FullName $backup }
Write-Host "Backup: $backup"

Write-Step 'Ensuring bundled zh-CN language files'
$resourceRoot = Join-Path (Split-Path -Parent $PSScriptRoot) 'resources'
$bundleRoot = Join-Path $PSScriptRoot 'zh-CN.json'
$bundleFrontend = Join-Path $PSScriptRoot 'frontend-zh-CN.json'
if (!(Test-Path -LiteralPath $bundleRoot)) { $bundleRoot = Join-Path $resourceRoot 'zh-CN.json' }
if (!(Test-Path -LiteralPath $bundleFrontend)) { $bundleFrontend = Join-Path $resourceRoot 'frontend-zh-CN.json' }
Copy-BundledFileIfNeeded $bundleRoot $rootZh -Force:$ForceBundledLanguage
Copy-BundledFileIfNeeded $bundleFrontend $frontendZh -Force:$ForceBundledLanguage

Write-Step 'Patching zh-CN language files'
Update-JsonStrings $rootZh $RootZhMap
Update-JsonStrings $frontendZh $FrontendZhMap

Write-Step 'Patching frontend JS fallbacks'
Patch-TitleGeneration $assets
Patch-FallbackTitles $assets
Patch-StatsBookList $assets

Write-Step 'Clearing Claude cache'
Clear-ClaudeCache

Write-Step 'Done'
Write-Host 'Please reopen Claude Desktop.' -ForegroundColor Green
Write-Host "Backup saved at: $backup"