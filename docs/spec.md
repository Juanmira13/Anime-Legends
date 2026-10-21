# Anime Legends — Especificación

Qué hace el juego y cómo se comprueba que lo hace. El detalle de cada sistema está en `docs/game-design.md` y los números en `docs/balance.md`; este documento no los duplica.

Estado: ✅ hecho · 🟡 parcial · ⏳ pendiente

## Resumen

Simulador de progresión de Roblox al estilo Anime Fighters Simulator. El jugador derrota enemigos para ganar Yenes, tira en el gacha de cada isla para conseguir personajes de anime, los equipa para hacer más daño y desbloquea islas más difíciles. Los Raids dan Gemas, boosts y ranuras extra de personajes equipados.

## Requisitos funcionales

### R1. Guardado de progreso ✅
- El progreso se guarda en DataStore: monedas, personajes, equipados, mejoras de inventario, islas desbloqueadas, última isla, pity, boosts y progreso de Raids.
- Un jugador nuevo empieza con 0 Yenes, 0 Gemas y Kurilin equipado.
- Dos servidores no pueden escribir los datos del mismo jugador a la vez (bloqueo de sesión).

**Aceptación:** al salir y volver a entrar (con acceso a la API activo) se conservan los datos. Sin acceso a la API, Studio juega con datos temporales y lo avisa en la salida.

### R2. Enemigos y combate ✅
- Cada isla tiene enemigos estáticos de 4 rangos (Fácil, Medio, Difícil, Jefe) con barra de vida.
- El jugador hace clic en un enemigo para elegirlo como objetivo; sus personajes equipados le pegan según su daño y cooldown mientras esté a menos de 60 studs.
- Al morir, todos los que lo golpearon reciben sus Yenes (×2 con Boost de Dinero). Reaparece a los 20 s (jefes: 60 s).
- Solo se puede atacar en islas desbloqueadas.

**Aceptación:** con Kurilin, un enemigo Fácil de Nameku (170 de vida) baja 10 cada 2 s, da 5 ¥ y reaparece a los 20 s.

### R3. Gacha ✅
- Una máquina por isla. Cada tirada cuesta Yenes según la isla y da un personaje de esa isla según las probabilidades de rareza.
- Pity por isla para Legendario (500), Mítico (5,000) y Secreto (1,000,000).
- Boost de Suerte: ×2 Legendario, Mítico y Secreto, restado de Común.
- No se puede tirar sin Yenes, en islas bloqueadas ni con el inventario lleno.

**Aceptación:** una tirada en Nameku cuesta 50 ¥ y muestra el personaje con el color de su rareza.

### R4. Inventario ✅
- 50 espacios al inicio, ampliables de 10 en 10 con Yenes (costo ×1.5) hasta 250.
- Equipar y desequipar hasta el límite de ranuras (3 al inicio, máximo 6). "Equipar mejores" llena las ranuras con más daño por segundo.
- Eliminar personajes con confirmación; no los equipados ni el último.

**Aceptación:** el panel muestra "Personajes x/50 · Equipados y/3" y se actualiza al tirar en el gacha.

### R5. Islas y portales 🟡
- 6 islas en orden: Nameku, Kono, Clover Kingdom, Titan Village, Hero Academy, Demon Corps.
- Los portales desbloquean islas en orden pagando Yenes y llevan a su punto de llegada. Volver es gratis.
- Al entrar o reaparecer, el jugador aparece en la última isla visitada.
- Las 6 islas están en el mar, cada una con plaza de llegada, gacha, portales, 4 zonas de enemigos unidas por un camino y el hito del jefe. Ver `docs/game-design.md` (Mundo y mar, Recorrido, Dirección de arte).

**Aceptación:** desbloquear Kono cuesta 2,700 ¥; intentar saltar una isla avisa "Primero desbloquea…". Con el mundo construido por el plugin, el validador no muestra errores y se puede viajar por portales de Nameku a Demon Corps y al lobby de Raids.
**Parcial:** las 6 islas están construidas con su propio terreno, relieve y decoración (Nameku aprobada); falta probar y ajustar las otras 5 en Studio.

