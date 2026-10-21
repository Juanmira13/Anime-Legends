# Anime Legends — Balance (propuesta inicial)

Valores iniciales para probar y ajustar. Inspirados en el estilo de Anime Fighters Simulator (AFS): el jugador elige un enemigo, sus personajes equipados lo atacan, el enemigo da Yenes y los Yenes se gastan en tiradas de gacha y en portales a islas más fuertes.

Los números se generan con un modelo sencillo (ver "Cómo ajustar" al final), así que cambiar una constante reajusta todo de forma proporcional.

## Reglas del modelo

- **Multiplicador por isla: ×6.** Daño de personajes, vida de enemigos, Yenes y costos se multiplican por 6 en cada isla.
- **Salto entre islas:** un personaje Común de una isla tiene casi el mismo daño por segundo que un Épico de la isla anterior. Al llegar a una isla nueva, los mejores personajes de la anterior siguen sirviendo, pero el jugador necesita tirar en el gacha nuevo para avanzar.
- **Equipo de referencia:** la vida de los enemigos se calcula para que un equipo de 3 personajes Raros de esa isla los derrote en un tiempo fijo por rango.
- **Recompensa:** los enemigos más difíciles dan un poco más de Yenes por segundo, para premiar a quien tiene mejor equipo.

## Personajes: daño por golpe y cooldown

El cooldown es igual en todas las islas. El daño crece ×6 por isla.

| Rareza | Cooldown | Nameku | Kono | Clover Kingdom | Titan Village | Hero Academy | Demon Corps |
|---|---|---|---|---|---|---|---|
| Común | 2.0 s | 10 | 60 | 360 | 2.2K | 13K | 78K |
| Poco común | 1.9 s | 16 | 96 | 580 | 3.5K | 21K | 120K |
| Raro | 1.8 s | 26 | 160 | 940 | 5.6K | 34K | 200K |
| Épico | 1.6 s | 45 | 270 | 1.6K | 9.7K | 58K | 350K |
| Legendario | 1.4 s | 80 | 480 | 2.9K | 17K | 100K | 620K |
| Mítico | 1.2 s | 150 | 900 | 5.4K | 32K | 190K | 1.2M |
| Secreto | 1.0 s | 300 | 1.8K | 11K | 65K | 390K | 2.3M |

Daño respecto al Común de su isla: Poco común ×1.6, Raro ×2.6, Épico ×4.5, Legendario ×8, Mítico ×15, Secreto ×30.

## Enemigos: vida por rango

| Rango | Tiempo para derrotarlo* | Nameku | Kono | Clover Kingdom | Titan Village | Hero Academy | Demon Corps |
|---|---|---|---|---|---|---|---|
| Fácil | 4 s | 170 | 1K | 6.2K | 37K | 220K | 1.3M |
| Medio | 10 s | 430 | 2.6K | 16K | 94K | 560K | 3.4M |
| Difícil | 25 s | 1.1K | 6.5K | 39K | 230K | 1.4M | 8.4M |
| Jefe | 2 min | 5.2K | 31K | 190K | 1.1M | 6.7M | 40M |

\* Con el equipo de referencia (3 Raros de esa isla).

Respawn: 20 s los enemigos normales, 1 min los jefes.

Cantidad sugerida por isla: 10 Fáciles, 8 Medios y 5 Difíciles, cada grupo en su propia zona, más 1 Jefe en una zona aparte. Con el respawn de 20 s, así siempre hay enemigos disponibles.

## Enemigos: Yenes por derrota

Los Yenes caen como monedas (`Balance.Coins`): la recompensa se reparte en 2 monedas si tiene una cifra y una más por cada cifra extra, hasta 8, y las monedas suman exacto. Se recogen a menos de 20 studs, el servidor acepta recogidas hasta 45 studs de la tanda, y a los 30 s se pagan solas.


| Rango | Nameku | Kono | Clover Kingdom | Titan Village | Hero Academy | Demon Corps |
|---|---|---|---|---|---|---|
| Fácil | 5 | 30 | 180 | 1.1K | 6.5K | 39K |
| Medio | 15 | 90 | 540 | 3.2K | 19K | 120K |
| Difícil | 45 | 270 | 1.6K | 9.7K | 58K | 350K |
| Jefe | 300 | 1.8K | 11K | 65K | 390K | 2.3M |

