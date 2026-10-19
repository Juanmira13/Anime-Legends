# Anime Legends — Constitución del proyecto

Este archivo es la guía que Claude Code sigue en este proyecto. Mantenerlo corto, concreto y actualizado.

## 1. Visión del proyecto

- **Qué es:** videojuego de Roblox basado en distintos animes japoneses (Dragon Ball, Naruto, Black Clover, etc.). Es un simulador de progresión entre mundos con lucha contra enemigos, obtención de objetos, dinero y personajes.
- **Referencia de estilo:** Anime Fighters Simulator (AFS) de Roblox. El jugador elige el enemigo, sus personajes equipados atacan, y los Yenes se gastan en gacha y portales.
- **Propósito:** ofrecer entretenimiento a los jugadores de la plataforma con mecánicas avanzadas, gráficos, efectos visuales, animaciones y modelos de alta calidad.
- **Público objetivo:** público general, jugadores de Roblox aficionados al anime.
- **Proyecto:** personal y no comercial.
- **Objetivo del MVP:** una primera versión jugable con:
  - Varios mundos o "islas" de tamaño considerable, cada uno con zonas de spawn de enemigos y un jefe final. Cada isla representa un anime (Dragon Ball, Naruto, Black Clover, etc.) y su costo sube proporcionalmente a su dificultad.
  - Enemigos estáticos con barra de vida sobre la cabeza. Al ser derrotados dan dinero (Yenes).
  - Sistema de gacha por isla con 7 rarezas: Común, Poco común, Raro, Épico, Legendario, Mítico y Secreto. Los personajes son de cada anime (p. ej., Goku y Vegeta en el mundo de Dragon Ball; Naruto y Sasuke en el de Naruto), con nombres ligeramente modificados.
  - Daño por personaje según rareza: más alto en Mítico y Secreto, más bajo en Común y Poco común. Cada personaje tiene un cooldown entre golpes.
  - Inventario limitado de N personajes. El jugador es dueño de sus personajes y puede equiparlos y desequiparlos.
  - Dos monedas: Yenes (principal) y Gemas (secundaria), para comprar gacha, boosts e items.
  - Portales (rayos de luz) como sistema de transporte entre mundos.
  - Raids: fuente de Gemas y de mejoras del límite de personajes equipados.
- **Fuera de alcance por ahora:** Mazmorras (quedan para una versión posterior).

## 2. Stack técnico

- **Motor / framework:** Roblox Studio.
- **Lenguaje:** Luau.
- **Plataformas de destino:** Roblox (PC, móvil, consola y VR según lo soporte la experiencia).
- **Herramientas:** Rojo 7.7.1 (fijado en `rokit.toml`, gestionado con Rokit) para sincronizar los archivos `.luau` con Studio.
- **Servicios de Roblox:** DataStoreService para el guardado.

## 3. Estructura del repositorio

Rojo sincroniza los archivos `.luau` con Roblox Studio. El mapeo está en `default.project.json`:

```
AnimeLegends/
├── CLAUDE.md                 # Este archivo
├── default.project.json      # Mapeo de Rojo: carpetas → servicios de Roblox
├── rokit.toml                # Versiones fijadas de las herramientas
├── src/
│   ├── server/               # ServerScriptService.Server — lógica del servidor
│   ├── client/               # StarterPlayer.StarterPlayerScripts.Client — UI, efectos, control
│   └── shared/               # ReplicatedStorage.Shared — módulos compartidos
│       ├── Formulas.luau     # Valores derivados: daño, vida, Yenes, costos
│       ├── Config/           # Constantes: Balance, Rarities, Raids, Boosts
│       └── Data/             # Contenido: Islands, Characters
├── docs/                     # Diseño, decisiones de arquitectura
└── tests/                    # Pruebas
```

## 4. Comandos

- **Instalar herramientas:** `rokit install` (instala la versión de Rojo fijada en `rokit.toml`).
- **Ejecutar en desarrollo:** `rojo serve`, y en Roblox Studio conectar desde el plugin de Rojo (pestaña Plugins → Rojo → Connect).
- **Build / exportar:** `rojo build -o AnimeLegends.rbxlx` (los `.rbxl`/`.rbxlx` están en `.gitignore`).
- **Pruebas:** `python tests/run.py` ejecuta todos los `tests/*.spec.luau`. Requiere Python y el CLI de Luau (`luau`, de github.com/luau-lang/luau/releases; si no está en el PATH, indicar su ruta en la variable `LUAU`). `tests/bundle.py` empaqueta `src/shared` y `src/server` con una imitación de `script` para que los `require` por instancia funcionen fuera de Studio; solo sirve para módulos puros, sin servicios de Roblox.
  - `balance.spec.luau`: `Formulas` reproduce las tablas de `docs/balance.md`. Si se cambia el balance, actualizar ambos.
  - `player-record.spec.luau`: datos iniciales, reconciliación, migraciones y bloqueo de sesión.

## 5. Convenciones de código

- Seguir el estilo del código existente en cada archivo antes de introducir uno nuevo.
- Nombres en inglés para código y comentarios técnicos; los textos del juego pueden ir en español.
- Archivos Luau con extensión `.luau`. Sufijos de Rojo: `.server.luau` (Script), `.client.luau` (LocalScript), sin sufijo (ModuleScript). `init.luau` convierte una carpeta en módulo.
- TBD: formato y linter.

## 6. Diseño de juego (reglas para Claude)

