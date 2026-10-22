# Anime Legends — Constitución del proyecto

Este archivo es la guía que Claude Code sigue en este proyecto. Mantenerlo corto, concreto y actualizado.

**Documentos del proyecto** (se actualizan juntos en cada cambio; ver sección 7):

| Documento | Qué contiene |
|---|---|
| `CLAUDE.md` (este archivo) | Constitución: visión, stack, reglas de arquitectura y de trabajo |
| `docs/spec.md` | Especificación: qué hace el juego, requisitos y criterios de aceptación |
| `docs/plan.md` | Plan técnico: arquitectura, flujo de datos y fases |
| `docs/tasks.md` | Tareas: hechas (con su commit) y pendientes |
| `docs/game-design.md` | Diseño detallado de cada sistema |
| `docs/balance.md` | Valores numéricos y el modelo que los genera |

## 1. Visión del proyecto

- **Qué es:** videojuego de Roblox basado en distintos animes japoneses (Dragon Ball, Naruto, Black Clover, etc.). Es un simulador de progresión entre mundos con lucha contra enemigos, obtención de objetos, dinero y personajes.
- **Referencia de estilo:** Anime Fighters Simulator (AFS) de Roblox. El jugador elige el enemigo, sus personajes equipados atacan, y los Yenes se gastan en gacha y portales.
- **Propósito:** ofrecer entretenimiento a los jugadores de la plataforma con mecánicas avanzadas, gráficos, efectos visuales, animaciones y modelos de alta calidad.
- **Público objetivo:** público general, jugadores de Roblox aficionados al anime.
- **Proyecto:** personal y no comercial.
- **Objetivo del MVP:** una primera versión jugable con:
  - Varios mundos o "islas" de tamaño considerable, cada uno con zonas de spawn de enemigos y un jefe final. Cada isla representa un anime (Dragon Ball, Naruto, Black Clover, etc.) y su costo sube proporcionalmente a su dificultad.
  - Enemigos estáticos con barra de vida sobre la cabeza. Al ser derrotados sueltan monedas flotantes de Yenes que el jugador recoge.
  - Sistema de gacha por isla con 7 rarezas: Común, Poco común, Raro, Épico, Legendario, Mítico y Secreto. Los personajes son de cada anime (p. ej., Goku y Vegeta en el mundo de Dragon Ball; Naruto y Sasuke en el de Naruto), con nombres ligeramente modificados.
  - Daño por personaje según rareza: más alto en Mítico y Secreto, más bajo en Común y Poco común. Cada personaje tiene un cooldown entre golpes.
  - Inventario limitado (50 personajes al inicio, ampliable). El jugador es dueño de sus personajes y puede equiparlos y desequiparlos.
  - Dos monedas: Yenes (principal) y Gemas (secundaria), para comprar gacha, boosts e items.
  - Portales (rayos de luz) como sistema de transporte entre mundos.
  - Raids: fuente de Gemas y de mejoras del límite de personajes equipados.
- **Fuera de alcance por ahora:** Mazmorras (quedan para una versión posterior).

## 2. Stack técnico

- **Motor / framework:** Roblox Studio.
- **Lenguaje:** Luau.
- **Plataformas de destino:** Roblox (PC, móvil, consola y VR según lo soporte la experiencia).
- **Herramientas** (versiones fijadas en `rokit.toml`, gestionadas con Rokit): Rojo 7.7.1 para sincronizar los archivos `.luau` con Studio, luau 0.743 (pruebas), luau-lsp 1.70.1 (tipos), StyLua 2.6.0 (formato) y selene 0.32.0 (linter).
- **Estilo de la UI:** Check-UI, de la skill `check-ui-clean-roblox` (ver sección 6, Interfaz).
- **Servicios de Roblox:** DataStoreService para el guardado.

## 3. Estructura del repositorio

Rojo sincroniza los archivos `.luau` con Roblox Studio. El mapeo está en `default.project.json`:

