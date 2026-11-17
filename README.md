# ChessPawnStructures

Estructuras de peones en Swift: un tipo `PawnStructure` sobre dos bitboards, rasgos calculados con operaciones de bits, el catálogo de las 28 estructuras de *Chess Structures* (Flores Rios) más 4 genéricas con textos para mostrarlas (regla y planes, en español e inglés), y una distancia para buscar estructuras parecidas.

Pensado para indexar bases de partidas (etiquetas por clave de peones), explicar la estructura de una posición, construir árboles de estructuras y buscar estructuras parecidas.

- Swift 6, iOS 18 / macOS 15, sin dependencias.
- Puro: sin estado global mutable ni E/S. Todo es `Sendable`.
- Rápido: `StructureCatalog.mask` ≈ 50 ns por posición (ver [Rendimiento](#rendimiento)).

```swift
.package(url: "https://github.com/NSStudent/ChessPawnStructures.git", from: "0.1.0")
```

## Uso

```swift
import ChessPawnStructures

let s = PawnStructure(fen: "r1bq1rk1/pp2bppp/2n1pn2/8/3P4/2NB1N2/PP3PPP/R1BQ1RK1 w - - 0 10")!

StructureCatalog.classify(s)          // Set<StructureID>: [Peón aislado (IQP)]
StructureCatalog.primary(s)           // StructureID(.isolatedQueenPawn, reversed: false)
s.structures                          // StructureSet (bitset de 64 bits, para el índice)

s.isolated(.white)                    // bitboard con d4
s.traits.black.islands                // 2
s.colorsReversed                      // la misma estructura con colores invertidos
s.fileKey                             // "11010111/11001111" (modo «Files» de Scid)

s.summary(locale: .current)?.text     // nombre, regla y planes de la estructura principal (es/en)
StructureKind.carlsbad.text(.english) // textos en la orientación del libro

StructureDistance()(s, otra)          // distancia ponderada
nearest(s, in: candidatas)            // (index, structure, distance)?

// Una partida: estructura tras cada ply → estructuras que duran ≥ 6 plies.
structuresVisited(estructurasPorPly)  // StructureSet
```

Los bitboards de peones de Polyglot o python-chess se usan sin conversión: `PawnStructure(white: board.pawns & board.occupied_co[WHITE], …)`.

## API

### `PawnStructure`

| Miembro | Qué hace |
|---|---|
| `init(white:black:)` | Dos `UInt64`, a1 = bit 0, b1 = bit 1, …, h8 = bit 63 (la convención de Polyglot y python-chess). |
| `init?(fen:)` | Lee los peones del campo de colocación de un FEN. |
| `white`, `black`, `subscript(Side)`, `all` | Bitboards. |
| `colorsReversed` | Espejo vertical + cambio de bando (involución). La Carlsbad del Gambito de Dama Cambio invertida es la de la Caro-Kann Cambio. |
| `mirroredHorizontally` | Espejo a ↔ h (no lo usan las reglas). |
| `fileKey` | `FileKey`: nº de peones por columna y color en 64 bits (4 bits por columna y color). Dos estructuras con la misma clave tienen los mismos peones en cada columna aunque cambien las filas. |
| `fenPlacement`, `description` | Solo peones, para depurar. |
| Rasgos | `isolated`, `doubled`, `doubledCount`, `passed`, `backward`, `connected`, `chainMembers`, `chains`, `chainCount`, `chainBases`, `islands`, `hanging`, `files`, `openFiles`, `semiOpenFiles`, `pawnCount(_:on:)`, `majority(on:)`, `holes`, `traits`. |

`Square.mask("d4 e5")`, `Square.index("d4")` y `Square.names(bitboard)` convierten nombres de casillas.

### Catálogo

| Tipo | Qué es |
|---|---|
| `StructureKind` | Las 32 estructuras: las 28 del libro en su orden (`rawValue` 0…27) y 4 genéricas (28…31). |
| `StructureID` | Estructura + orientación (`reversed`). `bit = kind * 2 + reversed` (0…63). |
| `StructureSet` | Bitset de 64 bits de `StructureID`; es lo que se guarda por partida (`structuresVisited`). |
| `StructureDefinition` | Nombre (es/en), familia, página del PDF, condición, `typical`, `specificity`. |
| `SidePattern` / `StructurePattern` | La regla declarativa: casillas exigidas, hasta dos grupos de alternativas, columnas vacías y columnas ocupadas. |
| `StructureCatalog` | `mask(_:)` (bitset, sin reservas de memoria), `classify(_:) -> Set<StructureID>`, `primary(_:)`, `ranked(_:)`, `precedes(_:_:)`, `definitions`, `minimumPlies = 6`. |
| `stableSpans(_:minimumPlies:firstEligiblePly:)` | Tramos de una partida con la misma estructura y duración mínima. |
| `structuresVisited(_:…)` | Unión de las estructuras de esos tramos. |

**Cada estructura se comprueba en las dos orientaciones.** `classify` devuelve, por ejemplo, `Carlsbad` y `Carlsbad (colores invertidos)` por separado; la ficha puede mostrar las dos.

**Estructura principal** (`primary`): cuando se cumplen varias reglas, gana

1. una del libro antes que una genérica;
2. la de más peones obligados (`specificity`: casillas exigidas + un peón por grupo de alternativas + uno por columna ocupada exigida);
3. la que exige más columnas vacías;
4. la orientación del libro antes que la invertida;
5. el orden del catálogo.

Ejemplo: una Maróczy con …g6 cumple también la Dragón; gana Maróczy (4 peones obligados contra 3).

### Textos

Cada estructura (las 28 del libro y las 4 genéricas) tiene, en español y en inglés, una línea con la regla («qué define la estructura») y 2–3 planes típicos por bando. Están escritos para el paquete con ideas generales de dominio público (ataque de minorías, ruptura d4-d5, casilla e5…), no copiados del libro.

| Miembro | Qué hace |
|---|---|
| `StructureLanguage` | `.spanish` / `.english`; `init(locale:)` elige español si el idioma es `es` e inglés en cualquier otro caso. |
| `StructureText` | `name`, `rule`, `whitePlans`, `blackPlans`, `plans(for:)` y `formattedPlans(_:)` (encabezado por bando y una viñeta por plan). |
| `StructureKind.text(_:)` | Textos en la orientación del libro. |
| `StructureID.text(_:)` / `text(locale:)` | Textos en esa orientación: con colores invertidos se cambian los bandos, las casillas pasan a su simétrica (d4 ↔ d5, `b2-b4` ↔ `b7-b5`) y los planes blancos son los negros del libro. |
| `PawnStructure.summary(locale:)` / `summary(_:)` | `StructureSummary` (estructura principal + textos); `nil` si no hay ninguna. |

`swift run pawn-structures-tool texts` vuelca los textos de las 28 del libro en JSON con las claves de la app (`ps_structure_rule_01`…`28` y `ps_structure_plans_01`…`28`, cada una con `es` y `en`).

```swift
let text = StructureID(.isolatedQueenPawn, reversed: true).text(.spanish)
text.rule        // "Las negras tienen un peón aislado en d5, sin peones c ni e, y las blancas no tienen peones c ni d."
text.whitePlans  // ["Bloquear el peón en d4, mejor con un caballo.", …]
```

## Definiciones de los rasgos

«Delante» es hacia la fila 8 para las blancas y hacia la fila 1 para las negras; «fila relativa» n es la fila n para las blancas y la 9 − n para las negras. Todos se calculan para las blancas con desplazamientos de bits; los de las negras, con la misma función sobre la estructura con colores invertidos.

| Rasgo | Definición |
|---|---|
| **Aislado** | Ningún peón propio en las columnas adyacentes (en cualquier fila). |
| **Doblado** | Comparte columna con otro peón propio. Se marcan todos los de la columna; `doubledCount` = peones − columnas ocupadas (los sobrantes: c3-c4-c5 vale 2). |
| **Pasado** | Ningún peón rival delante en su columna ni en las adyacentes. Los propios no cuentan; un rival a su lado o por detrás no lo impide. |
| **Retrasado** | Definición clásica: ningún peón propio en columnas adyacentes a su altura o por detrás (nadie puede apoyarlo) y su casilla de avance está controlada por un peón rival. Un peón aislado no se cuenta como retrasado (los dos rasgos se excluyen, como en Stockfish). |
| **Conectado** | Forma pareja con un peón propio de una columna adyacente: lo defiende, está defendido por él o está a su lado en la misma fila (falange). |
| **Cadena** | Componente conexa de peones unidos en diagonal por relaciones de defensa (2 o más peones). `chainBases`: miembros no defendidos por un peón propio (d4 en d4-e5, b2 en b2-c3-d4-e5). |
| **Islas** | Grupos de columnas contiguas con algún peón propio. |
| **Colgantes** | Isla de exactamente dos columnas adyacentes con un solo peón propio en cada una, los dos en la misma fila relativa (3.ª a 5.ª), y sin peones rivales en esas dos columnas. El caso de libro: c4-d4 sin peones b ni e, contra un rival sin c ni d. |
| **Columna abierta** | Sin peones de ningún color. |
| **Columna semiabierta** para un bando | Sin peones propios pero con algún peón rival. |
| **Mayoría por flanco** | El bando con más peones en a–d (dama) o e–h (rey); `nil` si están igualados. |
| **Casilla débil (agujero)** | Casilla de las filas relativas 3.ª y 4.ª que ya no puede atacar ningún peón propio (no queda ninguno en columnas adyacentes por detrás) y que no tiene un peón propio. Ejemplos: d5 para las negras en la Najdorf Tipo II; h3 para las blancas tras g3. |

## Las estructuras

Fuente: los diagramas de apertura de cada capítulo de Flores Rios, *Chess Structures – A Grandmaster Guide* (Quality Chess, 2015). Solo se toma la colocación de los peones de cada diagrama (un hecho técnico); las reglas, los nombres en español y los textos son propios, y no se copia texto del libro. **Requiere** = casillas con peón; **sin** = columnas sin peón de ese color; `c6|c7` = un peón en c6 o en c7; **típico** = lo que suele acompañar sin exigirse (sirve para similitud y para ordenar, no para filtrar; `matchesTypical`). La tabla la genera `swift run pawn-structures-tool catalog`.

| # | Estructura | Familia | p. PDF | Blancas | Negras | Típico | Especificidad |
|--:|---|---|--:|---|---|---|--:|
| 1 | Peón aislado (IQP) (`.isolatedQueenPawn`) | d4 contra …d5 | 14 | d4 sin ce | sin cd | negras e6 | 1 |
| 2 | Peones colgantes (`.hangingPawns`) | d4 contra …d5 | 38 | c4 d4 sin be | sin cd | negras e6 | 2 |
| 3 | Formación Caro-Kann (`.caroKann`) | d4 contra …d5 | 53 | d4 c2\|c3\|c4 sin e | c6 e6 sin d |  | 4 |
| 4 | Formación Eslava (`.slav`) | d4 contra …d5 | 71 | d4 e3 sin c | c6 e6 sin d |  | 4 |
| 5 | Carlsbad (`.carlsbad`) | d4 contra …d5 | 88 | d4 e2\|e3 sin c | d5 c6\|c7 sin e |  | 4 |
| 6 | Stonewall (`.stonewall`) | d4 contra …d5 | 105 | d4 | d5 e6 f5 | negras c6 | 4 |
| 7 | Centro Grünfeld (`.grunfeldCenter`) | d4 contra …d5 | 124 | c3 d4 e4 | c5\|c7 sin d | blancas sin b | 4 |
| 8 | Najdorf Tipo I (`.najdorfI`) | Siciliana abierta | 140 | d5 c2\|c3 sin e | d6 e5 sin c |  | 4 |
| 9 | Najdorf Tipo II (`.najdorfII`) | Siciliana abierta | 157 | e4 sin d | d6 e5 sin c | blancas c2\|c3 | 3 |
| 10 | Erizo (`.hedgehog`) | Siciliana abierta | 180 | c4 e4 sin d | a6 b6 d6 e6 sin c |  | 6 |
| 11 | Maróczy (`.maroczy`) | Siciliana abierta | 207 | c4 e4 sin d | e7 d6\|d7 sin c | negras g6 | 4 |
| 12 | Benoni asimétrica (`.asymmetricBenoni`) | Benoni | 226 | d5 e4 sin c | c5 d6 sin e |  | 4 |
| 13 | Benoni simétrica (`.symmetricBenoni`) | Benoni | 242 | c4 d5 sin e | c5 d6 sin e |  | 4 |
| 14 | India de Rey Tipo I (`.kingsIndianI`) | India de Rey | 261 | d5 e4 sin c | d6 e5 sin c |  | 4 |
| 15 | India de Rey Tipo II (`.kingsIndianII`) | India de Rey | 281 | c4 d5 e4 | c5 d6 e5 |  | 6 |
| 16 | India de Rey Tipo III (`.kingsIndianIII`) | India de Rey | 297 | c4 d5 e4 | c7 d6 e5 |  | 6 |
| 17 | India de Rey abierta (`.openKingsIndian`) | India de Rey | 323 | c4 e4 sin d | d6 c6\|c7 sin e |  | 4 |
| 18 | Complejo India de Rey (`.kingsIndianComplex`) | India de Rey | 338 | c4 d4 e4 | d6 e5 c6\|c7 |  | 6 |
| 19 | Francesa Tipo I (`.frenchI`) | Francesa | 353 | d4 sin e | d5 e6 sin f |  | 3 |
| 20 | Francesa Tipo II (`.frenchII`) | Francesa | 364 | e5 c2\|c3 sin d | d5 e6 sin c |  | 4 |
| 21 | Francesa Tipo III (`.frenchIII`) | Francesa | 383 | d4 e5 | d5 e6 | blancas columnas c; negras columnas c | 4 |
| 22 | 3–3 contra 4–2 (`.threeThreeVersusFourTwo`) | Misceláneas | 400 | columnas abcfgh sin de | columnas abefgh sin cd |  | 12 |
| 23 | Panov (`.panov`) | Misceláneas | 403 | c5 d4 sin e | d5 e6\|e7 sin c |  | 4 |
| 24 | Dragón (`.dragon`) | Misceláneas | 408 | e4 sin d | d6 g6 sin c | negras e7 | 3 |
| 25 | Scheveningen (`.scheveningen`) | Misceláneas | 411 | e4 c2\|c3 sin d | d6 e6 sin c |  | 4 |
| 26 | Benko (`.benko`) | Misceláneas | 415 | d5 e4 sin c | c5 d6 e7 sin ab |  | 5 |
| 27 | Ruy López cerrada (`.closedRuyLopez`) | Misceláneas | 417 | c3 d5 e4 | d6 e5 c4\|c5 | negras b5 | 6 |
| 28 | Formación López (`.ruyLopezFormation`) | Misceláneas | 421 | c3 d4 e4 | d6 e5 c5\|c6\|c7 | negras c5 | 6 |
| G | Mayoría en el flanco de dama (`.queensideMajority`) | Genéricas | — | más peones en a–c que las negras; sin d | sin d |  | 1 |
| G | Peones c doblados (Nimzo-Sämisch) (`.doubledCPawns`) | Genéricas | — | c3 c4 d4 | — |  | 3 |
| G | Berlinesa (`.berlin`) | Genéricas | — | e5 sin d | c6 c7 sin d |  | 3 |
| G | Cadena de la Londres/Colle (`.londonColle`) | Genéricas | — | c3 d4 e3 | d5 | blancas f4 | 4 |

Notas:

- **3–3 contra 4–2** es una regla por columnas: las blancas tienen peones exactamente en a, b, c, f, g, h y las negras exactamente en a, b, e, f, g, h.
- **Mayoría en el flanco de dama** (genérica): ningún bando tiene peones d y las blancas tienen más peones que las negras en a–c. Invertida = mayoría negra.
- **Las dos de la Española se afinaron en 0.1.1**, comprobadas con los diagramas del libro (pp. 417 y 421) y con su frecuencia en las mismas 100 000 partidas. Con las reglas de 0.1.0 salían muy bajas porque exigían casillas que el diagrama muestra pero que no definen la estructura:
  - **Ruy López cerrada**: ya no exige …b5. El peón b negro puede estar en b7 o b6, o haberse cambiado tras a4. Sigue exigiendo el peón c negro en c4 o c5: c3 contra c4/c5 es lo que la separa de la India de Rey Tipo II (c4 contra c5). Admitir también …c7 la mezclaría con el análogo de la India de Rey Tipo III. …b5 queda como típico. Frecuencia: de 0,10 % + 0,01 % a 0,23 % + 0,03 %.
  - **Formación López**: el peón c negro puede estar en c5 (el diagrama, Chigorin), c6 (Breyer) o c7 (Zaitsev). Es la misma tensión c3-d4-e4 contra …d6-e5 que el libro describe como formación en transición. …c5 queda como típico. Frecuencia: de 0,04 % + 0,01 % a 0,61 % + 0,09 %.

### Frecuencia (% de partidas)

Una estructura cuenta en una partida si dura ≥ 6 plies seguidos y aparece desde la jugada 8 (`stableSpans(…, minimumPlies: 6, firstEligiblePly: 14)`).

| Estructura | Libro % | Invertida % |
|---|--:|--:|
| 01 Peón aislado (IQP) | 3.45 | 3.78 |
| 02 Peones colgantes | 0.28 | 0.38 |
| 03 Formación Caro-Kann | 1.69 | 0.22 |
| 04 Formación Eslava | 0.44 | 0.15 |
| 05 Carlsbad | 2.56 | 1.83 |
| 06 Stonewall | 1.33 | 0.94 |
| 07 Centro Grünfeld | 0.31 | 0.10 |
| 08 Najdorf Tipo I | 0.54 | 0.04 |
| 09 Najdorf Tipo II | 2.53 | 0.27 |
| 10 Erizo | 0.23 | 0.01 |
| 11 Maróczy | 0.85 | 0.12 |
| 12 Benoni asimétrica | 0.52 | 0.15 |
| 13 Benoni simétrica | 0.50 | 0.17 |
| 14 India de Rey Tipo I | 0.69 | 0.18 |
| 15 India de Rey Tipo II | 0.42 | 0.09 |
| 16 India de Rey Tipo III | 0.66 | 0.10 |
| 17 India de Rey abierta | 0.53 | 0.28 |
| 18 Complejo India de Rey | 0.12 | 0.03 |
| 19 Francesa Tipo I | 1.00 | 0.39 |
| 20 Francesa Tipo II | 1.44 | 0.28 |
| 21 Francesa Tipo III | 3.06 | 0.51 |
| 22 3–3 contra 4–2 | 2.63 | 0.90 |
| 23 Panov | 0.22 | 0.25 |
| 24 Dragón | 3.03 | 0.47 |
| 25 Scheveningen | 1.52 | 0.08 |
| 26 Benko | 0.20 | 0.01 |
| 27 Ruy López cerrada | 0.23 | 0.03 |
| 28 Formación López | 0.61 | 0.09 |
| G Mayoría en el flanco de dama | 20.90 | 15.36 |
| G Peones c doblados (Nimzo-Sämisch) | 0.38 | 0.20 |
| G Berlinesa | 0.13 | 0.06 |
| G Cadena de la Londres/Colle | 1.47 | 2.27 |

Primeras 100 000 partidas de la Lumbras Gigabase OTB 2025 (`LumbrasGigabase_OTB_2025.pgn`), calculado con `pawn-structures-tool compare`. «Libro» = con los colores del diagrama; «invertida» = colores cambiados. Con alguna estructura del libro: 35,0 % de las partidas (34,4 % con las reglas de 0.1.0).

## Distancia entre estructuras

`StructureDistance` suma la distancia de Hamming de los peones y las diferencias de rasgos:

```
d(a, b) = Σ peso · |diferencia|
```

| Componente | Cómo se mide | Peso (`.standard`) |
|---|---|--:|
| Hamming | casillas con peón distinto, blancas y negras por separado (mover un peón una casilla = 2) | 1 |
| Aislados | por bando, diferencia del nº de peones aislados | 1,5 |
| Doblados | por bando, diferencia de `doubledCount` | 1 |
| Pasados | por bando, diferencia del nº de pasados | 4 |
| Retrasados | por bando | 1 |
| Islas | por bando | 1 |
| Colgantes | por bando, nº de peones colgantes | 1 |
| Columnas abiertas | columnas que cambian de estado | 1,5 |
| Columnas semiabiertas | por bando, columnas que cambian de estado | 1 |
| Mayorías | por flanco donde cambia quién tiene la mayoría | 2 |

Los pesos dan más importancia a los rasgos que cambian el plan que a la casilla exacta de un peón: un pasado de más pesa como mover dos peones una casilla. Ejemplo (test `traitsMatter`): en una IQP, llevar el peón negro de e6 a e7 cuesta 2; quitarlo cuesta 9,5 (1 de Hamming + 4 por el pasado de d4 + 1,5 por la columna e abierta + 1 por la semiabierta que pierden las blancas + 2 por la mayoría negra en e–h que desaparece). `Weights.hammingOnly` deja solo Hamming.

`nearest(_:in:)` recorre las candidatas y devuelve la más cercana (`index`, `structure`, `distance`); con `allowingReversedColors: true` compara también con cada candidata invertida. Para muchas comparaciones contra la misma estructura, `distance(_:_:_:_:)` acepta los `PawnTraits` ya calculados.

## Rendimiento

`swift run -c release pawn-structures-tool bench [REFERENCIA.bin]`: 100 000 claves de peones reales distintas (de Lumbras 2025), tiempo de CPU del hilo por llamada, M2 Pro, mejor de 7 pasadas de ≥ 1 M llamadas. Se mide tiempo de CPU y no de reloj porque la máquina estaba muy cargada (carga media ~300).

| Llamada | ns por posición |
|---|--:|
| `StructureCatalog.mask` (bitset, las dos orientaciones) | 49 |
| `StructureCatalog.classify` (`Set<StructureID>`) | 104 |
| `StructureCatalog.primary` | 48 |
| `PawnTraits` (todos los rasgos de los dos bandos) | 76 |
| `fileKey` | 4 |
| `StructureDistance` (incluye `PawnTraits` de las dos) | 147 |

`classify` (con `Set`) queda por debajo de 1 µs, y `mask`, la ruta para indexar, a unos 50 ns: clasificar las ~1,6 M claves distintas de 100 k partidas cuesta menos de 0,1 s.

## Verificación

- `swift test` (Swift Testing):
  - una fixture FEN por estructura (32 posiciones típicas escritas para el paquete, legales según python-chess), en la orientación del libro y con colores invertidos (invertidos por texto, sin usar el código del paquete): cada una cumple su estructura y es la principal;
  - casos límite de cada rasgo (bordes a/h sin envoltura, doblados, retrasado frente a aislado, cadenas, colgantes en filas distintas, agujeros tras g3…);
  - paridad con la referencia en Python sobre una muestra versionada de 3 734 claves (`Tests/…/Resources/reference-sample.txt`), con ejemplos de las 28 estructuras;
  - las dos reglas afinadas de la Española: sin …b5, con el peón c en c5, c6 o c7, y sin confundirse con el Complejo India de Rey;
  - textos: regla y 2–3 planes por bando en los dos idiomas para las 32, la regla escrita nombra todas las casillas que exige la regla del catálogo y los textos con colores invertidos cambian bandos, casillas y planes;
  - opcional: con `PAWN_STRUCTURES_REFERENCE=/ruta/ref-100k.bin swift test`, todas las claves de 100 k partidas y los % por estructura contra la referencia.
- Paridad completa (con las reglas de 0.1.1): **0 diferencias en 1 582 642 claves distintas** de las primeras 100 000 partidas de `LumbrasGigabase_OTB_2025.pgn` entre `StructureCatalog.mask` y una implementación de referencia de las mismas reglas escrita aparte en Python (python-chess).

### Regenerar la referencia

```bash
uv run --with chess python3 Tools/dump_reference.py RUTA/reglas_referencia.py ~/Downloads/LumbrasGigabase_OTB_2025.pgn ref-100k.bin 100000
swift run -c release pawn-structures-tool compare ref-100k.bin
python3 Tools/make_sample.py ref-100k.bin Tests/ChessPawnStructuresTests/Resources/reference-sample.txt
```

`dump_reference.py` importa las reglas de referencia (no las copia) y vuelca cada clave con su clasificación en Python y la secuencia de claves de cada partida. Las dos de la Española las toma de `Tools/refined_rules.py` (reglas de 0.1.1). Un volcado hecho antes se puede actualizar con `python3 Tools/refined_rules.py ref-100k.bin ref-100k-011.bin`. Nunca con la base de 13,4 M.

## Pendiente

- Prototipos por estructura para «parecidas» al nivel del catálogo (hoy `nearest` compara estructuras concretas).

## Cambios

- **0.1.1** (en `main`, sin etiqueta): reglas afinadas de Ruy López cerrada y Formación López; textos (regla y planes, es/en) con `StructureText`, `StructureID.text(_:)` y `PawnStructure.summary(locale:)`; subcomando `texts`.
- **0.1.0**: primera versión.

## Licencia

MIT. Ver [LICENSE](LICENSE).
