#!/usr/bin/env bash
# Desinstalador del entorno CTF para macOS y Linux
#   ./uninstall.sh       -> pregunta antes de borrar cada cosa
#   ./uninstall.sh -y    -> borra todo sin preguntar (menos Homebrew y ~/ctf)
set -uo pipefail

IMAGE="ctf-tools:latest"
NAME="ctf"
CTF_DIR="$HOME/ctf"
YES=0; [ "${1:-}" = "-y" ] && YES=1

info() { printf '\033[1;34m[*]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[+]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }

# confirm "pregunta" [forzar_pregunta]
confirm() {
  if [ "$YES" = 1 ] && [ -z "${2:-}" ]; then return 0; fi
  read -r -p "$1 [s/N] " r
  [[ "$r" =~ ^[sSyY]$ ]]
}

OS="$(uname -s)"
DOCKER="docker"
docker info >/dev/null 2>&1 || DOCKER="sudo docker"
export PATH="$PATH:$HOME/.docker/bin:/Applications/Docker.app/Contents/Resources/bin"

# --- 1. Contenedor e imagen -------------------------------------------------
if command -v docker >/dev/null 2>&1 && $DOCKER info >/dev/null 2>&1; then
  if confirm "¿Borrar el contenedor y la imagen del CTF?"; then
    $DOCKER rm -f "$NAME" >/dev/null 2>&1 && ok "Contenedor borrado"
    $DOCKER rmi -f "$IMAGE" >/dev/null 2>&1 && ok "Imagen borrada"
    $DOCKER image prune -f >/dev/null 2>&1
    $DOCKER builder prune -af >/dev/null 2>&1 && ok "Caché de build limpiada"
  fi
else
  warn "Docker no está arrancado: no puedo borrar contenedor ni imagen (si vas a desinstalar Docker da igual)"
fi

# --- 2. Comando ctf ---------------------------------------------------------
if [ -f /usr/local/bin/ctf ] && confirm "¿Borrar el comando 'ctf'?"; then
  sudo rm -f /usr/local/bin/ctf && ok "Comando ctf borrado"
fi

# --- 3. Carpeta compartida (siempre pregunta: son tus ficheros) -------------
if [ -d "$CTF_DIR" ] && confirm "¿Borrar $CTF_DIR con TODO su contenido?" force; then
  rm -rf "$CTF_DIR" && ok "$CTF_DIR borrada"
fi

# --- 4. Burp Suite ----------------------------------------------------------
if confirm "¿Desinstalar Burp Suite?"; then
  if [ "$OS" = "Darwin" ]; then
    if command -v brew >/dev/null 2>&1 && brew list --cask burp-suite >/dev/null 2>&1; then
      brew uninstall --cask --zap burp-suite
    else
      sudo rm -rf /Applications/Burp\ Suite*.app
    fi
    rm -rf "$HOME/.BurpSuite"
  else
    if [ -x "$HOME/BurpSuiteCommunity/uninstall" ]; then
      "$HOME/BurpSuiteCommunity/uninstall" -q
    fi
    rm -rf "$HOME/BurpSuiteCommunity" "$HOME/.BurpSuite"
  fi
  ok "Burp Suite desinstalado"
fi

# --- 5. Docker --------------------------------------------------------------
if confirm "¿Desinstalar Docker? (se pierden TODOS tus contenedores e imágenes, no solo los del CTF)"; then
  if [ "$OS" = "Darwin" ]; then
    osascript -e 'quit app "Docker"' >/dev/null 2>&1; sleep 3
    if command -v brew >/dev/null 2>&1 && brew list --cask docker-desktop >/dev/null 2>&1; then
      brew uninstall --cask --zap docker-desktop
    elif command -v brew >/dev/null 2>&1 && brew list --cask docker >/dev/null 2>&1; then
      brew uninstall --cask --zap docker
    elif [ -x /Applications/Docker.app/Contents/MacOS/uninstall ]; then
      /Applications/Docker.app/Contents/MacOS/uninstall
      sudo rm -rf /Applications/Docker.app
    fi
    rm -rf "$HOME/.docker" \
           "$HOME/Library/Containers/com.docker.docker" \
           "$HOME/Library/Group Containers/group.com.docker" \
           "$HOME/Library/Application Support/Docker Desktop"
  else
    sudo systemctl disable --now docker docker.socket containerd >/dev/null 2>&1
    PKGS="docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin docker-ce-rootless-extras"
    if command -v apt-get >/dev/null 2>&1; then
      sudo apt-get purge -y $PKGS && sudo apt-get autoremove -y
    elif command -v dnf >/dev/null 2>&1; then
      sudo dnf remove -y $PKGS
    fi
    sudo rm -rf /var/lib/docker /var/lib/containerd /etc/docker "$HOME/.docker"
    sudo gpasswd -d "$USER" docker >/dev/null 2>&1
  fi
  ok "Docker desinstalado"
fi

# --- 6. Homebrew (solo macOS, siempre pregunta) -----------------------------
if [ "$OS" = "Darwin" ] && command -v brew >/dev/null 2>&1; then
  if confirm "¿Desinstalar también Homebrew? (borra TODO lo instalado con brew, no solo lo del CTF)" force; then
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/uninstall.sh)"
  fi
fi

echo
ok "Desinstalación terminada"