```
AnimeLegends/
├── CLAUDE.md                 # Este archivo
├── default.project.json      # Mapeo de Rojo: carpetas → servicios de Roblox
├── builder.project.json      # Plugin "Island Builder" de Studio (src/builder + src/shared)
├── rokit.toml                # Versiones fijadas de las herramientas
├── stylua.toml               # Formato (StyLua)
├── selene.toml               # Linter (selene, std de Roblox + tests.yml)
├── tests.yml                 # Globales de las pruebas para selene
├── src/
│   ├── server/               # ServerScriptService.Server — lógica del servidor
│   │   ├── Main.server.luau  # Arranca los servicios en orden
│   │   ├── Remotes.luau      # Crea los RemoteEvents en ReplicatedStorage.Remotes
│   │   ├── Services/         # Data, Enemy, Combat, Coin, Gacha, Inventory, Portal, Raid, Boost, Settings (…Service)
│   │   ├── Signal.luau       # Eventos entre servicios (pasan las mismas tablas, no copias)
│   │   ├── Coins/            # Lógica pura de las monedas (CoinOps)
│   │   ├── Data/             # PlayerRecord (forma de los datos guardados)
│   │   ├── Combat/           # Lógica pura de combate (AttackClock)
│   │   ├── Gacha/            # Lógica pura del gacha (GachaRoll)
│   │   ├── Inventory/        # Lógica pura del inventario (InventoryOps)
│   │   ├── Portals/          # Lógica pura de desbloqueo y viaje (PortalOps)
│   │   ├── Raids/            # Lógica pura de Raids (RaidOps)
│   │   ├── Boosts/           # Lógica pura de boosts (BoostOps)
│   │   ├── Settings/         # Lógica pura de las opciones del jugador (SettingsOps)
│   │   └── Dev/              # Ayudas solo para Studio (TestArena, MapValidator; DevCheats es temporal)
│   ├── client/               # StarterPlayer.StarterPlayerScripts.Client — UI, efectos, control
│   │   ├── Main.client.luau  # Arranca los controladores
│   │   ├── Dev/              # Ayudas solo para Studio (RevealPreview, temporal)
│   │   ├── UI/               # Theme (colores), CheckUI (constructores Check-UI), Notify, CharacterViewport, GachaRevealView
│   │   ├── Followers/        # Lógica pura de los personajes visibles (FollowerMotion)
│   │   ├── Effects/          # Lógica pura de los efectos de golpe, del gacha y del sonido (HitStyle, GachaReveal, SoundMix)
│   │   └── Controllers/      # Sound, Hud, Enemy (barras de vida), Gacha, Inventory (panel), Portal, Raid, Boost, Follower, Ambience, Sea, Coin, HitEffect
│   ├── shared/               # ReplicatedStorage.Shared — módulos compartidos
│   │   ├── Formulas.luau     # Valores derivados: daño, vida, Yenes, costos
│   │   ├── Format.luau       # Formato de números para la UI (1.5K, 2.3M)
│   │   ├── Config/           # Constantes: Balance, Rarities, Raids, Boosts, World (mar e islas), Ambience (look por área), Sounds (audios)
│   │   ├── Map/              # MapCheck (reglas puras del mapa), MapScan (recolecta y valida), AmbienceApply, GachaStar
│   │   └── Data/             # Contenido: Islands, Characters
│   └── builder/              # Plugin Island Builder (no se publica en el juego)
│       ├── Main.server.luau  # Panel: construir mundo/isla/lobby/arena, validar, puntos de foto
│       ├── IslandBuilder.luau # Construye una isla: terreno, mar, jugabilidad, decoración
│       ├── RaidLobby.luau    # Lobby de Raids (templo flotante)
│       ├── RaidArena.luau    # Arena de Raid (coliseo) → ServerStorage.RaidArena
│       ├── RaidArenaLayout.luau # Medidas, llegada y portal de salida de la arena (puro)
│       ├── Gen/              # Lógica pura: Rng, Shape (terreno), Scatter, PathWalk, LayoutCheck
│       ├── Kit/              # Parts, Buildings, TerrainWriter, Sea, Gameplay, Nature
│       └── Islands/          # Por isla: <Isla>Layout (trazado puro) y <Isla> (decoración); Layouts y Registry
├── docs/
│   ├── spec.md               # Especificación (qué)
│   ├── plan.md               # Plan técnico (cómo)
│   ├── tasks.md              # Tareas hechas y pendientes
│   ├── game-design.md        # Diseño detallado
│   └── balance.md            # Valores numéricos
├── assets/                   # Modelos (.rbxmx/.rbxm) que Rojo sincroniza
│   ├── CharacterModels/      # ReplicatedStorage.CharacterModels.<Isla>.<IdPersonaje> — luchadores
│   ├── EnemyModels/          # ServerStorage.EnemyModels.<Isla>.<Rango> y .Raid.<Tipo> — enemigos
│   └── Textures/             # Imágenes para subir a Roblox (SeaCartoon.png); Rojo no las sincroniza
├── tools/
│   ├── build_rigs.py         # Genera los rigs R6 provisionales que falten
│   ├── build_textures.py     # Genera la textura cartoon del mar
│   ├── selene_std.py         # Genera la std de Roblox para selene
│   └── typecheck.py          # Revisión de tipos del juego y del plugin
└── tests/                    # Pruebas (*.spec.luau, run.py, bundle.py)
```

## 4. Comandos

