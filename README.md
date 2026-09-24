# Entorno para el CTF

Con esto te dejas el ordenador listo para el CTF. Se instala:

- Burp Suite, para los retos web.
- Docker, con un contenedor Linux que ya trae todo lo de pwn, reversing y cripto.
- Una carpeta compartida entre tu ordenador y el contenedor, para pasar ficheros de uno a otro.
- El comando `ctf`, para entrar al contenedor sin pelearte con Docker.

La guía empieza por Mac. Si usas Windows, salta a [Windows](#windows); si usas Linux, a [Linux](#linux). A partir de [Usando el entorno](#usando-el-entorno) es igual para todos.

---

## Mac

Sirve tanto para Mac con chip Apple (M1, M2, M3…) como para los antiguos con Intel.

Antes de empezar:

- Necesitas unos 15 GB libres.
- Tienes que ser administrador del Mac, porque el instalador pide tu contraseña. Si es un portátil de empresa o de la uni, puede que no te deje.

### Instalar

Descomprime el zip, abre la Terminal y ejecuta:

```bash
cd ~/Downloads/ctf-kit
chmod +x install.sh uninstall.sh ctf dbg test-entorno.sh
./install.sh
```

Esto hace lo siguiente:

- Instala Homebrew si no lo tienes.
- Instala Docker Desktop y Burp Suite.
- Construye el contenedor.
- Crea la carpeta `~/ctf`.
- Deja instalado el comando `ctf`.

Durante la instalación:

- La primera vez se abre Docker Desktop y tienes que aceptar sus términos. El script se queda esperando hasta que arranca, no lo cierres.
- Construir el contenedor tarda un rato: 5-10 minutos en un Mac Intel y 15-20 en uno con chip Apple. Es normal que se quede parado en algún paso.
- Si la organización os ha pasado una imagen ya construida, es mucho más rápido:

  ```bash
  CTF_REMOTE_IMAGE=ghcr.io/USUARIO/ctf-tools:latest ./install.sh
  ```

### Comprobar que funciona

```bash
cp test-entorno.sh ~/ctf/
ctf bash test-entorno.sh
```

Tiene que acabar en `0 fallos`. Fíjate en que se lanza con `ctf bash` delante: si lo ejecutas como `./test-entorno.sh`, se ejecuta en el Mac y no en el contenedor, y todo falla.

En un Mac con chip Apple la primera línea pondrá `Modo: emulado`. Es lo esperado; más abajo se explica qué significa.

### Desinstalar

```bash
./uninstall.sh
```

Va preguntando antes de borrar cada cosa: el contenedor, el comando `ctf`, la carpeta `~/ctf`, Burp, Docker y Homebrew. Con `./uninstall.sh -y` no pregunta, salvo para la carpeta `~/ctf` y para Homebrew, que siempre preguntan porque puedes tener cosas tuyas ahí.

Ojo con desinstalar Docker: se borran todos tus contenedores, no solo el del CTF.

---

## Windows

Necesitas Windows 10 u 11, ser administrador y unos 15 GB libres. Docker en Windows funciona sobre WSL2; si no lo tienes activado, lo activa el instalador de Docker, pero puede pedirte reiniciar.

### Instalar

Abre PowerShell en la carpeta del kit y ejecuta:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

Instala Docker Desktop y Burp Suite con `winget`, construye el contenedor, crea `C:\Users\TU_USUARIO\ctf` y añade el comando `ctf`.

- Si Docker te pide reiniciar, reinicia y vuelve a lanzar el script. Lo que ya esté instalado se lo salta.
- Cuando acabe, cierra PowerShell y abre uno nuevo. Si no, el comando `ctf` no aparece.
- Si te dice que no encuentra `winget`, instala "Instalador de aplicaciones" desde la Microsoft Store.

Con imagen ya construida:

```powershell
$env:CTF_REMOTE_IMAGE="ghcr.io/USUARIO/ctf-tools:latest"
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

### Comprobar que funciona

Copia `test-entorno.sh` a `C:\Users\TU_USUARIO\ctf` y ejecuta:

```powershell
ctf bash test-entorno.sh
```

Tiene que acabar en `0 fallos`.

### Diferencias con Mac

- La carpeta compartida es `C:\Users\TU_USUARIO\ctf`.
- `gdb` funciona directamente, sin el lío del modo emulado de los Mac con chip Apple. `dbg` también vale.
- Si lanzas `ctf` desde una subcarpeta, entras en `/ctf`, no en la subcarpeta. En Mac sí te lleva a la subcarpeta.
- No hay desinstalador. Quita Docker Desktop y Burp Suite desde Configuración → Aplicaciones, y borra `C:\Users\TU_USUARIO\.ctf`.

---

## Linux

```bash
chmod +x install.sh uninstall.sh ctf dbg test-entorno.sh
./install.sh
```

Instala Docker Engine, Burp Suite (en `~/BurpSuiteCommunity`), el contenedor y el comando `ctf`.

- Al acabar, cierra sesión y vuelve a entrar para poder usar Docker sin `sudo`. Mientras tanto `ctf` funciona igual, pero te pedirá contraseña.
- Para comprobar que funciona y para desinstalar, es igual que en Mac.
- Para que el contenedor pueda mandar tráfico a Burp, en Burp tienes que poner el proxy escuchando en todas las interfaces. Se explica en el apartado de Burp.

---

## Usando el entorno

### El comando ctf

```bash
ctf                    # entras al contenedor
ctf python3 solve.py   # ejecutas algo dentro sin entrar
ctf root               # entras como root
ctf stop               # lo paras (libera memoria)
ctf reset              # lo borras y se crea limpio la próxima vez
```

Para salir del contenedor, `exit` o `Ctrl+D`. Puedes tener varias terminales con `ctf` abiertas a la vez; todas entran al mismo contenedor.

Dentro eres el usuario `ctf`, que puede usar `sudo` sin contraseña. Sabes que estás dentro porque el prompt pone `ctf:/ctf$`.

### La carpeta compartida

`~/ctf` en tu ordenador y `/ctf` en el contenedor son la misma carpeta. Lo normal es:

1. Descargar el reto con el navegador.
2. Moverlo a `~/ctf/nombre-del-reto`.
3. Abrirlo en Ghidra desde tu ordenador y ejecutarlo o explotarlo desde el contenedor.

Trabaja siempre dentro de `/ctf`. Lo que guardes en otro sitio del contenedor, como `/home/ctf`, se pierde con `ctf reset` o si reinstalas.

### Qué trae el contenedor

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

Aquí está la única diferencia importante entre ordenadores.

En Windows, Linux y Mac Intel, `gdb` funciona como siempre:

```bash
gdb ./reto
```

Dentro pones tus breakpoints y lanzas el programa con `run`.

En Mac con chip Apple, `gdb` no puede ejecutar el programa. Los binarios de los retos son x86 y tu Mac es ARM, así que el contenedor va emulado, y con la emulación GDB pierde la forma de controlar el proceso. Puedes seguir usando `gdb` para mirar el binario sin ejecutarlo (`disassemble main`, `info functions`…), pero `run` no funciona.

Para eso está `dbg`:

```bash
dbg ./reto
dbg ./reto argumento1 argumento2
```

En Windows, Linux y Mac Intel, `dbg` simplemente abre `gdb`. En Mac con chip Apple abre una pantalla partida en dos:

- A la izquierda está el programa. Ahí le escribes la entrada y ves lo que imprime.
- A la derecha está GDB, ya conectado y con el programa parado al principio.

Como el programa ya está arrancado, en vez de `run` usas `c`:

```
gef➤ break main
gef➤ c
```

La pantalla partida es tmux. Todo se hace pulsando `Ctrl+b`, soltando, y luego la tecla:

- `Ctrl+b` y una flecha: cambias de lado.
- `Ctrl+b` y `x`: cierras el lado en el que estás.
- `Ctrl+b` y `[`: puedes hacer scroll. Sales con `q`.

Si te sale `Address already in use`, es que tienes otro `dbg` abierto. Ciérralo, o usa otro puerto con `DBG_PORT=1235 dbg ./reto`.

En Mac con chip Apple tampoco funcionan `strace` ni `ltrace`, por el mismo motivo. Para ver las syscalls usa:

```bash
qemu-x86_64 -strace ./reto
```

Algunos comandos de GDB y GEF que vas a usar mucho:

```
break main         breakpoint en main
b *0x401156        breakpoint en una dirección
ni / si            siguiente instrucción (si entra en los call)
finish             sales de la función actual
x/20gx $rsp        ves la pila
x/s 0x402004       ves una cadena
context            vista completa de GEF: registros, pila y código
vmmap              mapa de memoria
pattern create 200 generas un patrón para calcular offsets
pattern search $rsp buscas el offset donde se ha pisado
heap chunks        ves el heap
got                ves la GOT
```

---

## Pwntools

Una plantilla que funciona en cualquier ordenador, también en Mac con chip Apple:

```python
from pwn import *
import os

elf = context.binary = ELF("./reto")
context.terminal = ["tmux", "splitw", "-h"]

def start():
    if args.REMOTE:
        return remote("reto.ctf", 1337)
    if args.GDB:
        if os.environ.get("CTF_EMULATED") == "1":   # Mac con chip Apple
            p = process(["qemu-x86_64", "-g", "1234", elf.path])
            gdb.attach(("127.0.0.1", 1234), exe=elf.path, gdbscript="c")
            return p
        return gdb.debug(elf.path, gdbscript="c")
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

Ten en cuenta dos cosas:

- No viene ningún diccionario. Si necesitas rockyou, descárgalo en `~/ctf`.
- En el contenedor hashcat solo usa CPU y va lento. Si te toca crackear algo serio, instálalo en tu ordenador para que use la gráfica.

---

## Burp Suite

Burp se instala en tu ordenador, no en el contenedor. Ábrelo y pulsa "Temporary project", luego "Use Burp defaults" y "Start Burp".

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

En Linux, además, tienes que ir a Proxy → Proxy settings, editar el listener y poner "All interfaces". En Mac y Windows no hace falta.

---

## Ghidra

Ghidra no va en el contenedor porque es una aplicación con ventanas. Se instala en tu ordenador y abres los binarios directamente desde `~/ctf`.

En Mac:

```bash
brew install --cask temurin@21
brew install --cask ghidra
```

En Windows:

1. Instala Java con `winget install EclipseAdoptium.Temurin.21.JDK`.
2. Descarga el zip de la última versión de <https://github.com/NationalSecurityAgency/ghidra/releases>.
3. Descomprímelo y abre `ghidraRun.bat`.

En Linux:

1. Instala Java con `sudo apt install openjdk-21-jdk`.
2. Descarga el mismo zip.
3. Descomprímelo y ejecuta `./ghidraRun`.

Para empezar a usarlo:

1. File → New Project.
2. File → Import File, y eliges el binario.
3. Doble clic en el binario y aceptas cuando pregunte si quieres analizarlo.
4. A la izquierda, en Symbol Tree → Functions, buscas `main`. A la derecha tienes el código decompilado.
5. Con la `L` renombras variables y funciones, lo que ayuda muchísimo a entender el código.

La forma de trabajar suele ser: entiendes el binario en Ghidra, lo ves en ejecución con `dbg` y escribes el exploit con pwntools.

---

## Instalar algo más en el contenedor

```bash
sudo apt update && sudo apt install -y paquete
pip install paquete
```

Se pierde con `ctf reset` o al reinstalar. Si echas algo en falta de verdad, díselo a la organización para que lo metan en la imagen.

---

## Si algo falla

**`Cannot connect to the Docker daemon`**
Docker no está arrancado. Abre Docker Desktop y espera a que el icono de la ballena se quede quieto. En Linux, ejecuta `sudo systemctl start docker`.

**`ctf: command not found`**
En Windows, abre una terminal nueva. En Mac o Linux, vuelve a lanzar `./install.sh`.

**`"/motd": not found` al instalar**
Te falta algún fichero. Descarga el zip entero y lanza el instalador desde dentro de la carpeta.

**El test da un montón de fallos y pone `Modo: nativo` en un Mac**
Lo has lanzado fuera del contenedor. Tiene que ser `ctf bash test-entorno.sh`.

**`run` no funciona en gdb**
Si tienes un Mac con chip Apple es normal. Usa `dbg`.

**`./reto: Permission denied`**
Ejecuta `chmod +x reto`.

**No llegan peticiones a Burp**
Comprueba que Burp está abierto y escuchando en el 8080. En Linux, revisa lo de "All interfaces".

**En Windows no se ejecuta el script**
Lánzalo exactamente como pone arriba, con `-ExecutionPolicy Bypass`.

**Todo va raro**
Ejecuta `ctf reset` y vuelve a entrar. Lo que tengas en `~/ctf` no se toca.

---

Algunos detalles:

- La imagen es Ubuntu 24.04 y siempre `linux/amd64`, igual que los servidores de retos.
- Python va en un venv en `/opt/venv`.
- El usuario `ctf` tiene UID 1000.
- El contenedor arranca con `SYS_PTRACE` y sin seccomp para que GDB funcione.
- En ordenadores ARM se pasa la variable `CTF_EMULATED=1`, y `dbg` la usa para cambiar al modo QEMU.