Yenes por segundo con el equipo de referencia: Fácil 1.25, Medio 1.5, Difícil 1.8 y Jefe 2.5 (×6 por isla).

## Costos: gacha y portales

| Isla | Tirada de gacha | Portal para entrar | Farmeo aproximado para el portal** |
|---|---|---|---|
| Nameku | 50 | Gratis (inicio) | — |
| Kono | 300 | 2.7K | 30 min en Nameku |
| Clover Kingdom | 1.8K | 32K | 1 h en Kono |
| Titan Village | 11K | 290K | 1 h 30 min en Clover Kingdom |
| Hero Academy | 65K | 2.3M | 2 h en Titan Village |
| Demon Corps | 390K | 21M | 3 h en Hero Academy |

\*\* Solo el tiempo de farmeo para pagar el portal. Como el jugador también gasta Yenes en el gacha, el tiempo real en cada isla es aproximadamente el doble.

La tirada x10 cuesta exactamente 10 tiradas (sin descuento): 500 ¥ en Nameku.

Una tirada cuesta lo que se gana en unos 33 s farmeando enemigos Medios de esa isla, unas 100 tiradas por hora. Con las probabilidades del gacha, eso da un Legendario cada ~30 min, un Mítico cada ~1 h y un Secreto cada ~10 h de farmeo, en promedio.

## Inventario

Empieza con 50 personajes. Cada compra añade +10 espacios y cuesta ×1.5 la anterior. Máximo propuesto: 250.

| Compra | Capacidad | Costo |
|---|---|---|
| 1 | 60 | 10K |
| 2 | 70 | 15K |
| 3 | 80 | 23K |
| 4 | 90 | 34K |
| 5 | 100 | 51K |
| 6 | 110 | 76K |
| 7 | 120 | 110K |
| 8 | 130 | 170K |
| 9 | 140 | 260K |
| 10 | 150 | 380K |
| 11 | 160 | 580K |
| 12 | 170 | 860K |
| 13 | 180 | 1.3M |
| 14 | 190 | 1.9M |
| 15 | 200 | 2.9M |
| 16 | 210 | 4.4M |
| 17 | 220 | 6.6M |
| 18 | 230 | 9.9M |
| 19 | 240 | 15M |
| 20 | 250 | 22M |

## Raids

Cada dificultad está calibrada para el equipo de referencia de una isla:

| Dificultad | Pensado para un equipo de |
|---|---|
| Fácil | Kono |
| Medio | Titan Village |
| Difícil | Demon Corps |

### Composición de oleadas (igual en las 3 dificultades)

| Oleadas | Enemigos |
|---|---|
| Todas (1–20) | 4 débiles + 2 medianos + 1 fuerte |
| 10 | además, el mini jefe |
| 20 | además, el jefe final |

**Crecimiento por oleada:** ×1.03 de vida y de Yenes respecto a la oleada anterior (`Raids.WaveGrowth`), igual para todos los tipos: la oleada 20 es ×1.75 la 1. Las Gemas por enemigo no cambian con la oleada.

En total: 80 débiles, 40 medianos, 20 fuertes, 1 mini jefe y 1 jefe final. Con el equipo de referencia, un jugador solo termina en unos 24 minutos, dentro del límite de 30. En grupo es más rápido.

Tiempo para derrotarlos con el equipo de referencia (oleada 1): débil 3 s, mediano 8 s, fuerte 12 s, mini jefe 60 s, jefe final 150 s.

### Vida de enemigos de Raid (oleada 1; después ×1.03 por oleada)

| Tipo | Fácil | Medio | Difícil |
|---|---|---|---|
| Débil | 780 | 28K | 1M |
| Mediano | 2.1K | 75K | 2.7M |
| Fuerte | 3.1K | 110K | 4M |
| Mini jefe | 16K | 560K | 20M |
| Jefe final | 39K | 1.4M | 51M |

Con el crecimiento: un débil de la oleada 20 tiene 1.4K / 49K / 1.8M; el mini jefe (oleada 10), 20K / 730K / 26M; el jefe final (oleada 20), 68K / 2.5M / 89M.

### Recompensas por enemigo