- **Instalar herramientas:** `rokit install` (instala en `~/.rokit/bin`, que está en el PATH, las versiones fijadas en `rokit.toml`). Los tipos de Roblox para `luau-lsp` están en `~/.local/share/luau-lsp/globalTypes.d.luau`, indicados por la variable de usuario `LUAU_DEFINITIONS`. En este equipo el antivirus AVG analiza HTTPS: los dominios de GitHub (`github.com`, `api.github.com`, `raw.githubusercontent.com`, `objects.githubusercontent.com`, `release-assets.githubusercontent.com`) tienen excepción para que Rokit pueda descargar.
- **Formato:** `stylua src tests` (comprobar sin cambiar: `stylua --check src tests`).
- **Linter:** `selene src tests` (`std = "roblox+tests"`; `tests.yml` declara los globales que inyecta `tests/bundle.py`). La primera vez, y cuando cambie la versión de selene, `python tools/selene_std.py` genera `roblox_base.yml` y `roblox.yml` (en `.gitignore`); sustituye a `selene generate-roblox-std`, que se rinde si la descarga de la API de Roblox es lenta. Debe terminar con 0 errores y 0 avisos.
- **Ejecutar en desarrollo:** `rojo serve`, y en Roblox Studio conectar desde el plugin de Rojo (pestaña Plugins → Rojo → Connect).
- **Build / exportar:** `rojo build -o AnimeLegends.rbxlx` (los `.rbxl`/`.rbxlx` están en `.gitignore`).
- **Pruebas:** `python tests/run.py` ejecuta todos los `tests/*.spec.luau`. Requiere Python y el CLI de Luau (`luau`, de github.com/luau-lang/luau/releases; si no está en el PATH, indicar su ruta en la variable `LUAU`). `tests/bundle.py` empaqueta `src/shared`, `src/server`, `src/client` y `src/builder` con una imitación de `script` para que los `require` por instancia funcionen fuera de Studio; solo sirve para módulos puros, sin servicios de Roblox.
  - `balance.spec.luau`: `Formulas` reproduce las tablas de `docs/balance.md`. Si se cambia el balance, actualizar ambos.
  - `player-record.spec.luau`: datos iniciales (también las opciones), reconciliación, migraciones y bloqueo de sesión.
  - `combat.spec.luau`: tiempos de ataque, recompensas y formato de números.
  - `gacha.spec.luau`: probabilidades, Boost de Suerte, pity, distribución de tiradas y tirada x10 (igual que 10 sueltas, costo ×10).
  - `inventory.spec.luau`: añadir, equipar, desequipar, eliminar, "Equipar mejores", ampliaciones y espacio para varios.
  - `portal.spec.luau`: orden de desbloqueo, viajes e isla de aparición.
  - `raid.spec.luau`: esperas, completados y logros de ranuras, recompensas, drops de boosts, oleadas y puntos aleatorios de los enemigos en la arena.
  - `coins.spec.luau`: reparto de las recompensas en monedas.
  - `signal.spec.luau`: los eventos entre servicios pasan las mismas tablas.
  - `boost.spec.luau`: conceder, activar (acumula duración) y descontar tiempo.
  - `acceptance.spec.luau`: los criterios de aceptación numéricos de `docs/spec.md` (R1 a R7), uno por requisito. Si cambia la especificación, actualizarlo.
  - `effects.spec.luau`: números de daño (salto, subida y desvanecido, tamaños, topes), destellos de golpe y animación del gacha (estilo por rareza, entrada, carga con subida de colores, estallido, confeti, cartas, volteo y orden de las diez cartas, distribución en pantalla).
  - `followers.spec.luau`: formación, arco alrededor del objetivo, embestida (más corta que el cooldown más rápido), velocidad de marcha, ciclo de caminar y giro de los personajes visibles.
  - `worldgen.spec.luau`: aleatorio con semilla, forma del terreno, relieve (montañas, ríos con cascada, lagos, caminos con rampas, formas de costa), materiales, orilla, vóxeles de tierra y agua, dispersión, y reglas de trazado (`LayoutCheck`) sobre los trazados reales de las 6 islas.
  - `sound.spec.luau`: configuración de los audios, límites de efectos, tonos que suben (monedas, gacha), tono de los golpes por rareza, música por área y del jefe, fundido y opciones del jugador (`SettingsOps`).
  - `map.spec.luau`: reglas del mapa (`MapCheck`), configuración del mundo, ambientación de todas las áreas trazado de la arena de Raid (`RaidArenaLayout`) y geometría de la estrella del gacha (`GachaStar`).
- **Modelos provisionales:** `python tools/build_rigs.py` crea el rig R6 de cada luchador y enemigo que no tenga modelo (nunca sobrescribe; `--force` regenera solo los `.rbxmx`). `python tools/build_rigs.py --check` falla si falta alguno: ejecutarlo al añadir personajes, islas, rangos o tipos de enemigo de Raid.
- **Plugin Island Builder:** `rojo build builder.project.json --plugin AnimeLegendsBuilder.rbxm` lo instala en la carpeta de plugins de Studio (volver a ejecutarlo tras cada cambio en `src/builder`). En Studio: pestaña Plugins → Anime Legends → Island Builder.
- **Textura del mar:** `python tools/build_textures.py` genera `assets/Textures/SeaCartoon.png`. Subirla a Roblox y poner su id en `World.Sea.textureId` (ahora `rbxassetid://133815183624535`). El plugin pone la textura al construir, así que tras cambiarla hay que reconstruir el océano y las islas.
- **Revisión de tipos (incluye código con APIs de Roblox):** `python tools/typecheck.py`. Hace tres pasadas con `luau-lsp`: juego (con `sourcemap.json`), plugin (con `builder-sourcemap.json`) y una pasada sin mapa de fuentes que detecta propiedades inexistentes de clases de Roblox (con mapa de fuentes, `luau-lsp` no tipa bien `workspace` ni `game` y esos errores se escapan). Requiere `rojo`, `luau-lsp` y `globalTypes.d.luau` (de github.com/JohnnyMorganz/luau-lsp); si no están en el PATH o en la raíz, indicar sus rutas en `ROJO`, `LUAU_LSP` y `LUAU_DEFINITIONS`. Debe terminar sin errores.

