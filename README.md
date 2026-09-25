# Entorno para el CTF

Con esto te dejas el Mac listo para el CTF. Se instala:

- Burp Suite, para los retos web.
- Docker, con un contenedor Linux que ya trae todo lo de pwn, reversing y cripto.
- Una carpeta compartida entre el Mac y el contenedor, para pasar ficheros de uno a otro.
- El comando `ctf`, para entrar al contenedor sin pelearte con Docker.

Esta guía es para Mac (chip Apple: M1, M2, M3…), que es lo que usamos todos. Si alguien va con Windows o Linux, lo más rápido es que tire de la OVA que os pasamos; montar esto en otro sistema da más guerra de la que merece.

---

## Antes de empezar

- Necesitas unos 15 GB libres.
- Tienes que ser administrador del Mac, porque el instalador pide tu contraseña.

---

## Instalar

Descomprime el zip, abre la Terminal y ejecuta:

```bash
cd ~/Downloads/ctf-kit
chmod +x install.sh uninstall.sh ctf dbg test-entorno.sh
./install.sh
```

Esto hace lo siguiente:

- Instala Homebrew si no lo tienes.
- Instala Docker Desktop y Burp Suite.
- Construye el contenedor con todas las herramientas.
- Crea la carpeta `~/ctf`.
- Deja instalado el comando `ctf`.

### Lo más importante: Docker no arranca solo

Instalar Docker Desktop no basta. Tienes que **abrir la aplicación Docker** (búscala en Launchpad o Spotlight), y la primera vez te va a pedir permisos: te sale una ventana pidiendo tu contraseña para instalar un componente del sistema. **Dale y acepta.** Hasta que no hagas eso y la ballena de la barra de arriba deje de moverse, Docker no funciona y no va nada.

El instalador espera a que Docker arranque, así que si se queda parado ahí, es que le falta que aceptes esos permisos en la ventana de Docker.

### Cuánto tarda

Construir el contenedor tarda 15-20 minutos, porque el Mac tiene que compilar cosas para x86 emulando. Es normal que se quede un buen rato parado en algún paso. No lo cierres.

Si os hemos pasado la imagen ya construida, es cuestión de un par de minutos:

```bash
CTF_REMOTE_IMAGE=ghcr.io/USUARIO/ctf-tools:latest ./install.sh
```

---

## Comprobar que funciona

```bash
cp test-entorno.sh ~/ctf/
ctf bash test-entorno.sh
```

Tiene que acabar en `0 fallos`. Fíjate en el `ctf bash` de delante: si lo lanzas como `./test-entorno.sh`, se ejecuta en el Mac y no en el contenedor, y todo falla. La primera línea pondrá `Modo: emulado`, que es lo normal en estos Mac.

---

## El comando ctf

```bash
ctf                    # entras al contenedor
ctf python3 solve.py   # ejecutas algo dentro sin entrar
ctf root               # entras como root
ctf stop               # lo paras (libera memoria)
ctf reset              # lo borras y se crea limpio la próxima vez
```

Para salir del contenedor, `exit` o `Ctrl+D`. Puedes tener varias terminales con `ctf` abiertas a la vez; todas entran al mismo contenedor.

Dentro eres el usuario `ctf`, que puede usar `sudo` sin contraseña. Sabes que estás dentro porque el prompt pone `ctf:/ctf$`. Si lanzas `ctf` estando dentro de una subcarpeta de `~/ctf`, entras directamente en esa carpeta dentro del contenedor.

---

## La carpeta compartida

`~/ctf` en el Mac y `/ctf` en el contenedor son la misma carpeta. Lo normal es:

1. Descargar el reto con el navegador.
2. Moverlo a `~/ctf/nombre-del-reto`.
3. Abrirlo en Ghidra desde el Mac y ejecutarlo o explotarlo desde el contenedor.

Trabaja siempre dentro de `/ctf`. Lo que guardes en otro sitio del contenedor, como `/home/ctf`, se pierde con `ctf reset` o si reinstalas.

---

## Qué trae el contenedor

Para pwn y reversing:

- `gdb` con GEF, y `dbg`, que se explica abajo.
- `checksec`, `ROPgadget`, `one_gadget`, `seccomp-tools` y `patchelf`.
- `strace` y `ltrace`.
- `objdump`, `readelf`, `strings`, `file` y `xxd`.
- `gcc` (también compila en 32 bits con `-m32`) y `nasm`.
- `qemu` para binarios de otras arquitecturas y `gdb-multiarch` para depurarlos.
- `binwalk`.

