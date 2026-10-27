# Nocturne Clock Fix

*[Read in English](README.md)*

Un pequeño parche para **Nocturne** (Terminal Reality, 1999). Elimina los bloqueos largos de los menús en
los PC modernos.

## El problema
En un PC moderno, Nocturne se queda bloqueado a menudo entre 5 y 20 segundos:

- en el menú principal y sus pantallas,
- entre el vídeo de introducción y el menú principal,
- en los menús durante la partida.

Durante un bloqueo, un núcleo de la CPU trabaja al 100 %. Los bloqueos son aleatorios: ocurren a menudo,
pero no siempre.

**Por qué:** el juego cuenta el tiempo en pasos pequeños, y en muchos menús espera al siguiente paso. Cada
vez que lee el reloj, descarta la fracción de paso. En un PC de 1999, cada lectura tardaba lo suficiente
para contar. Una CPU moderna es tan rápida que cada lectura cuenta como 0, y el reloj del juego se para.
El juego espera entonces en un bucle hasta que, por casualidad, una lectura tarda lo suficiente.

## Qué hace este parche y qué no hace
- Cambia 2 bytes de tu `nocturne.exe`. Después, el juego usa su otro reloj interno (`timeGetTime`), que
  no pierde tiempo.
- **Solo corrige estos bloqueos de los temporizadores.** **No** hace que Nocturne funcione por sí solo en
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

Cuando el juego funcione pero los menús se bloqueen, aplica este parche.

## Instalación
1. Cierra Nocturne.
2. Descarga `NocturneClockFix-1.0.0.zip` de la
   [página de versiones (Releases)](https://github.com/vorvek/NocturneClockFix/releases).
3. Descomprime el zip. Copia estos 3 archivos en la carpeta de Nocturne (la carpeta donde está
   `nocturne.exe`):
   - `NocturneClockFix.ps1`
   - `Apply Clock Fix.cmd`
   - `Remove Clock Fix.cmd`
4. Haz doble clic en `Apply Clock Fix.cmd`.
5. Comprueba que la ventana muestra `Done.` (hecho). Después, pulsa una tecla para cerrarla.
6. Inicia el juego.

Antes de escribir, el parche guarda el archivo original como `nocturne.exe.clockfix-backup`.

## Desinstalación
Haz doble clic en `Remove Clock Fix.cmd`. También puedes copiar `nocturne.exe.clockfix-backup` encima de
`nocturne.exe`.

## Si algo sale mal
Los mensajes de la ventana están en inglés:

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

## Versión probada

| MD5 de `nocturne.exe` | Tamaño | Resultado |
|---|---|---|
| `24acd9b17f6846225123a9d8354b09e1` | 1.948.160 bytes | Probado en el juego: sin bloqueos en los menús |

El parche también acepta otras versiones si encuentra el mismo código exactamente una vez. Esas versiones
no están probadas. Los informes son bienvenidos.

## Detalles técnicos
- Punto del parche en la versión probada: desplazamiento en el archivo `0x157C08`, dirección
  `0x558808`. Los bytes cambian de `0F 85` (`jne`) a `90 E9` (`nop; jmp`). Normalmente el juego usa
  `QueryPerformanceCounter`, y solo usa su reloj `timeGetTime` si ese contador no existe. Después del
  parche, siempre usa `timeGetTime`.
- Medido con un perfilador por muestreo en un Ryzen 9 9950X3D. Antes del parche, el hilo principal
  estuvo al 100 % de CPU durante 40 de 81 segundos en los menús. Después del parche, durante 0 de 23
  segundos.
- El reloj del juego es un valor de 32 bits, así que da la vuelta aproximadamente cada 61 minutos, también
  en el juego original. En ese momento, el juego puede perder como máximo un fotograma de tiempo de juego.
  No se bloquea.

## Créditos y licencia
- Análisis y parche hechos con Claude Code (Claude Opus 5.5, un modelo de IA de Anthropic), con el kit de
  herramientas [universal-modder](https://github.com/rehan-remade/universal-modder). Probado en el juego
  por [vorvek](https://github.com/vorvek).
- Nocturne es un juego de Terminal Reality. Este proyecto no tiene relación con Terminal Reality ni con
  ningún titular de derechos.
- Licencia: MIT. Consulta [LICENSE](LICENSE).