## 5. Convenciones de código

- Seguir el estilo del código existente en cada archivo antes de introducir uno nuevo.
- Nombres en inglés para código y comentarios técnicos; los textos del juego pueden ir en español.
- Archivos Luau con extensión `.luau`. Sufijos de Rojo: `.server.luau` (Script), `.client.luau` (LocalScript), sin sufijo (ModuleScript). `init.luau` convierte una carpeta en módulo.
- **Formato:** StyLua con `stylua.toml` (tabs, 120 columnas, comillas dobles, paréntesis siempre). Todo el código pasa `stylua --check src tests`.
- **Linter:** selene con `selene.toml`. Todo el código pasa `selene src tests` sin errores ni avisos.

## 6. Diseño de juego (reglas para Claude)

El diseño detallado (islas, personajes, probabilidades, pity) está en `docs/game-design.md` y los valores numéricos en `docs/balance.md`. Leerlos antes de tocar cualquier sistema de juego.

- **Islas (en orden de progresión):** Nameku, Kono, Clover Kingdom, Titan Village, Hero Academy, Demon Corps. Cada isla tiene 7 personajes, uno por rareza.
- **Dificultad:** la vida de enemigos y jefes de cada isla es proporcional al daño de los personajes de esa isla.
- **Economía:** Yenes se obtienen derrotando enemigos, que los sueltan como monedas flotantes. Gemas se obtienen en Raids.
- **Monedas de Yenes:** al morir un enemigo (de isla o de Raid), cada jugador que lo golpeó recibe su propia tanda de monedas donde estaba el enemigo (solo él las ve). Las monedas flotan y giran; al acercarse a menos de `Balance.Coins.magnetRadius` vuelan hacia el jugador y cada una suma su parte de Yenes en ese momento. Las que siguen en el suelo pasados `Balance.Coins.lifetime` segundos se pagan solas (vuelan si el jugador está cerca), y al salir del juego se pagan antes del guardado: nunca se pierden. `CoinService` lleva las tandas y valida cada recogida (la tanda es suya, la moneda no se recogió y el jugador está a menos de `collectRange`); `CoinOps` reparte la recompensa en monedas que suman exacto; `CoinController` las dibuja. Las Gemas de los Raids se suman directamente.
- **Boosts:** Suerte, Dinero y Gemas, de 15 minutos. Se obtienen como drop de enemigos en los Raids o comprándolos con Gemas en la tienda.
- **Gacha:** por isla, 7 rarezas, con pity para Legendario, Mítico y Secreto. Tirada x1 o x10 (cuesta 10 tiradas, sin descuento, y necesita 10 espacios libres).
- **Combate:** el jugador elige el objetivo. Daño y cooldown dependen del personaje y su rareza.
- **Equipados:** 3 al inicio, hasta 6. Logros de Raid de +1 ranura cada uno: Fácil 15 veces, Medio 25 veces, Difícil 50 veces.
- **Inventario:** 50 personajes al inicio. Se amplía con Yenes, con costo creciente.
- **Portales:** rayos de luz entre islas. Se desbloquean con Yenes y cuestan más según la dificultad de la isla.
- **Enemigos:** estáticos, con barra de vida. Cuatro rangos: Fácil, Medio, Difícil y Jefe. Los normales reaparecen a los 20 segundos y los jefes al minuto.
- **Escala:** todo (daño, vida, Yenes, costos) se multiplica ×6 por isla.
- **Raids:** lugar común con portal en Nameku, solo o en grupo (máximo 20 jugadores), 20 oleadas (mini jefe en la 10, jefe final en la 20) y 30 minutos de límite. Tres dificultades desbloqueadas desde el inicio, con más vida y mejores recompensas cuanto más difíciles. Espera independiente: Fácil 1 h, Medio 1 h 30 min, Difícil 2 h. No escalan con los jugadores. Cada oleada trae enemigos débiles, medianos y fuertes (`Raids.WaveEnemies`) y es un poco más difícil que la anterior (vida y Yenes ×`Raids.WaveGrowth` = 1.03 por oleada, sin saltos); la 10 añade el mini jefe y la 20 el jefe final (`Raids.WaveExtras`). Las 20 oleadas se juegan siempre, también en Studio. Cada enemigo da Gemas y Yenes según su tipo. El mini jefe y el jefe final aparecen en el centro del coliseo (círculo dorado); los demás enemigos, en puntos aleatorios de la pista (nunca en las gradas), separados entre sí y lejos del jefe, del punto de llegada y del portal de salida. Un portal de salida dentro del coliseo deja abandonar el Raid y lleva al lobby de Raids.
- **Pity:** contadores por isla, uno por rareza; cada uno se reinicia al obtener esa rareza.
- **Guardado:** `src/server/Services/DataService.luau` (DataStore con bloqueo de sesión, autoguardado cada 2 min, guardado al salir y al cerrar el servidor). La forma de los datos, los valores iniciales y las migraciones están en `src/server/Data/PlayerRecord.luau`. Al añadir un campo, ponerlo en `newData()`; la reconciliación lo añade a las partidas existentes. Si se renombra o cambia de forma un campo, subir `CurrentVersion` y añadir una migración.
- **Mundo:** las islas están en el mar (no flotan), en fila sobre +X a 2000 studs una de otra (Nameku en el origen), con el nivel del mar en y = 0 (`Shared/Config/World`). Cada isla ocupa un cuadrado de mar de 2000 studs con su orilla de espuma y una textura cartoon animada encima del agua Terrain; alrededor de todas, un océano (`Workspace.Map.Ocean`) llega 4000 studs más allá para que el mar alcance el horizonte. El lobby de Raids es un templo flotante en el cielo.
- **Island Builder (plugin):** construye las islas en Studio desde código, en `Workspace.Map.<Área>` (`Gameplay`, `Decor`, `Sea`). Cada isla tiene su propio módulo: un trazado puro (`Islands/<Isla>Layout`) y su decoración (`Islands/<Isla>`). Ninguna isla reutiliza el terreno ni la organización de otra. El trazado define la silueta de la costa (alargada, lóbulos, bahías), las colinas, las montañas, las mesetas del mar (`mesas`), las terrazas donde pueden ir zonas (`plateaus`), los ríos (con cascadas, cada uno a su nivel de agua) y lagos, las superficies de suelo (`surfaces`), la plaza, las 4 zonas planas y los caminos. Un camino con alturas en todos sus puntos talla rampas y cortes en el relieve, pero se interrumpe sobre el agua, que necesita un puente decorativo con colisión. El terreno, los objetos y los puntos de jugabilidad salen de las mismas funciones de `Gen/Shape`, así que siempre coinciden. Reconstruir borra y regenera el área salvo la carpeta `Map.<Área>.Manual`, que es para retoques a mano. Antes de construir comprueba el trazado con `LayoutCheck` (zonas en tierra y separadas, caminos con pendiente ≤ 0.5, agua lejos de las zonas); después valida el mapa con `MapCheck`. Los puntos de foto (cámaras fijas para capturas) se guardan en `ServerStorage.PhotoSpots`.
- **Ambientación:** cada área (isla, `RaidLobby`, `Raid`) tiene su iluminación, cielo, niebla, color, colores de terreno y agua y partículas en `Shared/Config/Ambience`. El servidor replica el área del jugador en el atributo `CurrentArea` (`PortalService` y `RaidService` al teletransportar) y `AmbienceController` la aplica. Los colores de material del terreno son globales en Roblox, por eso se aplican por área en el cliente.
- **Construir el mapa:** el código no depende de posiciones; lee Parts etiquetadas (CollectionService) con atributos:

  | Etiqueta | Atributos | Qué es |
  |---|---|---|
  | `IslandSpawn` | `Island` | Punto de llegada a una isla (uno por isla) |
  | `EnemySpawn` | `Island`, `Rank` | Punto de aparición de un enemigo |
  | `GachaStand` | `Island` | Núcleo de la estrella de una máquina de gacha |
  | `Portal` | `TargetIsland` | Portal hacia otra isla (la Part base; el haz de luz es decorativo) |
  | `RaidPortal` | — | Portal hacia el lobby de Raids (en Nameku) |
  | `RaidLobbySpawn` | — | Punto de llegada al lobby de Raids |
  | `RaidPad` | `Difficulty` (`Easy`, `Medium`, `Hard`) | Plataforma para entrar a la fila de un Raid |

  Modelos de enemigos en `ServerStorage.EnemyModels.<Isla>.<Rango>` y `EnemyModels.Raid.<Tipo>` (vienen de `assets/EnemyModels`, ver **Modelos**). La arena de Raid es `ServerStorage.RaidArena` (Model con PrimaryPart y pivote en el centro del suelo, el atributo `FieldRadius` con el radio de la pista, una Part `PlayerSpawn` y la Part `RaidExit` del portal de salida). La construye el plugin (botón *Arena de Raid*) con las medidas de `RaidArenaLayout`, y deja una copia `Workspace.RaidArenaPreview` para las fotos que `RaidService` borra al arrancar. Sin plantilla se usa una plataforma generada.

  En Studio, si no hay ningún `IslandSpawn`, `Dev/TestArena` construye un mundo de prueba con Nameku, Kono y el lobby de Raids. Si existe `Workspace.Map`, `Dev/MapValidator` lo valida al arrancar y muestra en la salida lo que falte. Para que el validador sepa en qué área está cada Part, las Parts hechas a mano van dentro de `Workspace.Map.<Área>`.