Cada jugador del Raid recibe la recompensa completa de cada enemigo. Yenes de la oleada 1 (después ×1.03 por oleada, como monedas); las Gemas no crecen.

| Tipo | Fácil | Medio | Difícil |
|---|---|---|---|
| Débil | 1 Gema + 30 ¥ | 3 Gemas + 1.1K ¥ | 7 Gemas + 39K ¥ |
| Mediano | 3 Gemas + 90 ¥ | 6 Gemas + 3.2K ¥ | 14 Gemas + 120K ¥ |
| Fuerte | 5 Gemas + 180 ¥ | 12 Gemas + 6.5K ¥ | 30 Gemas + 230K ¥ |
| Mini jefe | 20 Gemas + 1.4K ¥ | 50 Gemas + 49K ¥ | 120 Gemas + 1.7M ¥ |
| Jefe final | 50 Gemas + 5.4K ¥ | 150 Gemas + 190K ¥ | 400 Gemas + 7M ¥ |
| **Total del Raid completo** | **370 Gemas + 24K ¥** | **920 Gemas + 870K ¥** | **2,240 Gemas + 31M ¥** |

Gemas por hora de espera: Fácil ~370, Medio ~613, Difícil ~1,120. Las dificultades altas siempre rinden más.

## Boosts

Hay 3 boosts. Duran 15 minutos y se obtienen de dos formas: como drop de los enemigos de los Raids o comprándolos con Gemas en la tienda.

| Boost | Efecto (propuesta) |
|---|---|
| Suerte | ×2 probabilidad de Legendario, Mítico y Secreto en el gacha |
| Dinero | ×2 Yenes |
| Gemas | ×2 Gemas |

### Probabilidad de drop (propuesta)

Cada enemigo derrotado tiene una probabilidad de soltar un boost al azar entre los 3. El jefe final siempre suelta uno.

| Tipo | Fácil | Medio | Difícil |
|---|---|---|---|
| Débil | 0.5% | 0.75% | 1% |
| Mediano | 1% | 1.5% | 2% |
| Fuerte | 2% | 3% | 4% |
| Mini jefe | 25% | 37.5% | 50% |
| Jefe final | 100% | 100% | 100% |
| **Boosts esperados por Raid completo** | **~2.4** | **~3.2** | **~3.9** |

Supuestos (a confirmar):
- Cada jugador del Raid tira su propio drop.
- Los boosts se guardan y el jugador los activa cuando quiere.
- Activar un boost que ya está activo suma 15 minutos a su duración.

### Tienda (propuesta)

| Boost | Precio |
|---|---|
| Dinero | 125 Gemas |
| Suerte | 200 Gemas |
| Gemas | 300 Gemas |

El Boost de Gemas es el más caro porque se paga a sí mismo: activado durante un Raid Difícil devuelve más Gemas de las que cuesta. Así sigue siendo útil sin volverse una fuente infinita de Gemas.

Pendiente: otros usos de las Gemas (tiradas de gacha con Gemas, items).

## Inicio del jugador

El jugador nuevo empieza con 0 Yenes y solo Kurilin (10 de daño cada 2 s). Un enemigo Fácil de Nameku tarda ~34 s y la primera tirada de gacha llega a los ~6 minutos. Es un ritmo de inicio aceptado a propósito: no acelerarlo sin decidirlo antes.

## Cómo ajustar

El modelo está en estas constantes; cambiar una reajusta todas las tablas de forma proporcional:

| Constante | Valor | Efecto |
|---|---|---|
| Multiplicador por isla | ×6 | Cuánto más fuerte es cada isla |
| Daño base (Común de Nameku) | 10 | Escala de todos los daños |
| Tiempo para derrotar por rango | 4 s / 10 s / 25 s / 2 min | Dificultad de los enemigos |
| Yenes por rango en Nameku | 5 / 15 / 45 / 300 | Velocidad de ganancia |
| Tirada de gacha en Nameku | 50 | Frecuencia de tiradas |
| Horas de farmeo por portal | 0.5 / 1 / 1.5 / 2 / 3 | Duración del grinding por isla |

Para un grinding más largo, subir las horas por portal o bajar los Yenes por rango. Para que los personajes nuevos se noten más, subir el multiplicador por isla.
