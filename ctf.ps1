# Lanzador del entorno CTF (Windows)
#   ctf              -> entra al contenedor
#   ctf <comando>    -> ejecuta un comando dentro (p.ej. ctf python3 solve.py)
#   ctf root | stop | reset | help

$Rest   = @($args)
$Image  = "ctf-tools:latest"
$Name   = "ctf"
$CtfDir = Join-Path $env:USERPROFILE "ctf"
$Emu    = if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "1" } else { "0" }

function Ensure-Running {
  New-Item -ItemType Directory -Force $CtfDir | Out-Null
  docker container inspect $Name *> $null
  if ($LASTEXITCODE -ne 0) {
    docker run -d --name $Name --hostname ctf --init --platform linux/amd64 `
      --cap-add=SYS_PTRACE --security-opt seccomp=unconfined `
      --add-host=host.docker.internal:host-gateway `
      -e CTF_EMULATED=$Emu -v "${CtfDir}:/ctf" -w /ctf `
      $Image sleep infinity | Out-Null
  } elseif ((docker inspect -f '{{.State.Running}}' $Name) -ne "true") {
    docker start $Name | Out-Null
  }
}

$cmd = if ($Rest.Count -gt 0) { $Rest[0] } else { "shell" }

switch ($cmd) {
  "shell" { Ensure-Running; docker exec -it -w /ctf $Name bash }
  "root"  { Ensure-Running; docker exec -it -u root -w /ctf $Name bash }
  "stop"  { docker stop $Name | Out-Null; Write-Host "Contenedor parado" }
  "reset" { docker rm -f $Name *> $null; Write-Host "Contenedor borrado (lo que haya en $CtfDir sigue ahí)" }
  "help"  { Get-Content $PSCommandPath -TotalCount 5 | Select-Object -Skip 1 }
  default { Ensure-Running; docker exec -it -w /ctf $Name @Rest }
}