### R6. Raids ✅
- Lobby común al que se llega por un portal en Nameku. 3 dificultades abiertas desde el inicio, con espera por jugador (1 h, 1 h 30 min, 2 h).
- Fila de 15 s; juegan juntos hasta 20 jugadores, cada grupo en su propia arena.
- 20 oleadas (mini jefe en la 10, jefe en la 20), 30 minutos de límite.
- Cada enemigo da Gemas y Yenes a todos los del Raid y puede soltar un boost para cada jugador.
- Logros: Fácil ×15, Medio ×25 y Difícil ×50 dan +1 ranura de equipado cada uno.

**Aceptación:** al completar un Raid Fácil se vuelve al lobby con "¡Raid completado!" y la plataforma muestra la espera de 1 hora.

### R7. Boosts ✅
- Suerte, Dinero y Gemas, de 15 minutos. Se obtienen como drop en Raids o se compran con Gemas (125, 200, 300).
- Activar suma 15 minutos al tiempo restante. El tiempo solo corre con el jugador conectado.

**Aceptación:** con el Boost de Dinero activo, un enemigo Fácil de Nameku da 10 ¥.

### R8. Interfaz ✅
- Yenes y Gemas siempre visibles, con los boosts activos debajo.
- Botones "Inventario" y "Boosts" en el borde izquierdo (no tapan el joystick en móvil).
- Avisos en pantalla para gacha, portales, Raids y boosts.
- Interacciones con ProximityPrompt y clic/toque: funcionan en PC, móvil y consola.
- Estilo oficial Check-UI (ventanas opacas, tipografía GothamBlack con contorno, botones con relieve, escalado según el tamaño de pantalla). Ver `CLAUDE.md` (sección 6, Interfaz); la migración de la UI actual es la Fase 11 de `docs/plan.md`.

### R9. Presentación 🟡
- Personajes equipados visibles para todos los jugadores, que siguen a su dueño caminando por el suelo y van hasta el enemigo a golpear (estilo AFS). Ver `docs/game-design.md` (Combate → Personajes visibles).
- Modelos de enemigos y arena de Raid (coliseo flotante), efectos de golpe, números de daño, efectos de gacha, sonido y música.
- Islas de alta calidad, con la dirección de arte de cada anime, mar cartoon animado y ambientación por isla (luz, cielo, niebla, partículas).

**Aceptación:** con 3 personajes equipados, caminan detrás del jugador a la misma velocidad, con los pies en el suelo y moviendo brazos y piernas; al elegir un enemigo caminan hasta colocarse a su alrededor y cada uno embiste cada vez que golpea. Otro jugador ve lo mismo. Al equipar o desequipar, el grupo cambia al momento.
- Cada luchador y enemigo tiene su modelo en rig R6 que se puede exportar desde Studio para rehacerlo en Blender y volver a importarlo sin tocar código.

**Parcial:** personajes visibles hechos; los 70 modelos son rigs R6 provisionales (luchadores del color de su rareza, enemigos del color y tamaño de su rango). Faltan los modelos finales de Blender, efectos, sonido y mapas.

## Requisitos no funcionales

- **Autoridad del servidor:** el cliente solo envía peticiones; el servidor valida y calcula daño, monedas, gacha, pity e inventario.
- **Balance proporcional:** todos los valores derivan de las constantes de `src/shared/Config/` mediante `Shared.Formulas` (×6 por isla).
- **Construcción de mapas sin código:** el juego lee Parts etiquetadas (ver tabla en `CLAUDE.md`).
- **Pruebas:** la lógica pura tiene pruebas automáticas (`python tests/run.py`) y el código con APIs de Roblox pasa la revisión de tipos de `luau-lsp`. Todo el código pasa el formato de StyLua y el linter selene.

## Fuera de alcance

- Mazmorras.
- Otros usos de las Gemas además de los boosts.
- Venta de personajes por Yenes.
