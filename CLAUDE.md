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
  - Enemigos estáticos con barra de vida sobre la cabeza. Al ser derrotados dan dinero (Yenes).
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
│   │   ├── Main.server.luau  # Arranca los servicios en orden
│   │   ├── Remotes.luau      # Crea los RemoteEvents en ReplicatedStorage.Remotes
│   │   ├── Services/         # Data, Enemy, Combat, Gacha, Inventory, Portal, Raid, Boost (…Service)
│   │   ├── Data/             # PlayerRecord (forma de los datos guardados)
│   │   ├── Combat/           # Lógica pura de combate (AttackClock)
│   │   ├── Gacha/            # Lógica pura del gacha (GachaRoll)
│   │   ├── Inventory/        # Lógica pura del inventario (InventoryOps)
│   │   ├── Portals/          # Lógica pura de desbloqueo y viaje (PortalOps)
│   │   ├── Raids/            # Lógica pura de Raids (RaidOps)
│   │   ├── Boosts/           # Lógica pura de boosts (BoostOps)
│   │   └── Dev/              # Ayudas solo para Studio (TestArena; DevCheats es temporal)
│   ├── client/               # StarterPlayer.StarterPlayerScripts.Client — UI, efectos, control
│   │   ├── Main.client.luau  # Arranca los controladores
│   │   ├── UI/               # Theme (colores y constructores), Notify (avisos en pantalla)
│   │   ├── Followers/        # Lógica pura de los personajes visibles (FollowerMotion)
│   │   └── Controllers/      # Hud, Enemy (barras de vida), Gacha, Inventory (panel), Portal, Raid, Boost, Follower
│   └── shared/               # ReplicatedStorage.Shared — módulos compartidos
│       ├── Formulas.luau     # Valores derivados: daño, vida, Yenes, costos
│       ├── Format.luau       # Formato de números para la UI (1.5K, 2.3M)
│       ├── Config/           # Constantes: Balance, Rarities, Raids, Boosts
│       └── Data/             # Contenido: Islands, Characters
├── docs/
│   ├── spec.md               # Especificación (qué)
│   ├── plan.md               # Plan técnico (cómo)
│   ├── tasks.md              # Tareas hechas y pendientes
│   ├── game-design.md        # Diseño detallado
│   └── balance.md            # Valores numéricos
├── assets/                   # Modelos (.rbxmx/.rbxm) que Rojo sincroniza
│   ├── CharacterModels/      # ReplicatedStorage.CharacterModels.<Isla>.<IdPersonaje> — luchadores
│   └── EnemyModels/          # ServerStorage.EnemyModels.<Isla>.<Rango> y .Raid.<Tipo> — enemigos
├── tools/
│   └── build_rigs.py         # Genera los rigs R6 provisionales que falten
└── tests/                    # Pruebas (*.spec.luau, run.py, bundle.py)
```

## 4. Comandos

- **Instalar herramientas:** `rokit install` (instala la versión de Rojo fijada en `rokit.toml`).
- **Ejecutar en desarrollo:** `rojo serve`, y en Roblox Studio conectar desde el plugin de Rojo (pestaña Plugins → Rojo → Connect).
- **Build / exportar:** `rojo build -o AnimeLegends.rbxlx` (los `.rbxl`/`.rbxlx` están en `.gitignore`).
- **Pruebas:** `python tests/run.py` ejecuta todos los `tests/*.spec.luau`. Requiere Python y el CLI de Luau (`luau`, de github.com/luau-lang/luau/releases; si no está en el PATH, indicar su ruta en la variable `LUAU`). `tests/bundle.py` empaqueta `src/shared`, `src/server` y `src/client` con una imitación de `script` para que los `require` por instancia funcionen fuera de Studio; solo sirve para módulos puros, sin servicios de Roblox.
  - `balance.spec.luau`: `Formulas` reproduce las tablas de `docs/balance.md`. Si se cambia el balance, actualizar ambos.
  - `player-record.spec.luau`: datos iniciales, reconciliación, migraciones y bloqueo de sesión.
  - `combat.spec.luau`: tiempos de ataque, recompensas y formato de números.
  - `gacha.spec.luau`: probabilidades, Boost de Suerte, pity y distribución de tiradas.
  - `inventory.spec.luau`: añadir, equipar, desequipar, eliminar, "Equipar mejores" y ampliaciones.
  - `portal.spec.luau`: orden de desbloqueo, viajes e isla de aparición.
  - `raid.spec.luau`: esperas, completados y logros de ranuras, recompensas, drops de boosts y oleadas.
  - `boost.spec.luau`: conceder, activar (acumula duración) y descontar tiempo.
  - `followers.spec.luau`: formación, arco alrededor del objetivo, embestida (más corta que el cooldown más rápido), velocidad de marcha, ciclo de caminar y giro de los personajes visibles.
- **Modelos provisionales:** `python tools/build_rigs.py` crea el rig R6 de cada luchador y enemigo que no tenga modelo (nunca sobrescribe; `--force` regenera solo los `.rbxmx`). `python tools/build_rigs.py --check` falla si falta alguno: ejecutarlo al añadir personajes, islas, rangos o tipos de enemigo de Raid.
- **Revisión de tipos (incluye código con APIs de Roblox):** `rojo sourcemap default.project.json -o sourcemap.json` y luego `luau-lsp analyze --platform=roblox --definitions=globalTypes.d.luau --sourcemap=sourcemap.json src`. `luau-lsp` y `globalTypes.d.luau` vienen de github.com/JohnnyMorganz/luau-lsp. Debe terminar sin errores.

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
- **Construir el mapa:** el código no depende de posiciones; lee Parts etiquetadas (CollectionService) con atributos:

  | Etiqueta | Atributos | Qué es |
  |---|---|---|
  | `IslandSpawn` | `Island` | Punto de llegada a una isla (uno por isla) |
  | `EnemySpawn` | `Island`, `Rank` | Punto de aparición de un enemigo |
  | `GachaStand` | `Island` | Máquina de gacha |
  | `Portal` | `TargetIsland` | Portal hacia otra isla (la Part base; el haz de luz es decorativo) |
  | `RaidPortal` | — | Portal hacia el lobby de Raids (en Nameku) |
  | `RaidLobbySpawn` | — | Punto de llegada al lobby de Raids |
  | `RaidPad` | `Difficulty` (`Easy`, `Medium`, `Hard`) | Plataforma para entrar a la fila de un Raid |

  Modelos de enemigos en `ServerStorage.EnemyModels.<Isla>.<Rango>` y `EnemyModels.Raid.<Tipo>` (vienen de `assets/EnemyModels`, ver **Modelos**). Opcional: `ServerStorage.RaidArena` (Model con PrimaryPart, una Part `PlayerSpawn` y una carpeta `EnemySpawns` de Parts) para la arena de Raid; sin ella se usa una plataforma generada.

  En Studio, si no hay ningún `IslandSpawn`, `Dev/TestArena` construye un mundo de prueba con Nameku, Kono y el lobby de Raids.
- **Raids:** `RaidService` gestiona filas (empiezan 15 s después del primer jugador), una arena por grupo creada en el aire (`y = 1500`), oleadas, recompensas por enemigo para todos los jugadores del Raid y logros. El estado se replica en atributos del jugador (`RaidQueue`, `RaidSessionId`, `RaidWave`, `RaidEndsAt`, `RaidReady_<Dificultad>`); los tiempos son unix (comparar con `workspace:GetServerTimeNow()`). Las recompensas de enemigos de Raid las da `RaidService`, no `CombatService`.
- **Portales:** desbloquean islas en orden pagando `Formulas.portalCost` y llevan al `IslandSpawn` de la isla. Las islas desbloqueadas se replican como atributos `Unlocked_<IslandId>` del jugador. Al entrar o reaparecer, el jugador aparece en `LastIsland`.
- **Enemigos en el mapa:** cada punto de spawn es una Part con la etiqueta `EnemySpawn` y los atributos `Island` (id de isla) y `Rank` (`Easy`, `Medium`, `Hard`, `Boss`). El modelo se toma de `ServerStorage.EnemyModels.<Island>.<Rank>` (ver **Modelos**); el ClickDetector va en el modelo, así que cualquier parte sirve para elegirlo. El servidor pone en el modelo los atributos `EnemyId`, `DisplayName`, `Health` y `MaxHealth`; el cliente dibuja la barra con ellos.
- **Combate:** el jugador hace clic en un enemigo (ClickDetector) y el servidor lo fija como objetivo si la isla está desbloqueada. Los personajes equipados golpean según su cooldown mientras el jugador esté a menos de `Balance.Combat.range`. El objetivo se replica en el atributo `TargetEnemyId` del jugador.
- **Modelos (preparados para Blender):** cada luchador y cada enemigo tiene su propio modelo en `assets/` (uno por personaje, uno por rango e isla y uno por tipo de Raid), sincronizado por Rojo. Todos son **rigs R6**: `HumanoidRootPart` (PrimaryPart, invisible, la única pieza anclada), `Torso`, `Head`, `Left Arm`, `Right Arm`, `Left Leg`, `Right Leg`, los Motor6D estándar (`RootJoint`, `Neck`, `Left/Right Shoulder`, `Left/Right Hip`) y `Humanoid` (sin nombre ni vida visibles) con `Animator`. Escala 1 = 5 studs de alto con los pies en y = 0; los enemigos más grandes escalan el rig entero. Los modelos finales de Blender sustituyen al provisional con el mismo nombre y ruta, guardados como `.rbxm`; mantienen esa estructura para que las animaciones R6 funcionen. El código no ancla las extremidades y apoya cada modelo por su punto más bajo. Flujo completo en `docs/plan.md` (Modelos y Blender). Si falta un modelo se usa un bloque provisional.
- **Personajes visibles:** todos los jugadores ven los personajes equipados de todos. El servidor replica el equipo en el atributo `EquippedCharacters` del jugador (ids en orden de ranura, separados por comas; sale de `InventoryOps.activeTeam`) y envía `Remotes.CharacterHit (dueño, enemyId, {ranura, daño})` a todos los clientes por cada golpe. Es solo para animar: el daño lo decide `CombatService`. `FollowerController` dibuja los modelos de `ReplicatedStorage.CharacterModels.<Isla>.<IdPersonaje>` sin colisión ni `CanQuery` para no tapar los clics, con el nombre encima. Caminan por el suelo (no flotan), todos a la misma velocidad (la del dueño ×1.25), y mueven brazos y piernas con los Motor6D del rig R6.
- **Gacha en el mapa:** cada máquina es una Part con la etiqueta `GachaStand` y el atributo `Island`. El servidor le añade un ProximityPrompt; al activarlo valida (isla desbloqueada, espacio en inventario, Yenes), tira con `GachaRoll` y envía el resultado por `Remotes.GachaResult`.
- **Boosts:** `BoostService` activa boosts, los vende por Gemas y descuenta el tiempo cada segundo solo para jugadores conectados. Cualquier sistema que dé boosts usa `BoostService.grant`. Se replican como atributos `BoostOwned_<Id>` y `BoostTime_<Id>`. Los efectos se leen de `data.Boosts.Remaining.<Id> > 0` donde se calcula cada recompensa.
- **Inventario:** toda la lógica está en `InventoryOps` (pura). Los cambios en personajes siempre pasan por `InventoryService` (por ejemplo `addCharacter`), que envía el estado al cliente por `Remotes.InventoryChanged`. El cliente pide acciones por `Remotes.InventoryAction` y recibe el resultado más un snapshot.
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
- [x] `DevCheats` es temporal y se elimina antes de publicar (ver `docs/tasks.md`).
- [x] Personajes visibles para todos los jugadores; los golpes se sincronizan con un evento del servidor por golpe (`CharacterHit`).
- [x] Modelos en rig R6, uno por luchador y por enemigo, en `assets/` para exportarlos y rehacerlos en Blender.