El diseño detallado (islas, personajes, probabilidades, pity) está en `docs/game-design.md` y los valores numéricos en `docs/balance.md`. Leerlos antes de tocar cualquier sistema de juego.

- **Islas (en orden de progresión):** Nameku, Kono, Clover Kingdom, Titan Village, Hero Academy, Demon Corps. Cada isla tiene 7 personajes, uno por rareza.
- **Dificultad:** la vida de enemigos y jefes de cada isla es proporcional al daño de los personajes de esa isla.
- **Economía:** Yenes se obtienen derrotando enemigos. Gemas se obtienen en Raids.
- **Boosts:** Suerte, Dinero y Gemas, de 15 minutos. Se obtienen como drop de enemigos en los Raids o comprándolos con Gemas en la tienda.
- **Gacha:** por isla, 7 rarezas, con pity para Legendario, Mítico y Secreto.
- **Combate:** el jugador elige el objetivo. Daño y cooldown dependen del personaje y su rareza.
- **Equipados:** 3 al inicio, hasta 6. Logros de Raid de +1 ranura cada uno: Fácil 15 veces, Medio 25 veces, Difícil 50 veces.
- **Inventario:** 50 personajes al inicio. Se amplía con Yenes, con costo creciente.
- **Portales:** rayos de luz entre islas. Se desbloquean con Yenes y cuestan más según la dificultad de la isla.
- **Enemigos:** estáticos, con barra de vida. Cuatro rangos: Fácil, Medio, Difícil y Jefe. Los normales reaparecen a los 20 segundos y los jefes al minuto.
- **Escala:** todo (daño, vida, Yenes, costos) se multiplica ×6 por isla.
- **Raids:** lugar común con portal en Nameku, solo o en grupo (máximo 20 jugadores), 20 oleadas (mini jefe en la 10, jefe final en la 20) y 30 minutos de límite. Tres dificultades desbloqueadas desde el inicio, con más vida y mejores recompensas cuanto más difíciles. Espera independiente: Fácil 1 h, Medio 1 h 30 min, Difícil 2 h. No escalan con los jugadores. Cada enemigo da Gemas y Yenes según su tipo.
- **Pity:** contadores por isla, uno por rareza; cada uno se reinicia al obtener esa rareza.
- **Guardado:** `src/server/Services/DataService.luau` (DataStore con bloqueo de sesión, autoguardado cada 2 min, guardado al salir y al cerrar el servidor). La forma de los datos, los valores iniciales y las migraciones están en `src/server/Data/PlayerRecord.luau`. Al añadir un campo, ponerlo en `newData()`; la reconciliación lo añade a las partidas existentes. Si se renombra o cambia de forma un campo, subir `CurrentVersion` y añadir una migración.
- **Acceso a datos:** los demás servicios usan `DataService.getData`/`waitForData` y `addCurrency`/`spendCurrency`. Yenes y Gemas se replican al cliente como atributos del jugador (`Yen`, `Gems`).
- **Fuente de verdad de datos:** las constantes viven en `src/shared/Config/` y el contenido (islas, personajes) en `src/shared/Data/`. Los valores derivados (daño, vida, Yenes, costos) se calculan siempre con `Shared.Formulas`; nunca escribir esos números a mano en otro sitio.
- **Lógica sensible en el servidor:** tiradas del gacha, daño, monedas y pity se calculan en el servidor; el cliente solo envía peticiones y muestra resultados.

## 7. Reglas de trabajo para Claude

- Antes de cambiar código, leer los archivos relacionados.
- Hacer cambios pequeños y verificables; explicar las decisiones no obvias.
- No añadir dependencias nuevas sin preguntar.
- No modificar assets binarios ni datos de diseño sin confirmación.
- Ejecutar las pruebas o el build después de cambios relevantes, e informar del resultado tal cual.

## 8. Decisiones abiertas

- [x] Definir la visión y el MVP (sección 1).
- [x] Elegir motor y stack (sección 2).
- [x] Estructura de carpetas y Rojo configurados (sección 3).
- [x] Comandos de desarrollo (sección 4).
- [x] Lista de islas y personajes por isla.
- [x] Capacidad del inventario, personajes equipados, modo de ataque y guardado.
- [x] Cómo se obtienen las Gemas.
- [x] Requisitos de desbloqueo de los portales.
- [x] Probabilidades del gacha (suman 100%).
- [x] Hero Academy: Legendario es Hawks.
- [x] Pity de Secreto en 1,000,000 (confirmado).
- [x] Pity por isla; se reinicia al obtener esa rareza.
- [x] Valores iniciales de balance propuestos en `docs/balance.md` (pendientes de probar y ajustar).
- [x] Boosts: Suerte, Dinero y Gemas, 15 min, drop en Raids o compra con Gemas.
- [x] Diseño del MVP cerrado. En el MVP las Gemas solo se usan para comprar boosts.
- [x] Raids entran en el MVP; Mazmorras quedan fuera.
- [x] Diseño de Raids: acceso, jugadores, formato y recompensas.
- [x] Raids: ranuras extra por Raids completados, máximo 20 jugadores, 3 dificultades.
- [x] Raids: diferencias entre dificultades, desbloqueo, esperas y logros de ranuras.
- [ ] Confirmar si el máximo de equipados es 6 (solo logros) o si se mantienen 5 ranuras extra (máximo 8).
- [x] Respawn: 20 segundos los enemigos normales, 1 minuto los jefes.
