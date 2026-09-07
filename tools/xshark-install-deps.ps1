#Requires -Version 5.1
<#
.SYNOPSIS
  XShark 依赖检测与安装：VC++ 运行库、Npcap。
.DESCRIPTION
  - 已安装则跳过；缺失则自动安装（需管理员权限）。
  - VC++：使用包内 vc_redist.x64.exe（/install /quiet /norestart）。
  - Npcap：不随包分发（授权限制），缺失时从官方 GitHub Release 下载安装包再执行。
#>
param(
  [switch]$Silent,
  [switch]$SkipNpcap,
  [switch]$SkipVcRedist,
  [switch]$LaunchAfter
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $Root

function Write-Info([string]$msg) {
  if (-not $Silent) { Write-Host $msg }
}

function Test-IsAdmin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p = New-Object Security.Principal.WindowsPrincipal($id)
  return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Ensure-Admin {
  if (Test-IsAdmin) { return }
  Write-Info '需要管理员权限以安装驱动/运行库，正在请求提升…'
  $args = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath)
  if ($Silent) { $args += '-Silent' }
  if ($SkipNpcap) { $args += '-SkipNpcap' }
  if ($SkipVcRedist) { $args += '-SkipVcRedist' }
  if ($LaunchAfter) { $args += '-LaunchAfter' }
  Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $args -Wait
  exit $LASTEXITCODE
}

function Test-VcRedistInstalled {
  # VS 2015-2022 x64 runtime — same family as modern Wireshark builds
  $keys = @(
    'HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\x64'
  )
  foreach ($k in $keys) {
    if (Test-Path $k) {
      $installed = (Get-ItemProperty $k -ErrorAction SilentlyContinue).Installed
      if ($installed -eq 1) { return $true }
    }
  }
  # Fallback: core DLL beside System32
  return (Test-Path "$env:SystemRoot\System32\vcruntime140.dll") -and
         (Test-Path "$env:SystemRoot\System32\msvcp140.dll")
}

function Install-VcRedist {
  $exe = Join-Path $Root 'vc_redist.x64.exe'
  if (-not (Test-Path $exe)) {
    Write-Info "未找到包内 vc_redist.x64.exe，跳过 VC 运行库安装。"
    return $false
  }
  if (Test-VcRedistInstalled) {
    Write-Info 'VC++ 运行库已安装，跳过。'
    return $true
  }
  Write-Info '正在安装 VC++ 运行库（vc_redist.x64.exe）…'
  $p = Start-Process -FilePath $exe -ArgumentList '/install','/quiet','/norestart' -Wait -PassThru
  Write-Info ("vc_redist 退出码: {0}" -f $p.ExitCode)
  # 0 = success, 1638 = newer already installed, 3010 = reboot required
  if ($p.ExitCode -in 0, 1638, 3010) { return $true }
  return $false
}

function Test-NpcapInstalled {
  $reg = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\NpcapInst'
  if (Test-Path $reg) { return $true }
  if (Test-Path "$env:SystemRoot\System32\Npcap\wpcap.dll") { return $true }
  if (Get-Service -Name 'npcap' -ErrorAction SilentlyContinue) { return $true }
  return $false
}

function Get-LatestNpcapInstallerUrl {
  # Prefer GitHub API (stable); fall back to known redirect pattern if needed.
  try {
    $headers = @{
      'User-Agent' = 'XShark-dependency-installer'
      'Accept'     = 'application/vnd.github+json'
    }
    $rel = Invoke-RestMethod -Uri 'https://api.github.com/repos/nmap/npcap/releases/latest' -Headers $headers -TimeoutSec 60
    $asset = $rel.assets | Where-Object { $_.name -match '^npcap-.*\.exe$' -and $_.name -notmatch 'oem' } | Select-Object -First 1
    if ($asset) {
      return @{ Url = $asset.browser_download_url; Name = $asset.name }
    }
  } catch {
    Write-Info ("查询 Npcap 版本失败: {0}" -f $_.Exception.Message)
  }
  # Fallback: documented current release page still hosts installers; user can also visit npcap.com
  return $null
}

function Install-Npcap {
  if (Test-NpcapInstalled) {
    Write-Info 'Npcap 已安装，跳过。'
    return $true
  }

  $info = Get-LatestNpcapInstallerUrl
  if (-not $info) {
    Write-Info '无法自动获取 Npcap 下载地址。请手动打开 https://npcap.com/ 下载安装。'
    if (-not $Silent) {
      Start-Process 'https://npcap.com/#download'
    }
    return $false
  }

  $dest = Join-Path $env:TEMP $info.Name
  Write-Info ("正在下载 Npcap: {0}" -f $info.Name)
  try {
    Invoke-WebRequest -Uri $info.Url -OutFile $dest -UseBasicParsing -TimeoutSec 300
  } catch {
    Write-Info ("下载失败: {0}" -f $_.Exception.Message)
    if (-not $Silent) { Start-Process 'https://npcap.com/#download' }
    return $false
  }

  Write-Info '正在安装 Npcap（可能弹出安装向导）…'
  # /S = silent; /winpcap_mode=no keeps Npcap-only mode (recommended)
  $p = Start-Process -FilePath $dest -ArgumentList '/S','/winpcap_mode=no' -Wait -PassThru
  Write-Info ("Npcap 退出码: {0}" -f $p.ExitCode)
  Remove-Item $dest -Force -ErrorAction SilentlyContinue
  return (Test-NpcapInstalled)
}

# --- main ---
Ensure-Admin

Write-Info '======== XShark 依赖检查 ========'
$vcOk = $true
$npcapOk = $true

if (-not $SkipVcRedist) {
  $vcOk = Install-VcRedist
} else {
  Write-Info '已跳过 VC 运行库检查。'
}

if (-not $SkipNpcap) {
  $npcapOk = Install-Npcap
} else {
  Write-Info '已跳过 Npcap 检查。'
}

Write-Info '--------------------------------'
if ($vcOk) { Write-Info '[OK] VC++ 运行库' } else { Write-Info '[!!] VC++ 运行库未就绪' }
if ($npcapOk) { Write-Info '[OK] Npcap（抓包）' } else { Write-Info '[!!] Npcap 未就绪（可仅做离线打开 pcap）' }
Write-Info '================================'

if ($LaunchAfter) {
  $exe = Join-Path $Root 'XShark.exe'
  if (-not (Test-Path $exe)) { $exe = Join-Path $Root 'Wireshark.exe' }
  if (Test-Path $exe) {
    Start-Process -FilePath $exe -WorkingDirectory $Root
  }
}

if (-not $Silent) {
  Write-Host ''
  Write-Host '按任意键退出…'
  $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}

if ($vcOk -and $npcapOk) { exit 0 } else { exit 1 }
