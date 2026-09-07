#Requires -Version 5.1
param(
  [switch]$Silent,
  [switch]$SkipNpcap,
  [switch]$SkipVcRedist,
  [switch]$LaunchAfter,
  [switch]$NoPause,
  [string]$LogFile
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
if ([string]::IsNullOrWhiteSpace($Root)) { $Root = (Get-Location).Path }
Set-Location -LiteralPath $Root

if ([string]::IsNullOrWhiteSpace($LogFile)) {
  $LogFile = Join-Path $Root 'xshark-deps.log'
}

$script:ExitCode = 0

function Write-Log {
  param(
    [Parameter(Mandatory = $true)][string]$Message,
    [ValidateSet('INFO', 'WARN', 'ERROR', 'OK')][string]$Level = 'INFO'
  )
  $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
  try { Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8 } catch {}
  if (-not $Silent) {
    switch ($Level) {
      'ERROR' { Write-Host $line -ForegroundColor Red }
      'WARN'  { Write-Host $line -ForegroundColor Yellow }
      'OK'    { Write-Host $line -ForegroundColor Green }
      default { Write-Host $line }
    }
  } elseif ($Level -eq 'ERROR') {
    Write-Host $line -ForegroundColor Red
  }
}

function Test-IsAdmin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p = New-Object Security.Principal.WindowsPrincipal($id)
  return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-VcRedistInstalled {
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
  return (Test-Path "$env:SystemRoot\System32\vcruntime140.dll") -and
         (Test-Path "$env:SystemRoot\System32\msvcp140.dll")
}

function Test-NpcapInstalled {
  $reg = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\NpcapInst'
  if (Test-Path $reg) { return $true }
  if (Test-Path "$env:SystemRoot\System32\Npcap\wpcap.dll") { return $true }
  if (Get-Service -Name 'npcap' -ErrorAction SilentlyContinue) { return $true }
  return $false
}

function Install-VcRedist {
  $exe = Join-Path $Root 'vc_redist.x64.exe'
  if (-not (Test-Path -LiteralPath $exe)) {
    Write-Log "vc_redist.x64.exe not found: $exe" 'WARN'
    return $false
  }
  if (Test-VcRedistInstalled) {
    Write-Log 'VC++ runtime already installed.' 'OK'
    return $true
  }
  Write-Log "Installing VC++ runtime: $exe"
  $p = Start-Process -FilePath $exe -ArgumentList '/install', '/quiet', '/norestart' -Wait -PassThru
  Write-Log ("vc_redist exit code: {0}" -f $p.ExitCode)
  if ($p.ExitCode -in 0, 1638, 3010) { return $true }
  Write-Log ("VC++ install failed, exit={0}" -f $p.ExitCode) 'ERROR'
  return $false
}

function Get-LatestNpcapInstallerUrl {
  try {
    $headers = @{
      'User-Agent' = 'XShark-dependency-installer'
      'Accept'     = 'application/vnd.github+json'
    }
    Write-Log 'Querying latest Npcap release...'
    $rel = Invoke-RestMethod -Uri 'https://api.github.com/repos/nmap/npcap/releases/latest' -Headers $headers -TimeoutSec 60
    $asset = $rel.assets | Where-Object { $_.name -match '^npcap-.*\.exe$' -and $_.name -notmatch 'oem' } | Select-Object -First 1
    if ($asset) {
      Write-Log ("Npcap asset: {0}" -f $asset.name)
      return @{ Url = $asset.browser_download_url; Name = $asset.name }
    }
    Write-Log 'No Npcap exe asset found.' 'WARN'
  } catch {
    Write-Log ("Npcap version query failed: {0}" -f $_.Exception.Message) 'WARN'
  }
  return $null
}

function Install-Npcap {
  if (Test-NpcapInstalled) {
    Write-Log 'Npcap already installed.' 'OK'
    return $true
  }

  $info = Get-LatestNpcapInstallerUrl
  if (-not $info) {
    Write-Log 'Cannot resolve Npcap download URL. Open https://npcap.com/' 'ERROR'
    if (-not $Silent) { try { Start-Process 'https://npcap.com/#download' } catch {} }
    return $false
  }

  $dest = Join-Path $env:TEMP $info.Name
  Write-Log ("Downloading Npcap: {0}" -f $info.Url)
  try {
    Invoke-WebRequest -Uri $info.Url -OutFile $dest -UseBasicParsing -TimeoutSec 300
    Write-Log ("Download done: {0} ({1} bytes)" -f $dest, (Get-Item -LiteralPath $dest).Length)
  } catch {
    Write-Log ("Download failed: {0}" -f $_.Exception.Message) 'ERROR'
    if (-not $Silent) { try { Start-Process 'https://npcap.com/#download' } catch {} }
    return $false
  }

  Write-Log 'Installing Npcap (/S /winpcap_mode=no)...'
  $p = Start-Process -FilePath $dest -ArgumentList '/S', '/winpcap_mode=no' -Wait -PassThru
  Write-Log ("Npcap exit code: {0}" -f $p.ExitCode)
  Remove-Item -LiteralPath $dest -Force -ErrorAction SilentlyContinue
  if (Test-NpcapInstalled) {
    Write-Log 'Npcap installed.' 'OK'
    return $true
  }
  Write-Log 'Npcap still not detected after install.' 'ERROR'
  return $false
}

function Start-XSharkApp {
  $exe = Join-Path $Root 'XShark.exe'
  if (-not (Test-Path -LiteralPath $exe)) {
    Write-Log "XShark.exe not found in $Root" 'ERROR'
    $script:ExitCode = 2
    return
  }

  $appLog = Join-Path $Root 'xshark-app.log'
  Write-Log "Starting: $exe"
  Write-Log "App log: $appLog"
  try {
    $p = Start-Process -FilePath $exe -WorkingDirectory $Root -PassThru
    Start-Sleep -Milliseconds 1200
    if ($null -eq $p) {
      Write-Log 'Start-Process returned null.' 'ERROR'
      Set-Content -LiteralPath $appLog -Value 'Start-Process returned null' -Encoding UTF8
      $script:ExitCode = 3
      return
    }
    if ($p.HasExited) {
      $code = [int]$p.ExitCode
      Write-Log ("Process exited immediately, code={0}" -f $code) 'ERROR'
      $msg = "XShark start failed, exit=$code`r`nexe=$exe`r`ncwd=$Root"
      Set-Content -LiteralPath $appLog -Value $msg -Encoding UTF8
      $script:ExitCode = if ($code -ne 0) { $code } else { 3 }
    } else {
      Write-Log ("Started OK, PID={0}" -f $p.Id) 'OK'
      Set-Content -LiteralPath $appLog -Value ("started pid={0} exe={1}" -f $p.Id, $exe) -Encoding UTF8
    }
  } catch {
    Write-Log ("Start failed: {0}" -f $_.Exception.Message) 'ERROR'
    Set-Content -LiteralPath $appLog -Value $_.Exception.ToString() -Encoding UTF8
    $script:ExitCode = 4
  }
}

function Wait-IfNeeded {
  param([bool]$Failed)
  if ($NoPause) { return }
  if (-not $Failed -and $LaunchAfter) { return }
  if (-not $Failed -and $Silent) { return }
  Write-Host ''
  Write-Host ("Log file: {0}" -f $LogFile)
  if ($Failed) {
    Write-Host 'Failed. Please send the log file for troubleshooting.' -ForegroundColor Yellow
  }
  Write-Host 'Press any key to exit...'
  try {
    $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
  } catch {
    Start-Sleep -Seconds 10
  }
}

try {
  Write-Log '======== XShark dependency check start ========'
  Write-Log ("Root={0}" -f $Root)
  Write-Log ("User={0}; IsAdmin={1}; Silent={2}; LaunchAfter={3}" -f $env:USERNAME, (Test-IsAdmin), [bool]$Silent, [bool]$LaunchAfter)
  Write-Log ("PSVersion={0}" -f $PSVersionTable.PSVersion)

  $needVc = (-not $SkipVcRedist) -and -not (Test-VcRedistInstalled)
  $needNpcap = (-not $SkipNpcap) -and -not (Test-NpcapInstalled)
  Write-Log ("needVc={0}; needNpcap={1}" -f $needVc, $needNpcap)

  if (($needVc -or $needNpcap) -and -not (Test-IsAdmin)) {
    Write-Log 'Missing deps and not admin; requesting elevation...' 'WARN'
    $argList = @(
      '-NoProfile',
      '-ExecutionPolicy', 'Bypass',
      '-File', $PSCommandPath,
      '-LogFile', $LogFile
    )
    if ($Silent) { $argList += '-Silent' }
    if ($SkipNpcap) { $argList += '-SkipNpcap' }
    if ($SkipVcRedist) { $argList += '-SkipVcRedist' }
    if ($LaunchAfter) { $argList += '-LaunchAfter' }
    if ($NoPause) { $argList += '-NoPause' }

    try {
      $p = Start-Process -FilePath 'powershell.exe' -Verb RunAs -ArgumentList $argList -Wait -PassThru
    } catch {
      Write-Log ("Elevation failed (UAC canceled?): {0}" -f $_.Exception.Message) 'ERROR'
      $script:ExitCode = 5
      Wait-IfNeeded -Failed $true
      exit 5
    }
    $code = 0
    if ($null -ne $p) { $code = [int]$p.ExitCode }
    Write-Log ("Elevated process exit code={0}" -f $code)
    $script:ExitCode = $code
    exit $code
  }

  $vcOk = $true
  $npcapOk = $true

  if (-not $SkipVcRedist) {
    if (Test-VcRedistInstalled) {
      Write-Log 'VC++ runtime ready.' 'OK'
    } else {
      $vcOk = Install-VcRedist
    }
  } else {
    Write-Log 'Skip VC++ check.'
  }

  if (-not $SkipNpcap) {
    if (Test-NpcapInstalled) {
      Write-Log 'Npcap ready.' 'OK'
    } else {
      $npcapOk = Install-Npcap
    }
  } else {
    Write-Log 'Skip Npcap check.'
  }

  Write-Log '--------------------------------'
  if ($vcOk) {
    Write-Log '[OK] VC++ runtime' 'OK'
  } else {
    Write-Log '[!!] VC++ runtime missing' 'ERROR'
    $script:ExitCode = 1
  }
  if ($npcapOk) {
    Write-Log '[OK] Npcap' 'OK'
  } else {
    Write-Log '[!!] Npcap missing (offline pcap still works)' 'WARN'
  }
  Write-Log '======== dependency check end ========'

  if ($LaunchAfter) {
    Start-XSharkApp
  }
} catch {
  $script:ExitCode = 10
  Write-Log ("Unhandled exception: {0}" -f $_.Exception.Message) 'ERROR'
  try { Add-Content -LiteralPath $LogFile -Value $_.ScriptStackTrace -Encoding UTF8 } catch {}
  if (-not $Silent) {
    Write-Host $_.Exception.ToString() -ForegroundColor Red
  }
} finally {
  Wait-IfNeeded -Failed ($script:ExitCode -ne 0)
}

exit $script:ExitCode
