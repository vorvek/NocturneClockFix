# Nocturne Clock Fix

*[Read in English](README.md)*

Un pequeño parche para **Nocturne** (Terminal Reality, 1999). Elimina los bloqueos largos de los menús en
los PC modernos, y hace que la física de las telas se asiente cuando un personaje está quieto. Una sola
instalación aplica las dos correcciones.

## Los problemas

### Bloqueos de los menús
En un PC moderno, Nocturne se queda bloqueado a menudo entre 5 y 20 segundos, (si tienes mala suerte igual estás esperando 2 minutos):

- en el menú principal y sus pantallas,
- entre el vídeo de introducción y el menú principal,
- en los menús durante la partida.

Durante un bloqueo, un núcleo de la CPU trabaja al 100 %. Los bloqueos son aleatorios: ocurren a menudo,
pero no siempre.

**Por qué:** el juego cuenta el tiempo en pasos diminutos, y en muchos menús espera al siguiente paso. Cada
vez que lee el reloj, descarta la fracción de paso. En un PC de 1999, cada lectura tardaba lo suficiente
para contar, pero una CPU moderna es tan rápida que cada lectura cuenta como 0 (menos de un microsegundo, redondeado), y el reloj del juego se para.
El juego espera entonces en un bucle hasta que, por casualidad, una lectura tarda lo suficiente y puede continuar.

### Telas inquietas
Los abrigos, las capas, los vestidos y el pelo no dejan de moverse, aunque el personaje esté quieto. El
movimiento es más fuerte por encima de 30 FPS.

**Por qué:** los ajustes de la tela actúan una vez por paso de física, y el juego hace un paso por
fotograma. Cada vez que una partícula de la tela toca el cuerpo o tira de sus vecinas, el juego le suma
velocidad, y esa velocidad es mayor cuanto más corto es el fotograma. Así la tela recibe pequeños golpes
todo el tiempo y no llega a asentarse.

## Qué hace este parche y qué no hace
- Corrección del reloj: cambia 2 bytes de tu `nocturne.exe`. Después, el juego usa su otro reloj interno
  (`timeGetTime`), que no pierde tiempo.
- Corrección de las telas: añade una pequeña rutina a tu `nocturne.exe`. La física de las telas funciona a
  30 pasos por segundo fijos con cualquier tasa por encima de 30 FPS. Una partícula de tela que apenas se
  mueve se detiene hasta que una fuerza real la mueve. Los fotogramas entre dos pasos se interpolan, así
  que el movimiento sigue siendo suave a 60 FPS.