Para cripto:

- En Python: pycryptodome, cryptography, gmpy2, sympy, z3 y owiener.
- En consola: RsaCtfTool, factordb, xortool y openssl.

Para contraseñas: `john`, `hashcat` y `hashid`.

Para red y web: `nc`, `socat`, `curl`, `wget`, `sqlmap`, `ping` y `dig`.

Además: `python3`, `ipython`, `tmux`, `vim`, `nano`, `git`, `unzip` y `7z`.

Algunos ejemplos rápidos:

```bash
checksec reto
ROPgadget --binary reto | grep "pop rdi"
one_gadget libc.so.6
seccomp-tools dump ./reto
objdump -d -M intel reto | less
binwalk -e firmware.bin
nc reto.ctf 1337
```

Si el reto te da su propia libc, haz que el binario la use:

```bash
patchelf --set-interpreter ./ld-linux-x86-64.so.2 --set-rpath . ./reto
```

---

## Depurar con gdb

Aquí está lo único que se hace distinto en el Mac, así que léelo con calma.

Como el contenedor va emulado (los retos son x86 y el Mac es ARM), `gdb ./reto` seguido de `run` **no funciona**: bajo emulación GDB no puede controlar el proceso de la forma habitual. Sí puedes usar `gdb` para mirar el binario sin ejecutarlo (`disassemble main`, `info functions`, ver strings…), pero para depurarlo en marcha usa `dbg`:

```bash
dbg ./reto
dbg ./reto argumento1 argumento2
```

`dbg` abre una pantalla partida en dos:

- A la izquierda está el programa. Ahí le escribes la entrada y ves lo que imprime.
- A la derecha está GDB, ya conectado y con el programa parado al principio.

Como el programa ya está arrancado, en vez de `run` usas `c` para continuar. Y si el binario no tiene símbolos (lo normal en los retos), `b main` no vale: pon los breakpoints por dirección.

```
gef➤ b *0x401156
gef➤ c
```

### La línea roja de GEF es normal

Al conectar, GEF suelta un error tipo `Remote I/O error: Invalid argument`. No pasa nada: es GEF intentando leer el mapa de memoria del proceso, que el modo emulado no ofrece. Puedes seguir depurando sin problema. Lo único que no funciona por eso son los comandos de GEF que necesitan ese mapa, como `vmmap` o `heap chunks`. Todo lo demás (breakpoints, `si`/`ni`, registros, ver memoria con `x/`) va bien.

### Anti-debug con ptrace

Si un reto lleva un anti-debug del tipo `ptrace(PTRACE_TRACEME)`, con `dbg` **se salta solo**, porque al depurar así el binario no ve ningún depurador enganchado por ptrace. Así que no te compliques: pruébalo directamente con `dbg`.

### La pantalla partida es tmux

Todo se hace pulsando `Ctrl+b`, soltando, y luego la tecla:

- `Ctrl+b` y una flecha: cambias de lado.
- `Ctrl+b` y `x`: cierras el lado en el que estás.
- `Ctrl+b` y `[`: puedes hacer scroll. Sales con `q`.

Si te sale `Address already in use`, es que tienes otro `dbg` abierto. Ciérralo, o usa otro puerto con `DBG_PORT=1235 dbg ./reto`.

Para ver las syscalls (`strace`/`ltrace` no funcionan en modo emulado):

```bash
qemu-x86_64 -strace ./reto
```

Comandos de GDB y GEF que vas a usar mucho:

```
b *0x401156        breakpoint en una dirección
c                  continuar
ni / si            siguiente instrucción (si entra en los call)
finish             sales de la función actual
x/20gx $rsp        ves la pila
x/s 0x402004       ves una cadena
info registers
context            vista de GEF: registros, pila y código
pattern create 200 generas un patrón para calcular offsets
pattern search $rsp buscas el offset donde se ha pisado
got                ves la GOT
```

---

## Pwntools

Plantilla lista para el modo emulado del Mac:

```python
from pwn import *
import os

elf = context.binary = ELF("./reto")
context.terminal = ["tmux", "splitw", "-h"]

def start():
    if args.REMOTE:
        return remote("reto.ctf", 1337)
    if args.GDB:
        # en el Mac emulado gdb.debug() no vale, se usa qemu -g
        p = process(["qemu-x86_64", "-g", "1234", elf.path])
        gdb.attach(("127.0.0.1", 1234), exe=elf.path, gdbscript="c")
        return p
    return process(elf.path)

p = start()
p.sendline(b"A" * 40 + p64(elf.sym.win))
p.interactive()
```

```bash
python3 solve.py          # en local
python3 solve.py GDB      # en local con GDB
python3 solve.py REMOTE   # contra el servidor
```

Si usas la opción `GDB`, lanza primero `tmux` y ejecuta el script desde dentro, porque pwntools abre GDB en un panel al lado.

---

## Cripto

RSA cuando consigues factorizar n:

```python
from Crypto.Util.number import long_to_bytes
import gmpy2

d = gmpy2.invert(e, (p - 1) * (q - 1))
print(long_to_bytes(pow(c, d, n)))
```

Si e es 3 y no hay padding:

```python
m, exacto = gmpy2.iroot(c, 3)
if exacto:
    print(long_to_bytes(int(m)))
```

Si d es pequeño, el ataque de Wiener:

```python
import owiener
d = owiener.attack(e, n)   # None si no sale
```

Para leer una clave `.pem`:

```python
from Crypto.PublicKey import RSA
key = RSA.import_key(open("key.pub").read())
print(key.n, key.e)
```

Cuando no sabes por dónde tirar, RsaCtfTool prueba muchos ataques de golpe:

```bash
RsaCtfTool --publickey key.pub --private
RsaCtfTool -h
```

Otras herramientas de consola:

```bash
factordb 1234567890123456789   # busca si n ya está factorizado
xortool cifrado.bin            # XOR con clave repetida: estima la longitud de la clave
xortool -c 20 cifrado.bin      # suponiendo que el carácter más repetido es el espacio
```

z3, para cuando tienes un montón de condiciones y quieres la entrada que las cumple:

```python
from z3 import *
x = BitVec("x", 32)
s = Solver()
s.add((x ^ 0x1337) + 5 == 0xdeadbeef)
if s.check() == sat:
    print(hex(s.model()[x].as_long()))
```

---

## Contraseñas y hashes

```bash
hashid '$2y$10$...'                           # qué tipo de hash es
john --wordlist=wordlist.txt hashes.txt
john --show hashes.txt
hashcat -m 0 -a 0 hashes.txt wordlist.txt     # -m 0 es MD5
```

Dos avisos:

- No viene ningún diccionario. Si necesitas rockyou, descárgalo en `~/ctf`.
- En el contenedor hashcat solo usa CPU y va lento. Si te toca crackear algo serio, instálalo en el Mac para que use la gráfica.

---

## Burp Suite

Burp se instala en el Mac, no en el contenedor. Ábrelo y pulsa "Temporary project", luego "Use Burp defaults" y "Start Burp".

Lo más cómodo es usar el navegador que trae el propio Burp: pestaña Proxy → Intercept → "Open browser". Todo lo que hagas ahí pasa por Burp, también HTTPS, sin configurar nada.

Lo que más vas a usar:

- **Intercept.** Si está en "on", cada petición se queda parada hasta que le das a Forward. Normalmente lo tendrás en "off".
- **HTTP history.** Todo lo que ha pasado por Burp.
- **Repeater.** Clic derecho en una petición → "Send to Repeater", o `Ctrl+R`. Sirve para modificarla y reenviarla las veces que quieras.
- **Intruder.** Para fuerza bruta. En la versión gratuita va lento a propósito.
- **Decoder.** Base64, URL encoding, hex…

### Pasar tráfico del contenedor por Burp

Desde el contenedor, Burp está en `host.docker.internal:8080`:

```bash
curl -x http://host.docker.internal:8080 http://reto.ctf/
sqlmap -u "http://reto.ctf/item?id=1" --proxy=http://host.docker.internal:8080 --batch
```

```python
import requests
proxy = "http://host.docker.internal:8080"
r = requests.get("https://reto.ctf/", proxies={"http": proxy, "https": proxy}, verify=False)
```

Con HTTPS usa `curl -k` o `verify=False`, porque el contenedor no se fía del certificado de Burp.

---

## Ghidra

Ghidra no va en el contenedor porque es una aplicación con ventanas, y además en el Mac corre nativa, que va mucho mejor. Se instala aparte y abres los binarios directamente desde `~/ctf`:

```bash
brew install --cask temurin@21
brew install --cask ghidra
```

Para empezar a usarlo:

1. File → New Project.
2. File → Import File, y eliges el binario.
3. Doble clic en el binario y aceptas cuando pregunte si quieres analizarlo.
4. A la izquierda, en Symbol Tree → Functions, buscas `main`. A la derecha tienes el código decompilado.
5. Con la `L` renombras variables y funciones, lo que ayuda mucho a entender el código.

La forma de trabajar suele ser: entiendes el binario en Ghidra, lo ves en ejecución con `dbg` y escribes el exploit con pwntools.

---

## Instalar algo más en el contenedor

```bash
sudo apt update && sudo apt install -y paquete
pip install paquete
```

Se pierde con `ctf reset` o al reinstalar. Si echas algo en falta de verdad, dínoslo y lo metemos en la imagen.

---

## Si algo falla

**`Cannot connect to the Docker daemon`**
Docker no está arrancado. Abre la aplicación Docker y espera a que la ballena de la barra de arriba se quede quieta. Si es la primera vez, acepta los permisos que te pide.

**El instalador se queda parado esperando a Docker**
Le falta que aceptes los permisos en la ventana de Docker Desktop. Ábrela y acepta.

**`ctf: command not found`**
Vuelve a lanzar `./install.sh`.

**`"/motd": not found` al instalar**
Te falta algún fichero. Descomprime el zip entero y lanza el instalador desde dentro de la carpeta.

**El test da un montón de fallos y pone `Modo: nativo`**
Lo has lanzado fuera del contenedor. Tiene que ser `ctf bash test-entorno.sh`.

**`run` no funciona en gdb**
Es normal en el Mac. Usa `dbg`.

**En `dbg` sale una línea roja de GEF**
Es cosmético, puedes seguir depurando. Lo único que no va es `vmmap` y `heap`.

**`./reto: Permission denied`**
Ejecuta `chmod +x reto`.

**No llegan peticiones a Burp**
Comprueba que Burp está abierto y escuchando en el 8080.

**Todo va raro**
Ejecuta `ctf reset` y vuelve a entrar. Lo que tengas en `~/ctf` no se toca.

---

## Desinstalar

```bash
./uninstall.sh
```

Va preguntando antes de borrar cada cosa: el contenedor, el comando `ctf`, la carpeta `~/ctf`, Burp, Docker y Homebrew. Con `./uninstall.sh -y` no pregunta, salvo para `~/ctf` y Homebrew, que siempre preguntan.

Ojo con desinstalar Docker: se borran todos tus contenedores, no solo el del CTF.

---

## Para la organización

Qué hay en el kit:

| Fichero | Para qué sirve |
|---|---|
| `install.sh`, `uninstall.sh` | Instalador y desinstalador |
| `install.ps1`, `ctf.ps1` | Versión Windows, por si acaso (no la usamos) |
| `ctf` | El comando `ctf` |
| `Dockerfile` | La imagen con las herramientas |
| `dbg`, `motd` | Van dentro de la imagen |
| `test-entorno.sh` | El test |
| `.gitattributes` | Evita que Git rompa los scripts con finales de línea CRLF |

Para que la gente no tenga que construir la imagen (20 minutos en cada Mac), publícala una vez:

```bash
docker login ghcr.io
docker build --platform linux/amd64 -t ghcr.io/USUARIO/ctf-tools:latest .
docker push ghcr.io/USUARIO/ctf-tools:latest
```

Notas:

- Para el login usas tu usuario de GitHub y un token con permiso `write:packages`.
- Luego, en GitHub → Packages → ctf-tools → Package settings, cámbiala a pública.
- Después, a los participantes les pasas el comando con `CTF_REMOTE_IMAGE`.

Si hay que añadir herramientas: editas el `Dockerfile`, reconstruyes, subes la imagen y pides que relancen el instalador.

Detalles por si alguien pregunta:

- La imagen es Ubuntu 24.04 y siempre `linux/amd64`, igual que los servidores de retos.
- Python va en un venv en `/opt/venv`.
- El usuario `ctf` tiene UID 1000.
- El contenedor arranca con `SYS_PTRACE` y sin seccomp para que GDB funcione.
- En los Mac (ARM) se pasa la variable `CTF_EMULATED=1`, y `dbg` la usa para cambiar al modo QEMU.
