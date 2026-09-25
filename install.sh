#!/usr/bin/env bash
# Instalador del entorno CTF para macOS y Linux
#   ./install.sh
# Si el organizador ha publicado la imagen ya construida (mucho más rápido):
#   CTF_REMOTE_IMAGE=ghcr.io/usuario/ctf-tools:latest ./install.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
IMAGE="ctf-tools:latest"
CTF_DIR="$HOME/ctf"
REMOTE_IMAGE="${CTF_REMOTE_IMAGE:-}"
DOCKER="docker"

info() { printf '\033[1;34m[*]\033[0m %s\n' "$*"; }
ok()   { printf '\033[1;32m[+]\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m[!]\033[0m %s\n' "$*"; }
err()  { printf '\033[1;31m[x]\033[0m %s\n' "$*"; exit 1; }

wait_docker() {
  info "Esperando a que Docker arranque..."
  for _ in $(seq 1 90); do
    docker info >/dev/null 2>&1 && return 0
    sleep 2
  done
  return 1
}

install_macos() {
  if ! command -v brew >/dev/null 2>&1; then
    info "Instalando Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    if [ -x /opt/homebrew/bin/brew ]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
    else
      eval "$(/usr/local/bin/brew shellenv)"
    fi
  fi

  if [ ! -d "/Applications/Docker.app" ]; then
    info "Instalando Docker Desktop..."
    brew install --cask docker-desktop || brew install --cask docker
  else
    ok "Docker Desktop ya instalado"
  fi

  if ! ls -d /Applications/Burp\ Suite*.app >/dev/null 2>&1; then
    info "Instalando Burp Suite Community..."
    brew install --cask burp-suite
  else
    ok "Burp Suite ya instalado"
  fi

  export PATH="$PATH:$HOME/.docker/bin:/Applications/Docker.app/Contents/Resources/bin"
  if ! docker info >/dev/null 2>&1; then
    open -a Docker
    warn "Si es la primera vez, acepta los términos en la ventana de Docker Desktop."
    wait_docker || err "Docker no arranca. Ábrelo a mano y vuelve a lanzar ./install.sh"
  fi
}

install_linux() {
  if ! command -v docker >/dev/null 2>&1; then
    info "Instalando Docker Engine..."
    curl -fsSL https://get.docker.com | sudo sh
  else
    ok "Docker ya instalado"
  fi
  sudo systemctl enable --now docker >/dev/null 2>&1 || true

  if ! id -nG "$USER" | grep -qw docker; then
    sudo usermod -aG docker "$USER"
    warn "Te he añadido al grupo docker. Cierra sesión y vuelve a entrar para no necesitar sudo."
  fi
  docker info >/dev/null 2>&1 || DOCKER="sudo docker"

  if ! command -v BurpSuiteCommunity >/dev/null 2>&1 && [ ! -d "$HOME/BurpSuiteCommunity" ]; then
    info "Instalando Burp Suite Community..."
    case "$(uname -m)" in
      aarch64|arm64) BTYPE="LinuxArm64" ;;
      *)             BTYPE="Linux" ;;
    esac
    tmp="$(mktemp --suffix=.sh)"
    curl -fL "https://portswigger.net/burp/releases/download?product=community&type=$BTYPE" -o "$tmp"
    sh "$tmp" -q
    rm -f "$tmp"
  else
    ok "Burp Suite ya instalado"
  fi
}

case "$(uname -s)" in
  Darwin) install_macos ;;
  Linux)  install_linux ;;
  *)      err "Sistema no soportado. En Windows usa install.ps1" ;;
esac

mkdir -p "$CTF_DIR"

if [ -n "$REMOTE_IMAGE" ]; then
  info "Descargando imagen $REMOTE_IMAGE..."
  $DOCKER pull --platform linux/amd64 "$REMOTE_IMAGE"
  $DOCKER tag "$REMOTE_IMAGE" "$IMAGE"
else
  info "Construyendo la imagen (la primera vez tarda; en Mac con chip Apple bastante más)..."
  $DOCKER build --platform linux/amd64 -t "$IMAGE" "$SCRIPT_DIR"
fi

info "Instalando el comando 'ctf' en /usr/local/bin (pide contraseña)..."
sudo mkdir -p /usr/local/bin
sudo install -m 0755 "$SCRIPT_DIR/ctf" /usr/local/bin/ctf

# Si ya existía un contenedor, se recrea con la imagen nueva (~/ctf no se toca)
$DOCKER rm -f ctf >/dev/null 2>&1 || true

ok "Todo listo."
echo
echo "  Carpeta compartida : $CTF_DIR  <->  /ctf"
echo "  Entrar al entorno  : ctf"
echo "  Burp Suite         : ya instalado en tus aplicaciones"
echo