- **Raids:** `RaidService` gestiona filas (empiezan 15 s después del primer jugador), una arena por grupo creada en el aire (`y = 1500`), oleadas (`RaidOps.waveSpots`: jefes en el centro y el resto en puntos aleatorios de la pista con las distancias de `Raids.Arena`), el portal de salida (`RaidExit`, mantener 0.5 s: vuelve al lobby), recompensas por enemigo para todos los jugadores del Raid (Yenes como monedas) y logros. Salir del lobby saca de la fila. El estado se replica en atributos del jugador (`RaidQueue`, `RaidSessionId`, `RaidWave`, `RaidEndsAt`, `RaidReady_<Dificultad>`); los tiempos son unix (comparar con `workspace:GetServerTimeNow()`). Las recompensas de enemigos de Raid las da `RaidService`, no `CombatService`.
- **Portales:** desbloquean islas en orden pagando `Formulas.portalCost` y llevan al `IslandSpawn` de la isla. Las islas desbloqueadas se replican como atributos `Unlocked_<IslandId>` del jugador. Al entrar o reaparecer, el jugador aparece en `LastIsland`.
- **Enemigos en el mapa:** cada punto de spawn es una Part con la etiqueta `EnemySpawn` y los atributos `Island` (id de isla) y `Rank` (`Easy`, `Medium`, `Hard`, `Boss`). El modelo se toma de `ServerStorage.EnemyModels.<Island>.<Rank>` (ver **Modelos**); el ClickDetector va en el modelo, así que cualquier parte sirve para elegirlo. El servidor pone en el modelo los atributos `EnemyId`, `DisplayName`, `Health` y `MaxHealth`; el cliente dibuja la barra con ellos.
- **Combate:** el jugador hace clic en un enemigo (ClickDetector) y el servidor lo fija como objetivo si la isla está desbloqueada. Los personajes equipados golpean según su cooldown mientras el jugador esté a menos de `Balance.Combat.range`. El objetivo se replica en el atributo `TargetEnemyId` del jugador.
- **Modelos (preparados para Blender):** cada luchador y cada enemigo tiene su propio modelo en `assets/` (uno por personaje, uno por rango e isla y uno por tipo de Raid), sincronizado por Rojo. Todos son **rigs R6**: `HumanoidRootPart` (PrimaryPart, invisible, la única pieza anclada), `Torso`, `Head`, `Left Arm`, `Right Arm`, `Left Leg`, `Right Leg`, los Motor6D estándar (`RootJoint`, `Neck`, `Left/Right Shoulder`, `Left/Right Hip`) y `Humanoid` (sin nombre ni vida visibles) con `Animator`. Escala 1 = 5 studs de alto con los pies en y = 0; los enemigos más grandes escalan el rig entero. Los modelos finales de Blender sustituyen al provisional con el mismo nombre y ruta, guardados como `.rbxm`; mantienen esa estructura para que las animaciones R6 funcionen. El código no ancla las extremidades y apoya cada modelo por su punto más bajo. Flujo completo en `docs/plan.md` (Modelos y Blender). Si falta un modelo se usa un bloque provisional.
- **Personajes visibles:** todos los jugadores ven los personajes equipados de todos. El servidor replica el equipo en el atributo `EquippedCharacters` del jugador (ids en orden de ranura, separados por comas; sale de `InventoryOps.activeTeam`) y envía `Remotes.CharacterHit (dueño, enemyId, {ranura, daño})` a todos los clientes por cada golpe. Es solo para animar: el daño lo decide `CombatService`. `FollowerController` dibuja los modelos de `ReplicatedStorage.CharacterModels.<Isla>.<IdPersonaje>` sin colisión ni `CanQuery` para no tapar los clics, con el nombre encima. Caminan por el suelo (no flotan), todos a la misma velocidad (la del dueño ×1.25), y mueven brazos y piernas con los Motor6D del rig R6.
- **Efectos de golpe:** `HitEffectController` escucha `Remotes.CharacterHit` y, cuando la embestida conecta (`FollowerMotion.LUNGE_IN_TIME`), muestra el daño sobre el enemigo con el color de la rareza del personaje que golpea (Secreto: blanco con contorno dorado), en GothamBlack con contorno; el número salta, sube y se desvanece. Además, destello y chispas en el impacto, y una nube de humo cuando el enemigo muere. Los golpes propios se ven grandes; los de otros jugadores, más pequeños y solo cerca. Tamaños, tiempos y topes en `Client/Effects/HitStyle` (puro, `effects.spec`). Solo visual: el servidor no cambia.
- **Gacha en el mapa y en el HUD:** cada máquina es un pedestal con una estrella dorada (`Shared/Map/GachaStar`, la construyen el plugin y `TestArena`); el núcleo de la estrella es la Part con la etiqueta `GachaStand` y el atributo `Island`. `GachaController` hace girar y flotar las estrellas en el cliente y, a menos de 14 studs (en planta), abre en el HUD un panel Check-UI con los 7 personajes de la isla en 3D (`UI/CharacterViewport`), sus probabilidades (`Formulas.gachaChances`, con la Suerte si está activa) y dos botones: **Tirar x1** y **Tirar x10** (`Balance.GachaMultiRoll`; también E y R, o X e Y con mando). El cliente pide la tirada por `Remotes.GachaRoll (isla, cantidad)`; el servidor valida (cantidad 1 o 10, cerca de una estrella de esa isla, isla desbloqueada, espacio para todos, Yenes para todas), cobra `Formulas.gachaCost(isla, cantidad)` (x10 = 10 tiradas, sin descuento), tira con `GachaRoll.rollMany` (igual que tiradas sueltas seguidas, con pity) y responde por `Remotes.GachaResult` con la lista de resultados.
- **Animación del gacha:** a pantalla completa sobre el HUD (`UI/GachaRevealView`): la pantalla se oscurece, entra una estrella dorada que se carga (late, tiembla, sacude la pantalla y sube por los colores de rareza hasta la mejor obtenida, con un anillo en cada paso) y estalla con destello, onda y confeti. Una tirada muestra una carta grande con el personaje girando en 3D, cinta de rareza, estrellas de rareza y daño; diez tiradas colocan diez cartas boca abajo que se voltean de peor a mejor, con pausa y onda antes de cada Legendario o superior. Brillo en Legendario y superiores, doble capa de rayos en Mítico y Secreto, arcoíris en Secreto. Un clic, toque, E, Espacio o A adelanta. Tiempos y movimientos en `Client/Effects/GachaReveal` (puro, `effects.spec`); solo visual. En Studio, `Client/Dev/RevealPreview` (temporal) la reproduce sin tirar: Ctrl + 1..7 una tirada de cada rareza, Ctrl + 8 y 9 diez tiradas.
- **Sonido y música:** los ids de audio están en `Shared/Config/Sounds` (efectos con volumen, 2D o 3D, límite de copias y separación mínima; una pista de música por área y `RaidBoss`). Un id vacío no suena, así que cada sonido ya está enganchado y basta con poner su id. `SoundController` (cliente) los reproduce: `play` en pantalla, `playAt` en una posición del mundo (golpes y muertes, hasta `Sounds.SpatialRange`) y `coin` (tono que sube mientras las monedas se recogen seguidas); limita cada efecto y el total (`Sounds.MaxEffects`) con `Client/Effects/SoundMix` (puro, `sound.spec`). Los golpes suenan más graves cuanto más rara es la rareza del personaje y más bajos si son de otros jugadores. La música cambia con fundido al cambiar `CurrentArea`, y en el Raid pasa a `RaidBoss` en la última oleada (`RaidWave`). Los botones de `CheckUI.bind` suenan al pasar y al pulsar; `Notify.error` suena como error. Las opciones de música y efectos se guardan en `Data.Settings` (`Sounds.Settings`), se cambian con `Remotes.SetSetting (nombre, valor)` (`SettingsService`, validado con `SettingsOps`) y se replican en los atributos `SettingMusic` y `SettingEffects`, que silencian los grupos `Music` y `Effects` de SoundService.
- **Boosts:** `BoostService` activa boosts, los vende por Gemas y descuenta el tiempo cada segundo solo para jugadores conectados. Cualquier sistema que dé boosts usa `BoostService.grant`. Se replican como atributos `BoostOwned_<Id>` y `BoostTime_<Id>`. Los efectos se leen de `data.Boosts.Remaining.<Id> > 0` donde se calcula cada recompensa.
- **Inventario:** toda la lógica está en `InventoryOps` (pura). Los cambios en personajes siempre pasan por `InventoryService` (por ejemplo `addCharacter`), que envía el estado al cliente por `Remotes.InventoryChanged`. El cliente pide acciones por `Remotes.InventoryAction` y recibe el resultado más un snapshot.
- **Interfaz (estilo oficial Check-UI):** toda la UI de pantalla (HUD, inventario, gacha, boosts, Raids, avisos) sigue la skill `check-ui-clean-roblox`: tipografía `GothamBlack` con contorno negro, ventanas opacas `#3B5866` con borde oscuro, cabeceras con degradado por tipo de menú y divisor de dos líneas, botón de cerrar `[X]` con relieve, botones con relieve y tríada de estados (Reclamar, Reclamado, Bloqueado), iconos con `ScaleType.Fit`, interacciones desde el centro (`AnchorPoint` 0.5 y `UIScale`) y escalado según `ViewportSize`. Los tokens y constructores Check-UI (ventana, cabecera, `[X]`, botón estándar con paletas de la tríada, escalado) viven en `src/client/UI/CheckUI` y los colores de rareza en `src/client/UI/Theme`; los controladores no ponen colores a mano. Los textos en el mundo 3D (carteles, títulos de portales) mantienen su estilo propio. Antes de tocar la UI, cargar la skill.
- **Intangibles:** los personajes (luchadores) y los enemigos no chocan con nada: el jugador los atraviesa. `Shared/Intangible` pone `CanCollide`/`CanTouch` a false y el grupo de colisión `Intangible` (necesario porque el `Humanoid` vuelve a activar la colisión del torso y la cabeza), y mete los personajes de los jugadores en el grupo `Players`, que no choca con `Intangible`. `Intangible` debe seguir chocando con `Default`: los clics (`ClickDetector`) y los raycasts usan el grupo `Default` e ignoran las partes de grupos que no chocan con él, y los enemigos dejarían de poder seleccionarse. El servidor lo arranca con `Intangible.start()` en `Main.server.luau`.
- **Eventos entre servicios:** usar `Server.Signal`, nunca `BindableEvent`: un BindableEvent entrega copias de las tablas, así que comparar o usar como clave el enemigo o los datos recibidos falla (por eso los Raids no pasaban de la primera oleada). `EnemyService.Clicked`/`Died` y `DataService.Loaded`/`Releasing` son Signals.
- **Remotes:** los crea el servidor con `Remotes.event(name)`; el cliente los espera con `ReplicatedStorage.Remotes:WaitForChild(name)`. Nunca confiar en datos del cliente sin validarlos en el servidor.
- **Acceso a datos:** los demás servicios usan `DataService.getData`/`waitForData` y `addCurrency`/`spendCurrency`. Yenes y Gemas se replican al cliente como atributos del jugador (`Yen`, `Gems`).
- **Fuente de verdad de datos:** las constantes viven en `src/shared/Config/` y el contenido (islas, personajes) en `src/shared/Data/`. Los valores derivados (daño, vida, Yenes, costos) se calculan siempre con `Shared.Formulas`; nunca escribir esos números a mano en otro sitio.
- **Lógica sensible en el servidor:** tiradas del gacha, daño, monedas y pity se calculan en el servidor; el cliente solo envía peticiones y muestra resultados.

