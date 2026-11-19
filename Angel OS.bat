@echo off
title Angel OS
cd /d "%~dp0"
if not exist "%~dp0angel-os.html" (
  echo.
  echo  Le fichier angel-os.html doit etre dans le meme dossier que ce lanceur.
  echo.
  pause
  exit /b
)
set "ANGEL_DIR=%~dp0"
set "ANGEL_BAT=%~f0"
start "" /min powershell -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -Command "$s=[IO.File]::ReadAllText($env:ANGEL_BAT); $i=$s.IndexOf('##'+'PS'+'##'); Invoke-Expression $s.Substring($i+6)"
exit /b
##PS##
# Angel OS - petit serveur local : sert angel-os.html et installe les mises a jour
$port = 47231
$dir = $env:ANGEL_DIR
$fichier = Join-Path $dir 'angel-os.html'
$origine = "http://localhost:$port"
$adresse = "$origine/"
$enc = New-Object System.Text.UTF8Encoding $false
$l = New-Object System.Net.HttpListener
$l.Prefixes.Add($adresse)
# Raccourcis avec l'icone Angel OS (bureau et menu Demarrer de Windows)
function Raccourcis {
  try {
    $ico = Join-Path $dir 'angel-os.ico'
    $bat = $env:ANGEL_BAT
    $sh = New-Object -ComObject WScript.Shell
    $lieux = @([Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('Programs'))
    foreach ($lieu in $lieux) {
      try {
      if (-not $lieu) { continue }
      $lnk = Join-Path $lieu 'Angel OS.lnk'
      $r = $sh.CreateShortcut($lnk)
      $r.TargetPath = $bat
      $r.WorkingDirectory = $dir
      $r.WindowStyle = 7
      $r.Description = 'Angel OS'
      if (Test-Path -LiteralPath $ico) { $r.IconLocation = "$ico,0" }
      $r.Save()
      } catch {}
    }
  } catch {}
}
Raccourcis
function Ouvrir {
  try { Start-Process 'msedge' -ArgumentList @("--app=$adresse", '--start-fullscreen') -ErrorAction Stop }
  catch { Start-Process $adresse }
}
try { $l.Start() } catch { Ouvrir; exit }
Ouvrir
$dernier = Get-Date
function Repondre($rep, $code, $type, [byte[]]$octets) {
  $rep.StatusCode = $code
  $rep.ContentType = $type
  $rep.Headers['Cache-Control'] = 'no-store'
  $rep.ContentLength64 = $octets.Length
  $rep.OutputStream.Write($octets, 0, $octets.Length)
  $rep.OutputStream.Close()
}
function Json($rep, $code, $txt) { Repondre $rep $code 'application/json; charset=utf-8' ($enc.GetBytes($txt)) }
# --- v62.14 : ouvrir les logiciels Windows depuis Angel OS ---
try { Add-Type -AssemblyName System.Drawing } catch {}
try {
Add-Type -TypeDefinition @'
using System; using System.Collections.Generic; using System.Runtime.InteropServices; using System.Text;
[ComImport, Guid("2e941141-7f97-4756-ba1d-9decde894a3d"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAngelAct { int ActivateApplication([MarshalAs(UnmanagedType.LPWStr)] string id, [MarshalAs(UnmanagedType.LPWStr)] string a, int o, out uint pid); }
[ComImport, Guid("45BA127D-10A8-46EA-8AB7-56EA9078943C")] class AngelActMgr {}
public static class AngelWin {
  delegate bool EnumProc(IntPtr h, IntPtr p);
  [DllImport("user32.dll")] static extern bool EnumWindows(EnumProc f, IntPtr p);
  [DllImport("user32.dll")] static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] static extern int GetWindowTextLength(IntPtr h);
  [DllImport("user32.dll")] static extern IntPtr GetWindow(IntPtr h, uint c);
  [DllImport("user32.dll")] static extern bool IsIconic(IntPtr h);
  [DllImport("user32.dll")] static extern bool ShowWindow(IntPtr h, int n);
  [DllImport("user32.dll")] static extern bool SetForegroundWindow(IntPtr h);
  [DllImport("user32.dll")] static extern bool BringWindowToTop(IntPtr h);
  [DllImport("user32.dll")] static extern void keybd_event(byte k, byte s, uint f, UIntPtr e);
  public static uint Activer(string aumid) { uint pid; ((IAngelAct)new AngelActMgr()).ActivateApplication(aumid, null, 0, out pid); return pid; }
  public static List<long> Visibles() {
    var L = new List<long>();
    EnumWindows((h, p) => { if (IsWindowVisible(h) && GetWindowTextLength(h) > 0 && GetWindow(h, 4) == IntPtr.Zero) L.Add(h.ToInt64()); return true; }, IntPtr.Zero);
    return L;
  }
  public static void Devant(long v) {
    IntPtr h = new IntPtr(v);
    keybd_event(0x12, 0, 0, UIntPtr.Zero); keybd_event(0x12, 0, 2, UIntPtr.Zero);
    ShowWindow(h, IsIconic(h) ? 9 : 5); BringWindowToTop(h); SetForegroundWindow(h);
  }
}
'@
} catch {}
# --- v62.16 : piloter le vrai Windows (alimentation, son, luminosite) ---
try {
Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices;
[ComImport, Guid("5CDF2C82-841E-4546-9722-0CF74078229A"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAngelVol { int f(); int g(); int h(); int i(); int SetMasterVolumeLevelScalar(float l, Guid c); int j(); int GetMasterVolumeLevelScalar(out float l); int k(); int l(); int m(); int n(); int SetMute([MarshalAs(UnmanagedType.Bool)] bool b, Guid c); int GetMute(out bool b); }
[ComImport, Guid("D666063F-1587-4E43-81F1-B948E807363F"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAngelDev { int Activate(ref Guid id, int ctx, IntPtr p, [MarshalAs(UnmanagedType.IUnknown)] out object o); }
[ComImport, Guid("A95664D2-9614-4F35-A746-DE8DB63617E6"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
interface IAngelEnum { int f(); int GetDefaultAudioEndpoint(int flow, int role, out IAngelDev d); }
[ComImport, Guid("BCDE0395-E52F-467C-8E3D-C4579291692E")] class AngelEnumCo {}
public static class AngelSon {
  static IAngelVol V() { var e = (IAngelEnum)(new AngelEnumCo()); IAngelDev d; Marshal.ThrowExceptionForHR(e.GetDefaultAudioEndpoint(0, 1, out d)); Guid g = typeof(IAngelVol).GUID; object o; Marshal.ThrowExceptionForHR(d.Activate(ref g, 23, IntPtr.Zero, out o)); return (IAngelVol)o; }
  public static int Lire() { float v; Marshal.ThrowExceptionForHR(V().GetMasterVolumeLevelScalar(out v)); return (int)Math.Round(v * 100); }
  public static void Mettre(int p) { var v = V(); Marshal.ThrowExceptionForHR(v.SetMasterVolumeLevelScalar(Math.Max(0, Math.Min(100, p)) / 100f, Guid.Empty)); v.SetMute(p == 0, Guid.Empty); }
  public static bool Muet() { bool b; V().GetMute(out b); return b; }
}
'@
} catch {}
function LireLumiere() {
  try { $b = Get-CimInstance -Namespace root/WMI -ClassName WmiMonitorBrightness -ErrorAction Stop | Select-Object -First 1; return [int]$b.CurrentBrightness } catch { return -1 }
}
function MettreLumiere($p) {
  try { $m = Get-CimInstance -Namespace root/WMI -ClassName WmiMonitorBrightnessMethods -ErrorAction Stop | Select-Object -First 1; Invoke-CimMethod -InputObject $m -MethodName WmiSetBrightness -Arguments @{ Timeout = [uint32]1; Brightness = [byte]$p } | Out-Null; return $true } catch { return $false }
}
function EtatSysteme() {
  $v = -1; $mu = $false
  try { $v = [AngelSon]::Lire(); $mu = [AngelSon]::Muet() } catch {}
  return (ConvertTo-Json -InputObject @{ ok = $true; volume = $v; muet = $mu; lumiere = (LireLumiere) } -Compress)
}
function ActionSysteme($t) {
  $a, $val = $t -split ':', 2
  switch ($a) {
    'eteindre'     { Start-Process -FilePath 'shutdown.exe' -ArgumentList '/s', '/t', '0' -WindowStyle Hidden; return 'ok' }
    'redemarrer'   { Start-Process -FilePath 'shutdown.exe' -ArgumentList '/r', '/t', '0' -WindowStyle Hidden; return 'ok' }
    'deconnexion'  { Start-Process -FilePath 'shutdown.exe' -ArgumentList '/l' -WindowStyle Hidden; return 'ok' }
    'veille'       { Add-Type -AssemblyName System.Windows.Forms; [void][System.Windows.Forms.Application]::SetSuspendState('Suspend', $false, $false); return 'ok' }
    'appinstaller' { Start-Process 'ms-windows-store://pdp/?productid=9NBLGGH4NNS1'; $script:wgExe = $null; return 'ok' }
    'recuperation' { Start-Process -FilePath 'shutdown.exe' -ArgumentList '/r', '/o', '/t', '0' -WindowStyle Hidden; return 'ok' }
    'volume'       { try { [AngelSon]::Mettre([int]$val); return 'ok' } catch { return 'erreur' } }
    'lumiere'      { if (MettreLumiere ([int]$val)) { return 'ok' } else { return 'erreur' } }
    default        { return 'inconnue' }
  }
}
# --- v62.18 : un seul magasin, synchronise avec Windows (winget) ---
$script:wgJobs = @{}
$script:wgListe = $null
$script:wgListeQuand = [datetime]::MinValue
$script:wgExe = $null
function WgChemin() {
  if ($script:wgExe) { return $script:wgExe }
  $c = @()
  try { $g = Get-Command winget -ErrorAction Stop; if ($g.Source) { $c += $g.Source } } catch {}
  $c += (Join-Path $env:LOCALAPPDATA 'Microsoft\WindowsApps\winget.exe')
  try { $pk = Get-AppxPackage -Name 'Microsoft.DesktopAppInstaller' -ErrorAction Stop | Sort-Object Version -Descending | Select-Object -First 1; if ($pk) { $script:diag.appInstaller = [string]$pk.Version; $c += (Join-Path $pk.InstallLocation 'winget.exe') } else { $script:diag.appInstaller = 'absent' } } catch { $script:diag.appInstaller = 'erreur' }
  foreach ($x in $c) { if ($x -and (Test-Path -LiteralPath $x)) { $script:wgExe = $x; break } }
  $script:diag.winget = if ($script:wgExe) { $script:wgExe } else { 'introuvable' }
  return $script:wgExe
}
function WgExec($a, $maxMs) {
  $exe = WgChemin
  if (-not $exe) { $script:diag.wgErr = 'winget introuvable'; return $null }
  try {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $exe; $psi.Arguments = $a; $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true; $psi.RedirectStandardError = $true; $psi.CreateNoWindow = $true
    $psi.StandardOutputEncoding = [Text.Encoding]::UTF8
    $pr = [Diagnostics.Process]::Start($psi)
    $tache = $pr.StandardOutput.ReadToEndAsync()
    if (-not $pr.WaitForExit($maxMs)) { try { $pr.Kill() } catch {} ; $script:diag.wgErr = 'trop long : ' + $a; return $null }
    $script:diag.wgCode = ('0x{0:X8}' -f $pr.ExitCode)
    return $tache.Result
  } catch { $script:diag.wgErr = $_.Exception.Message; return $null }
}
function WgTable($txt) {
  $res = New-Object System.Collections.ArrayList
  if (-not $txt) { return $res }
  $lignes = @($txt -split "`n" | ForEach-Object { $l = $_.TrimEnd("`r"); $k = $l.LastIndexOf("`r"); if ($k -ge 0) { $l = $l.Substring($k + 1) }; $l })
  $i = -1
  for ($n = 1; $n -lt $lignes.Count; $n++) { if ($lignes[$n] -match '^-{8,}\s*$') { $i = $n; break } }
  if ($i -lt 1) { return $res }
  $tete = $lignes[$i - 1]
  $debuts = @(); for ($k = 0; $k -lt $tete.Length; $k++) { if ($tete[$k] -ne ' ' -and ($k -eq 0 -or $tete[$k - 1] -eq ' ')) { $debuts += $k } }
  $noms = @(); foreach ($d in $debuts) { $f = $tete.IndexOf(' ', $d); if ($f -lt 0) { $f = $tete.Length }; $noms += $tete.Substring($d, $f - $d).ToLower() }
  $cle = @{}
  for ($c = 0; $c -lt $noms.Count; $c++) {
    $t = $noms[$c]
    if ($t -match '^(name|nom)') { $cle['nom'] = $c } elseif ($t -eq 'id') { $cle['id'] = $c } elseif ($t -match '^version') { $cle['version'] = $c }
    elseif ($t -match '^(available|disponible)') { $cle['dispo'] = $c } elseif ($t -match '^source') { $cle['source'] = $c }
  }
  if (-not $cle.ContainsKey('id')) { return $res }
  for ($n = $i + 1; $n -lt $lignes.Count; $n++) {
    $l = $lignes[$n]; if (-not $l.Trim()) { continue }
    $champs = @()
    for ($c = 0; $c -lt $debuts.Count; $c++) {
      $a = $debuts[$c]; $b = if ($c + 1 -lt $debuts.Count) { $debuts[$c + 1] } else { [Math]::Max($l.Length, $a) }
      if ($a -ge $l.Length) { $champs += '' } else { $champs += $l.Substring($a, [Math]::Min($b, $l.Length) - $a).Trim() }
    }
    $id = $champs[$cle['id']]
    if (-not $id -or $id -notmatch '^[A-Za-z0-9][A-Za-z0-9.\-_+]{1,120}$') { continue }
    $o = [ordered]@{ nom = $champs[$cle['nom']]; id = $id; version = '' ; dispo = ''; source = '' }
    if ($cle.ContainsKey('version')) { $o.version = $champs[$cle['version']] }
    if ($cle.ContainsKey('dispo')) { $o.dispo = $champs[$cle['dispo']] }
    if ($cle.ContainsKey('source')) { $o.source = $champs[$cle['source']] }
    [void]$res.Add($o)
  }
  return $res
}
function WgCherche($q) {
  $q = ($q -replace '[^\p{L}\p{N} .+\-_]', '').Trim()
  if ($q.Length -lt 2) { return @() }
  $t = WgExec ('search --query "' + $q + '" --accept-source-agreements --disable-interactivity') 60000
  if ($null -eq $t) { return $null }
  return @(WgTable $t | Select-Object -First 40)
}
function WgInstalles($frais) {
  if (-not $frais -and $script:wgListe -and ((Get-Date) - $script:wgListeQuand).TotalSeconds -lt 90) { return $script:wgListe }
  $t = WgExec 'list --accept-source-agreements --disable-interactivity' 90000
  if ($null -eq $t) { return $null }
  $script:wgListe = @(WgTable $t); $script:wgListeQuand = Get-Date
  return $script:wgListe
}
function WgLancer($verbe, $id) {
  if ($script:wgJobs.ContainsKey($id) -and -not $script:wgJobs[$id].p.HasExited) { return 'encours' }
  $a = "$verbe --id $id -e --accept-source-agreements --disable-interactivity --silent"
  if ($verbe -ne 'uninstall') { $a += ' --accept-package-agreements' }
  $exe = WgChemin; if (-not $exe) { return 'erreur' }
  $psi = New-Object System.Diagnostics.ProcessStartInfo
  $psi.FileName = $exe; $psi.Arguments = $a; $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
  $pr = [Diagnostics.Process]::Start($psi)
  $script:wgJobs[$id] = @{ p = $pr; verbe = $verbe }
  $script:wgListe = $null; $script:wApps = $null
  return 'ok'
}
function WgEtats() {
  $o = @{}
  foreach ($k in @($script:wgJobs.Keys)) {
    $j = $script:wgJobs[$k]
    if ($j.p.HasExited) { $o[$k] = @{ etat = 'fini'; code = ('0x{0:X8}' -f $j.p.ExitCode); verbe = $j.verbe } }
    else { $o[$k] = @{ etat = 'encours'; verbe = $j.verbe } }
  }
  return $o
}
$script:wApps = $null
$script:wAppsQuand = [datetime]::MinValue
# --- v62.19 : peripheriques reels (Windows previent le lanceur a chaque branchement) ---
$script:diag = [ordered]@{ lanceur = '62.20'; demarre = (Get-Date).ToString('dd/MM HH:mm:ss') }
$script:periEvt = 0
try { Add-Type -AssemblyName System.Management } catch {}
try {
Add-Type -ReferencedAssemblies ([System.Management.ManagementEventWatcher].Assembly.Location) -TypeDefinition @'
using System; using System.Management; using System.Threading;
public static class AngelPeri {
  public static int Rev = 0; static ManagementEventWatcher w;
  public static void Demarrer() { try { w = new ManagementEventWatcher(new WqlEventQuery("SELECT * FROM Win32_DeviceChangeEvent")); w.EventArrived += (s, e) => { Interlocked.Increment(ref Rev); }; w.Start(); } catch { } }
}
'@
[AngelPeri]::Demarrer()
$script:diag.periType = 'ok'
} catch { $script:diag.periType = 'erreur : ' + $_.Exception.Message }
try { Register-WmiEvent -Query 'SELECT * FROM Win32_DeviceChangeEvent' -SourceIdentifier 'AngelPeri' -ErrorAction Stop | Out-Null; $script:diag.periEvt = 'ok' } catch { $script:diag.periEvt = 'erreur : ' + $_.Exception.Message }
function PeriRev() {
  try { $ev = @(Get-Event -SourceIdentifier 'AngelPeri' -ErrorAction SilentlyContinue); if ($ev.Count) { $script:periEvt += $ev.Count; $ev | Remove-Event -ErrorAction SilentlyContinue } } catch {}
  $r = $script:periEvt; try { $r += [AngelPeri]::Rev } catch {}
  return $r
}
$script:periCache = $null; $script:periRev = -1
function ListePeri() {
  $rev = PeriRev
  if ($script:periCache -and $script:periRev -eq $rev) { return $script:periCache }
  $L = New-Object System.Collections.ArrayList; $vus = @{}
  try {
    foreach ($d in @(Get-CimInstance -ClassName Win32_LogicalDisk -Filter 'DriveType=2' -ErrorAction Stop)) {
      $nom = if ($d.VolumeName) { $d.VolumeName } else { 'Cle USB' }
      [void]$L.Add([ordered]@{ cle = 'w:vol:' + $d.DeviceID + ':' + $d.VolumeSerialNumber; cat = 'stockage'; nom = $nom + ' (' + $d.DeviceID + ')'; fab = ''; lettre = $d.DeviceID; usb = $true })
    }
  } catch {}
  try {
    $classes = @{ Mouse = 'hid'; Keyboard = 'hid'; HIDClass = 'manette'; Camera = 'camera'; Image = 'camera'; AudioEndpoint = 'sortie'; Printer = 'imprimante'; WPD = 'usb'; Bluetooth = 'sansfil'; Media = 'audio' }
    foreach ($e in @(Get-CimInstance -ClassName Win32_PnPEntity -Filter 'Present=TRUE' -ErrorAction Stop)) {
      $cl = [string]$e.PNPClass; $id = [string]$e.PNPDeviceID
      if (-not $classes.ContainsKey($cl)) { continue }
      if ($id -notmatch '^(USB|HID|BTHENUM|BTHLE|SWD\\MMDEVAPI|SWD\\WPDBUSENUM)') { continue }
      if ($cl -eq 'HIDClass' -and $e.Name -notmatch 'game|manette|controller|xbox|joystick') { continue }
      if ($cl -eq 'Bluetooth' -and $id -notmatch '^(BTHENUM|BTHLE)\\(Dev_|\{)') { continue }
      $cat = $classes[$cl]; if ($cl -eq 'AudioEndpoint' -and $e.Name -match 'micro|mic') { $cat = 'micro' }
      $k = ($cl + '|' + $e.Name).ToLower(); if ($vus.ContainsKey($k)) { continue }; $vus[$k] = 1
      $vp = ''; if ($id -match 'VID_([0-9A-F]{4})&PID_([0-9A-F]{4})') { $vp = ($Matches[1] + ':' + $Matches[2]).ToLower() }
      $fab = [string]$e.Manufacturer; if ($fab -match '^\(|standard|g.n.rique|generic|^microsoft$') { $fab = '' }
      [void]$L.Add([ordered]@{ cle = 'w:' + $id; cat = $cat; nom = [string]$e.Name; fab = $fab; ids = $vp; usb = ($id -match '^(USB|HID|SWD\\WPDBUSENUM)') })
    }
  } catch {}
  $script:periCache = @($L); $script:periRev = $rev
  return $script:periCache
}
function IconeB64($chemin) {
  try {
    $i = [System.Drawing.Icon]::ExtractAssociatedIcon($chemin)
    if (-not $i) { return '' }
    $b = $i.ToBitmap(); $m = New-Object System.IO.MemoryStream
    $b.Save($m, [System.Drawing.Imaging.ImageFormat]::Png)
    $t = 'data:image/png;base64,' + [Convert]::ToBase64String($m.ToArray())
    $b.Dispose(); $i.Dispose(); $m.Dispose(); return $t
  } catch { return '' }
}
function LogoStore($aumid) {
  try {
    $fam, $appId = $aumid -split '!', 2
    $p = Get-AppxPackage | Where-Object { $_.PackageFamilyName -eq $fam } | Select-Object -First 1
    if (-not $p) { return '' }
    $app = @((Get-AppxPackageManifest $p).Package.Applications.Application) | Where-Object { $_.Id -eq $appId } | Select-Object -First 1
    if (-not $app) { return '' }
    $ve = $app.VisualElements
    $logo = $ve.Square44x44Logo; if (-not $logo) { $logo = $ve.Square150x150Logo }
    if (-not $logo) { return '' }
    $base = Join-Path $p.InstallLocation $logo
    $dirL = Split-Path -Parent $base
    $nom = [IO.Path]::GetFileNameWithoutExtension($base); $ext = [IO.Path]::GetExtension($base)
    $f = $null
    if (Test-Path -LiteralPath $base) { $f = Get-Item -LiteralPath $base }
    else {
      $c = @(Get-ChildItem -LiteralPath $dirL -Filter ($nom + '*' + $ext) -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch 'contrast|unplated' })
      $f = ($c | Where-Object { $_.Name -match 'targetsize-48|scale-200' } | Select-Object -First 1)
      if (-not $f) { $f = $c | Sort-Object Length -Descending | Select-Object -First 1 }
    }
    if (-not $f -or $f.Length -gt 60000) { return '' }
    return 'data:image/png;base64,' + [Convert]::ToBase64String([IO.File]::ReadAllBytes($f.FullName))
  } catch { return '' }
}
function ListeApplis($frais) {
  if (-not $frais -and $script:wApps -and ((Get-Date) - $script:wAppsQuand).TotalMinutes -lt 10) { return $script:wApps }
  $L = New-Object System.Collections.ArrayList
  $vus = @{}
  $sh = New-Object -ComObject WScript.Shell
  $lieux = @()
  foreach ($k in 'Programs', 'CommonPrograms', 'Desktop', 'CommonDesktopDirectory') {
    try { $d = [Environment]::GetFolderPath($k); if ($d -and (Test-Path -LiteralPath $d)) { $lieux += $d } } catch {}
  }
  $exclus = 'uninstall|desinstall|d.sinstall|readme|lisez|license|licence|help|aide|documentation|website|site web|angel os|remettre windows'
  $exclus += '|file explorer|explorateur|^ex.cuter$|^run$|command prompt|invite de commandes|powershell|registry|registre|recovery drive|administrative tools|outils d.administration|windows tools|outils windows|lecteur de r.cup.ration'
  $dossiersExclus = '\\(Administrative Tools|Windows Tools|Outils Windows|Outils d.administration|System Tools|Outils syst.me)\\'
  foreach ($d in $lieux) {
    foreach ($f in @(Get-ChildItem -LiteralPath $d -Recurse -Include *.lnk, *.url -ErrorAction SilentlyContinue)) {
      try {
        $nom = [IO.Path]::GetFileNameWithoutExtension($f.Name)
        if ($nom -match $exclus) { continue }
        if ($f.FullName -match $dossiersExclus) { continue }
        $cle = $nom.ToLower()
        if ($vus.ContainsKey($cle)) { continue }
        $cible = ''
        if ($f.Extension -ieq '.lnk') { $cible = $sh.CreateShortcut($f.FullName).TargetPath }
        if ($cible -match '\\explorer\.exe$' -or $cible -match '\\(cmd|powershell|pwsh|regedit|mmc)\.exe$') { continue }
        $vus[$cle] = 1
        [void]$L.Add([ordered]@{ id = 'L:' + $f.FullName; nom = $nom; type = 'lnk'; ico = (IconeB64 $f.FullName) })
      } catch {}
    }
  }
  try {
    foreach ($a in @(Get-StartApps | Where-Object { $_.AppID -like '*!*' })) {
      $cle = $a.Name.ToLower()
      if ($vus.ContainsKey($cle) -or $a.Name -match $exclus) { continue }
      $vus[$cle] = 1
      [void]$L.Add([ordered]@{ id = 'S:' + $a.AppID; nom = $a.Name; type = 'store'; ico = (LogoStore $a.AppID) })
    }
  } catch {}
  $script:wApps = @($L | Sort-Object { $_.nom })
  $script:wAppsQuand = Get-Date
  return $script:wApps
}
function LancerAppli($id) {
  $a = @(ListeApplis $false) | Where-Object { $_.id -eq $id } | Select-Object -First 1
  if (-not $a) { $a = @(ListeApplis $true) | Where-Object { $_.id -eq $id } | Select-Object -First 1 }
  if (-not $a) { return 'inconnue' }
  if ($a.type -eq 'store') { [void][AngelWin]::Activer($id.Substring(2)) }
  else { Start-Process -FilePath $id.Substring(2) }
  return 'ok'
}
function MettreDevant($avant) {
  for ($n = 0; $n -lt 30; $n++) {
    Start-Sleep -Milliseconds 500
    try {
      $neuves = @([AngelWin]::Visibles() | Where-Object { $avant -notcontains $_ })
      if ($neuves.Count) { Start-Sleep -Milliseconds 400; [AngelWin]::Devant($neuves[0]); return }
    } catch { return }
  }
}
while ($l.IsListening) {
  $attente = $l.GetContextAsync()
  while (-not $attente.Wait(30000)) {
    if (((Get-Date) - $dernier).TotalMinutes -gt 15) { $l.Stop(); exit }
  }
  $c = $attente.Result
  $dernier = Get-Date
  $req = $c.Request
  $rep = $c.Response
  try {
    $chemin = $req.Url.AbsolutePath
    if ($req.HttpMethod -eq 'GET' -and ($chemin -eq '/' -or $chemin -eq '/angel-os.html')) {
      Repondre $rep 200 'text/html; charset=utf-8' ([System.IO.File]::ReadAllBytes($fichier))
    }
    elseif ($chemin -eq '/angel/ping') {
      Json $rep 200 '{"ok":true,"lanceur":1}'
    }
    elseif ($chemin -eq '/angel/maj' -and $req.HttpMethod -eq 'POST') {
      if ($req.Headers['X-Angel'] -ne '1' -or ($req.Headers['Origin'] -and $req.Headers['Origin'] -ne $origine)) {
        Json $rep 403 '{"ok":false,"err":"refuse"}'
      } else {
        $lecteur = New-Object System.IO.StreamReader($req.InputStream, $enc)
        $txt = $lecteur.ReadToEnd()
        $lecteur.Close()
        if ($txt.Length -lt 200000 -or -not $txt.Contains('<title>Angel OS</title>') -or -not $txt.Contains('ANGEL_BUILD=')) {
          Json $rep 400 '{"ok":false,"err":"fichier invalide"}'
        } else {
          $tmp = $fichier + '.nouveau'
          [System.IO.File]::WriteAllText($tmp, $txt, $enc)
          Copy-Item -LiteralPath $fichier -Destination (Join-Path $dir 'angel-os.ancien.html') -Force
          Move-Item -LiteralPath $tmp -Destination $fichier -Force
          Json $rep 200 '{"ok":true}'
        }
      }
    }
    elseif ($chemin -eq '/angel/applis' -and $req.HttpMethod -eq 'GET') {
      $frais = ($req.Url.Query -match 'frais=1')
      $j = ConvertTo-Json -InputObject @{ ok = $true; applis = @(ListeApplis $frais) } -Depth 4 -Compress
      Json $rep 200 $j
    }
    elseif ($chemin -eq '/angel/store/cherche' -and $req.HttpMethod -eq 'GET') {
      $L = WgCherche ([string]$req.QueryString['q'])
      if ($null -eq $L) { Json $rep 200 '{"ok":false,"err":"winget"}' } else { Json $rep 200 (ConvertTo-Json -InputObject @{ ok = $true; res = @($L) } -Depth 4 -Compress) }
    }
    elseif ($chemin -eq '/angel/store/installes' -and $req.HttpMethod -eq 'GET') {
      $L = WgInstalles ($req.Url.Query -match 'frais=1')
      if ($null -eq $L) { Json $rep 200 '{"ok":false,"err":"winget"}' } else { Json $rep 200 (ConvertTo-Json -InputObject @{ ok = $true; res = @($L) } -Depth 4 -Compress) }
    }
    elseif ($chemin -eq '/angel/store/etat' -and $req.HttpMethod -eq 'GET') {
      Json $rep 200 (ConvertTo-Json -InputObject @{ ok = $true; jobs = (WgEtats) } -Depth 4 -Compress)
    }
    elseif ($chemin -eq '/angel/store/action' -and $req.HttpMethod -eq 'POST') {
      if ($req.Headers['X-Angel'] -ne '1' -or ($req.Headers['Origin'] -and $req.Headers['Origin'] -ne $origine)) {
        Json $rep 403 '{"ok":false,"err":"refuse"}'
      } else {
        $lecteur = New-Object System.IO.StreamReader($req.InputStream, $enc)
        $t = $lecteur.ReadToEnd().Trim()
        $lecteur.Close()
        if ($t -match '^(install|uninstall|upgrade):([A-Za-z0-9][A-Za-z0-9.\-_+]{1,120})$') {
          $r = 'erreur'; try { $r = WgLancer $Matches[1] $Matches[2] } catch { $r = 'erreur' }
          if ($r -eq 'erreur') { Json $rep 500 '{"ok":false,"err":"winget"}' } else { Json $rep 200 ('{"ok":true,"etat":"' + $r + '"}') }
        } else { Json $rep 400 '{"ok":false,"err":"inconnue"}' }
      }
    }
    elseif ($chemin -eq '/angel/diag') {
      [void](WgChemin)
      $v = WgExec '--version' 20000; $script:diag.wgVersion = if ($v) { $v.Trim() } else { '' }
      $script:diag.periRev = PeriRev
      try { $script:diag.peri = @(ListePeri | ForEach-Object { $_.nom }) -join ' | ' } catch { $script:diag.peri = 'erreur' }
      $script:diag.quand = (Get-Date).ToString('dd/MM HH:mm:ss')
      $j = ConvertTo-Json -InputObject $script:diag -Depth 3
      foreach ($dd in @((Join-Path $env:USERPROFILE 'Downloads\AngelOS-bureau'), $dir)) { try { if (Test-Path -LiteralPath $dd) { [IO.File]::WriteAllText((Join-Path $dd 'lanceur-diag.txt'), $j, $enc) } } catch {} }
      Json $rep 200 (ConvertTo-Json -InputObject $script:diag -Depth 3 -Compress)
    }
    elseif ($chemin -eq '/angel/peri/rev') {
      Json $rep 200 ('{"ok":true,"rev":' + (PeriRev) + '}')
    }
    elseif ($chemin -eq '/angel/peri') {
      $lp = @(ListePeri)
      Json $rep 200 (ConvertTo-Json -InputObject @{ ok = $true; rev = $script:periRev; liste = $lp } -Depth 4 -Compress)
    }
    elseif ($chemin -eq '/angel/sys' -and $req.HttpMethod -eq 'GET') {
      Json $rep 200 (EtatSysteme)
    }
    elseif ($chemin -eq '/angel/sys' -and $req.HttpMethod -eq 'POST') {
      if ($req.Headers['X-Angel'] -ne '1' -or ($req.Headers['Origin'] -and $req.Headers['Origin'] -ne $origine)) {
        Json $rep 403 '{"ok":false,"err":"refuse"}'
      } else {
        $lecteur = New-Object System.IO.StreamReader($req.InputStream, $enc)
        $t = $lecteur.ReadToEnd().Trim()
        $lecteur.Close()
        $r = 'erreur'
        if ($t -match '^(eteindre|redemarrer|deconnexion|veille|recuperation|appinstaller|volume:\d{1,3}|lumiere:\d{1,3})$') {
          $diff = ($t -match '^(eteindre|redemarrer|deconnexion|veille|recuperation)$')
          if ($diff) { Json $rep 200 '{"ok":true}'; Start-Sleep -Milliseconds 300; try { [void](ActionSysteme $t) } catch {} ; continue }
          try { $r = ActionSysteme $t } catch { $r = 'erreur' }
        } else { $r = 'inconnue' }
        if ($r -eq 'ok') { Json $rep 200 '{"ok":true}' }
        elseif ($r -eq 'inconnue') { Json $rep 400 '{"ok":false,"err":"inconnue"}' }
        else { Json $rep 500 '{"ok":false,"err":"echec"}' }
      }
    }
    elseif ($chemin -eq '/angel/lancer' -and $req.HttpMethod -eq 'POST') {
      if ($req.Headers['X-Angel'] -ne '1' -or ($req.Headers['Origin'] -and $req.Headers['Origin'] -ne $origine)) {
        Json $rep 403 '{"ok":false,"err":"refuse"}'
      } else {
        $lecteur = New-Object System.IO.StreamReader($req.InputStream, $enc)
        $id = $lecteur.ReadToEnd().Trim()
        $lecteur.Close()
        $avant = @()
        try { $avant = @([AngelWin]::Visibles()) } catch {}
        $r = 'erreur'
        try { $r = LancerAppli $id } catch { $r = 'erreur' }
        if ($r -eq 'ok') { Json $rep 200 '{"ok":true}'; MettreDevant $avant }
        elseif ($r -eq 'inconnue') { Json $rep 404 '{"ok":false,"err":"inconnue"}' }
        else { Json $rep 500 '{"ok":false,"err":"lancement"}' }
      }
    }
    else { Json $rep 404 '{"ok":false,"err":"introuvable"}' }
  } catch {
    try { Json $rep 500 '{"ok":false,"err":"erreur"}' } catch {}
  }
}
