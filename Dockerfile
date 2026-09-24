# Imagen con las herramientas del CTF (siempre x86_64, igual que los retos)
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    PATH=/opt/venv/bin:$PATH

# --- Paquetes del sistema ---------------------------------------------------
RUN apt-get update && apt-get install -y --no-install-recommends \
      build-essential gcc-multilib g++-multilib \
      gdb gdb-multiarch qemu-user \
      strace ltrace patchelf nasm binutils elfutils file xxd \
      python3 python3-dev python3-venv python3-pip \
      libgmp-dev libmpfr-dev libmpc-dev libssl-dev libffi-dev \
      ruby ruby-dev \
      john hashcat pocl-opencl-icd openssl binwalk \
      git curl wget ca-certificates unzip p7zip-full \
      vim nano tmux less sudo \
      netcat-openbsd socat iputils-ping dnsutils \
    && rm -rf /var/lib/apt/lists/*

# --- Python: pwn + cripto (en un venv para no pelearse con PEP 668) ----------
RUN python3 -m venv /opt/venv \
 && pip install --no-cache-dir --upgrade pip wheel \
 && pip install --no-cache-dir \
      pwntools ropgadget \
      pycryptodome cryptography gmpy2 sympy z3-solver \
      owiener factordb-pycli xortool hashid \
      requests sqlmap ipython

# RsaCtfTool (si falla no rompe la build)
RUN pip install --no-cache-dir git+https://github.com/RsaCtfTool/RsaCtfTool.git \
 || echo "[!] RsaCtfTool no se ha podido instalar, se continúa sin él"

# --- Ruby: gadgets y seccomp -------------------------------------------------
RUN gem install --no-document one_gadget seccomp-tools

# --- Usuario sin privilegios (UID 1000 para que en Linux los ficheros sean tuyos)
RUN userdel -r ubuntu 2>/dev/null || true \
 && useradd -m -u 1000 -s /bin/bash ctf \
 && echo "ctf ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/ctf \
 && mkdir -p /ctf && chown ctf:ctf /ctf

COPY dbg /usr/local/bin/dbg
COPY motd /etc/motd-ctf
# Por si alguien lo clona en Windows con finales de línea CRLF
RUN sed -i 's/\r$//' /usr/local/bin/dbg /etc/motd-ctf && chmod +x /usr/local/bin/dbg

USER ctf
WORKDIR /home/ctf

# GDB + GEF
RUN wget -qO ~/.gef.py https://raw.githubusercontent.com/hugsy/gef/main/gef.py \
 && echo "source ~/.gef.py" >> ~/.gdbinit \
 && printf '%s\n' \
      'export PS1="\[\e[1;31m\]ctf\[\e[0m\]:\[\e[1;34m\]\w\[\e[0m\]\$ "' \
      '[ -z "$TMUX" ] && cat /etc/motd-ctf' >> ~/.bashrc

WORKDIR /ctf
CMD ["bash"]