## 7. Reglas de trabajo para Claude

- Antes de cambiar código, leer los archivos relacionados.
- Hacer cambios pequeños y verificables; explicar las decisiones no obvias.
- No añadir dependencias nuevas sin preguntar.
- No modificar assets binarios ni datos de diseño sin confirmación.
- Ejecutar las pruebas o el build después de cambios relevantes, e informar del resultado tal cual.
- **Mantener los documentos al día:** cada cambio de diseño, regla o sistema se guarda en este archivo (constitución) si afecta a sus reglas, y siempre se refleja en `docs/spec.md`, `docs/plan.md` y `docs/tasks.md` dentro del mismo trabajo y del mismo commit. El detalle va en `docs/game-design.md` y los números en `docs/balance.md`; spec y plan enlazan a ellos en lugar de duplicarlos.
- Hacer commit y push solo cuando el usuario lo pida.

## 8. Registro de decisiones

Decisiones cerradas. Las tareas pendientes están en `docs/tasks.md`.

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
- [x] Máximo de equipados: 6 (3 iniciales + 3 logros de Raid).
- [x] Respawn: 20 segundos los enemigos normales, 1 minuto los jefes.
- [x] Nombres provisionales de personajes aceptados.
- [x] Inicio lento aceptado: el jugador nuevo empieza con 0 Yenes y solo Kurilin (primera tirada a los ~6 min).
- [x] Eliminar personajes: permitido sin recompensa; no se puede eliminar uno equipado ni el último.
- [x] `DevCheats` (servidor) y `RevealPreview` (cliente) son temporales y se eliminan antes de publicar (ver `docs/tasks.md`).
- [x] Personajes visibles para todos los jugadores; los golpes se sincronizan con un evento del servidor por golpe (`CharacterHit`).
- [x] Modelos en rig R6, uno por luchador y por enemigo, en `assets/` para exportarlos y rehacerlos en Blender.
- [x] Islas de alta calidad: dirección de arte por anime aprobada (`docs/game-design.md`), construidas por código con el plugin Island Builder; Nameku primero como isla de prueba del estilo.
- [x] Las islas están en el mar (no flotan), con mar de estilo cartoon (textura animada y espuma en la orilla).
- [x] La ambientación por isla (luz, cielo, niebla, partículas) entra en la Fase 9.
- [x] Cada isla con su propia organización, terreno (no reutilizado), relieve y decoración; nada de islas planas.
- [x] Las 6 islas aprobadas tal cual tras dos rondas de capturas (incluido el estilo de Nameku).
- [x] Plan de desarrollo aprobado (orden en `docs/plan.md`): cerrar la Fase 9, efectos y sonido, UI Check-UI, prueba temprana en servidor publicado, publicación; los modelos de Blender en paralelo.
- [x] Check-UI (skill `check-ui-clean-roblox`) es el estilo oficial de la UI.
- [x] Formato con StyLua y linter con selene; luau y luau-lsp también fijados en `rokit.toml`.
- [x] Raids: portal de salida dentro del coliseo hacia el lobby de Raids; enemigos en puntos aleatorios de la pista en cada oleada.
- [x] Yenes como monedas flotantes que el jugador recoge (se pagan solas a los 30 s y al salir del juego; nunca se pierden).
- [x] Eventos entre servicios con `Signal` (no `BindableEvent`).
- [x] Raids de 20 oleadas siempre (también en Studio): 4 débiles + 2 medianos + 1 fuerte por oleada, ×1.03 por oleada; mini jefe en la 10 y jefe final en la 20, en el centro del coliseo.
- [x] Personajes y enemigos intangibles (grupo de colisión `Intangible`).
- [x] Números de daño del color de la rareza del personaje que golpea, grandes los propios y pequeños los de otros jugadores; destello, chispas y humo al morir.
- [x] Sonido: los ids de audio los elige el usuario (Toolbox o subidos) y se ponen en `Config/Sounds`; mientras tanto el sistema está completo y en silencio.
- [x] Gacha en el HUD: panel Check-UI junto a la máquina con Tirar x1 y Tirar x10 (10 veces el costo, sin descuento; necesita 10 espacios) y animación a pantalla completa; la máquina es una estrella dorada que gira.
