# Instalador del entorno CTF para Windows
# Ejecutar desde PowerShell:
#   powershell -ExecutionPolicy Bypass -File .\install.ps1
# Con imagen ya publicada por la organización:
#   $env:CTF_REMOTE_IMAGE="ghcr.io/usuario/ctf-tools:latest"; powershell -ExecutionPolicy Bypass -File .\install.ps1

$Image  = "ctf-tools:latest"
$CtfDir = Join-Path $env:USERPROFILE "ctf"
$BinDir = Join-Path $env:USERPROFILE ".ctf"
$Remote = $env:CTF_REMOTE_IMAGE

function Info($m) { Write-Host "[*] $m" -ForegroundColor Cyan }
function Ok($m)   { Write-Host "[+] $m" -ForegroundColor Green }
function Warn($m) { Write-Host "[!] $m" -ForegroundColor Yellow }
function Fail($m) { Write-Host "[x] $m" -ForegroundColor Red; exit 1 }

function Refresh-Path {
  $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
              [Environment]::GetEnvironmentVariable("Path", "User")
}
function Is-Installed($id) {
  winget list -e --id $id --accept-source-agreements *> $null
  return ($LASTEXITCODE -eq 0)
}
function Docker-Up {
  if (-not (Get-Command docker -ErrorAction SilentlyContinue)) { return $false }
  docker info *> $null
  return ($LASTEXITCODE -eq 0)
}

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
  Fail "No encuentro winget. Instala 'Instalador de aplicaciones' desde Microsoft Store."
}

if (-not (Is-Installed "Docker.DockerDesktop")) {
  Info "Instalando Docker Desktop (pedirá permisos de administrador)..."
  winget install -e --id Docker.DockerDesktop --accept-package-agreements --accept-source-agreements
  Warn "Docker Desktop usa WSL2. Si te pide reiniciar, reinicia y vuelve a lanzar este script."
} else { Ok "Docker Desktop ya instalado" }

if (-not (Is-Installed "PortSwigger.BurpSuite.Community")) {
  Info "Instalando Burp Suite Community..."
  winget install -e --id PortSwigger.BurpSuite.Community --accept-package-agreements --accept-source-agreements
} else { Ok "Burp Suite ya instalado" }

Refresh-Path

if (-not (Docker-Up)) {
  $exe = Join-Path $env:ProgramFiles "Docker\Docker\Docker Desktop.exe"
  if (Test-Path $exe) { Start-Process $exe }
  Warn "Si es la primera vez, acepta los términos en la ventana de Docker Desktop."
  Info "Esperando a que Docker arranque..."
  for ($i = 0; $i -lt 90 -and -not (Docker-Up); $i++) { Start-Sleep 2 }
  if (-not (Docker-Up)) { Fail "Docker no arranca. Ábrelo a mano y vuelve a lanzar el script." }
}

New-Item -ItemType Directory -Force $CtfDir, $BinDir | Out-Null

if ($Remote) {
  Info "Descargando imagen $Remote..."
  docker pull --platform linux/amd64 $Remote
  if ($LASTEXITCODE -ne 0) { Fail "Fallo al descargar la imagen" }
  docker tag $Remote $Image
} else {
  Info "Construyendo la imagen (la primera vez tarda un rato)..."
  docker build --platform linux/amd64 -t $Image $PSScriptRoot
  if ($LASTEXITCODE -ne 0) { Fail "Fallo al construir la imagen" }
}

# Comando 'ctf' (un .cmd en el PATH que llama al .ps1, así no depende de la ExecutionPolicy)
Copy-Item (Join-Path $PSScriptRoot "ctf.ps1") $BinDir -Force
Set-Content -Path (Join-Path $BinDir "ctf.cmd") -Encoding ASCII `
  -Value '@powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ctf.ps1" %*'

$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -notlike "*$BinDir*") {
  [Environment]::SetEnvironmentVariable("Path", "$userPath;$BinDir", "User")
}

docker rm -f ctf *> $null

Ok "Todo listo."
Write-Host ""
Write-Host "  Carpeta compartida : $CtfDir  <->  /ctf"
Write-Host "  Entrar al entorno  : abre una terminal NUEVA y escribe  ctf"
Write-Host ""
