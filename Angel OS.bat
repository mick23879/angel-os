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
$script:wApps = $null
$script:wAppsQuand = [datetime]::MinValue
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