- **Solo corrige estos dos problemas.** **No** hace que Nocturne funcione por sí solo en
  las versiones modernas de Windows. Sigues necesitando las correcciones habituales, como DDrawCompat.
  Consulta [Antes de empezar](#antes-de-empezar).
- No cambia los gráficos, el sonido, las partidas guardadas ni ningún archivo del juego aparte de
  `nocturne.exe`.
- Este repositorio no contiene ningún archivo del juego. Necesitas tu propia copia del juego.

## Antes de empezar
Primero, haz que el juego arranque y funcione. La
[página de Nocturne en PCGamingWiki](https://www.pcgamingwiki.com/wiki/Nocturne) (en inglés) explica
todos los pasos. En resumen:

- Instala el último parche oficial (Patch 2, versión 1.00.52) si tu copia lo necesita. 
- Instala [DDrawCompat](https://github.com/narzoul/DDrawCompat/releases). PCGamingWiki lo considera
  imprescindible. Corrige los gráficos, el vídeo de introducción y los errores al arrancar, y limita la
  tasa de fotogramas.
- La protección anticopia SafeDisc de algunos discos europeos no funciona en Windows Vista ni en
  versiones posteriores.

Cuando el juego funcione, aplica este parche.

## Instalación
1. Descarga `NocturneClockFix-1.1.0.zip` de la
   [página de versiones (Releases)](https://github.com/vorvek/NocturneClockFix/releases).
2. Descomprime el zip directamente en la carpeta de Nocturne (la carpeta donde está `nocturne.exe`).
   `Apply Clock Fix.cmd` tiene que quedar junto a `nocturne.exe`, no en una subcarpeta.
   - Con 7-Zip o WinRAR, usa **Extraer aquí** dentro de la carpeta de Nocturne.
   - **Extraer todo...** de Windows propone una subcarpeta nueva llamada `NocturneClockFix-1.1.0`.
     Borra esa última parte de la ruta antes de pulsar **Extraer**.
3. Haz doble clic en `Apply Clock Fix.cmd`.
4. Comprueba que la ventana muestra `Done.` (hecho). Después, pulsa una tecla para cerrarla.
5. Inicia el juego.

Antes de escribir, el parche guarda el archivo original como `nocturne.exe.clockfix-backup`.

Si ya usas la versión 1.0.0, descomprime el zip nuevo encima de los archivos anteriores y haz doble clic
otra vez en `Apply Clock Fix.cmd`. El parche añade la corrección de las telas.

## Desinstalación
Haz doble clic en `Remove Clock Fix.cmd`. Quita las dos correcciones. También puedes copiar `nocturne.exe.clockfix-backup` encima de
`nocturne.exe`.

## Si algo sale mal

- **"Windows refused to write nocturne.exe"** (Windows no permitió escribir en nocturne.exe): el juego
  está en una carpeta protegida, como Archivos de programa. Haz clic derecho en `Apply Clock Fix.cmd` y
  elige **Ejecutar como administrador**.
- **"Found 0 matching sites"** (no se encontró el código): el parche no conoce tu versión de
  `nocturne.exe`, o otra herramienta ya cambió el archivo. El parche no cambió nada. Por favor,
  [abre una incidencia (issue)](https://github.com/vorvek/NocturneClockFix/issues) e incluye el MD5 que
  muestra la ventana.
- **"Nocturne is running"** (Nocturne está en ejecución): cierra el juego primero.
- **Windows dice que la ejecución de scripts está deshabilitada**: inicia el parche con los archivos
  `.cmd`. Permiten que se ejecute solo este script. No cambian ninguna configuración de Windows.

## Versiones

| MD5 de `nocturne.exe` | Versión | Tamaño | Resultado |
|---|---|---|---|
| `24acd9b17f6846225123a9d8354b09e1` | 1.00.52 | 1.948.160 bytes | Reloj: probado en el juego, sin bloqueos en los menús. Telas: probado con el propio código de telas del juego en una CPU emulada |
| `cb98ab8bd3f544bcf1fbeda8b963bf8c` | 1.00.47 (disco original en inglés) | 1.942.016 bytes | Mismo código de reloj que la 1.00.52; la corrección del reloj se aplica. No probado en el juego. La corrección de las telas no se aplica |

La corrección del reloj también acepta otras versiones si encuentra el mismo código exactamente una vez.
Esas versiones no están probadas. Los informes son bienvenidos. La corrección de las telas solo se aplica a
la versión 1.00.52. En otras versiones, la ventana muestra `This build does not support the cloth fix` (esta
versión no admite la corrección de las telas), y solo se aplica la corrección del reloj.

## Detalles técnicos
- Punto del parche en la versión probada: desplazamiento en el archivo `0x157C08`, dirección
  `0x558808`. Los bytes cambian de `0F 85` (`jne`) a `90 E9` (`nop; jmp`). Normalmente el juego usa
  `QueryPerformanceCounter`, y solo usa su reloj `timeGetTime` si ese contador no existe. Después del
  parche, siempre usa `timeGetTime`.
- El reloj del juego es un valor de 32 bits, así que da la vuelta aproximadamente cada 61 minutos, también
  en el juego original. En ese momento, el juego puede perder como máximo un fotograma de tiempo de juego.
  No se bloquea.
- La corrección de las telas añade dos saltos en `CCloth::simulate` y 392 bytes de código nuevo en un
  espacio libre al final de la sección de código. Detalles, resultados y código fuente (en inglés):
  [cloth/NOTES.md](cloth/NOTES.md).

## Créditos y licencia
- Nocturne es un juego de Terminal Reality. Este proyecto no tiene relación con Terminal Reality ni con
  ningún titular de derechos.
- Licencia: MIT. Consulta [LICENSE](LICENSE).
