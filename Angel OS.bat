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
    else { Json $rep 404 '{"ok":false,"err":"introuvable"}' }
  } catch {
    try { Json $rep 500 '{"ok":false,"err":"erreur"}' } catch {}
  }
}
