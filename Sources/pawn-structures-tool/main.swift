// Herramienta de desarrollo de ChessPawnStructures.
//
//   swift run -c release pawn-structures-tool bench
//   swift run -c release pawn-structures-tool compare REFERENCIA.bin
//   swift run pawn-structures-tool texts      # JSON con ps_structure_rule_XX / ps_structure_plans_XX
//
// `compare` lee el volcado de Tools/dump_reference.py y comprueba, clave a clave, que `classify`
// da lo mismo que las reglas de referencia en Python; después recalcula el % de partidas por
// estructura (≥ 6 plies seguidos desde la jugada 8) igual que el script de medida de referencia.
import ChessPawnStructures
import Foundation

nonisolated(unsafe) var sink: UInt64 = 0
@inline(never)
func blackHole(_ x: UInt64) { sink &+= x }

func now() -> UInt64 { DispatchTime.now().uptimeNanoseconds }

func sampleStructures() -> [PawnStructure] {
    let fens = [
        "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1",
        "r1bq1rk1/pp2bppp/2n1pn2/8/3P4/2NB1N2/PP3PPP/R1BQ1RK1 w - - 0 10",
        "r1bq1rk1/pp1nbppp/2p1pn2/3p4/2PP4/2N1PN2/PPQ2PPP/R1B1KB1R w KQ - 0 8",
        "r2q1rk1/1p2bppp/p1npbn2/4p3/4P3/1NN1B3/PPP1BPPP/R2Q1RK1 w - - 0 11",
        "r1bq1rk1/pppn1pbp/3p1np1/3Pp3/2P1P3/2N2N2/PP2BPPP/R1BQK2R w KQ - 0 8",
        "8/5pk1/6p1/p6p/P6P/6P1/5PK1/8 w - - 0 50",
        "rnbqkb1r/pp3ppp/4pn2/2pp4/3P4/2P1PN2/PP3PPP/RNBQKB1R w KQkq - 0 5",
    ]
    var out = fens.compactMap { PawnStructure(fen: $0) }
    // Estructuras pseudoaleatorias reproducibles (peones en filas 2–7).
    var state: UInt64 = 0x9E37_79B9_7F4A_7C15
    func next() -> UInt64 {
        state ^= state << 13; state ^= state >> 7; state ^= state << 17
        return state
    }
    let middle: UInt64 = 0x00FF_FFFF_FFFF_FF00
    for _ in 0 ..< 1017 {
        let w = next() & next() & middle
        let b = next() & next() & middle & ~w
        out.append(PawnStructure(white: w, black: b))
    }
    return out
}

func bench(_ path: String?) {
    var structures = sampleStructures()
    if let path, let data = FileManager.default.contents(atPath: path) {
        // Claves reales: las primeras 100 000 claves distintas del volcado de referencia.
        var r = Reader(data: data, offset: 4)
        let n = min(r.u32(), 100_000)
        structures = (0 ..< n).map { _ in
            let s = PawnStructure(white: r.u64(), black: r.u64())
            _ = r.u64()
            return s
        }
        print("\(n) claves reales de \(path)")
    } else {
        print("\(structures.count) estructuras sintéticas")
    }
    // Tiempo de CPU del hilo (no de reloj): con la máquina cargada, el reloj mide también las
    // expropiaciones del planificador.
    func cpu() -> UInt64 { clock_gettime_nsec_np(CLOCK_THREAD_CPUTIME_ID) }
    let calls = max(structures.count, 1_000_000)

    func measure(_ name: String, _ body: (PawnStructure) -> Void) {
        for s in structures { body(s) } // calentamiento
        var best = Double.infinity
        for _ in 0 ..< 7 {
            var done = 0
            let t0 = cpu()
            while done < calls {
                for s in structures { body(s) }
                done += structures.count
            }
            best = min(best, Double(cpu() - t0) / Double(done))
        }
        print(String(format: "%-34@ %8.1f ns", name as NSString, best))
    }

    measure("StructureCatalog.mask (bitset)") { blackHole(StructureCatalog.mask($0).rawValue) }
    measure("StructureCatalog.classify (Set)") { blackHole(UInt64(StructureCatalog.classify($0).count)) }
    measure("StructureCatalog.primary") { blackHole(UInt64(StructureCatalog.primary($0)?.bit ?? 99)) }
    measure("PawnTraits") { let t = PawnTraits($0); blackHole(t.white.holes ^ t.black.passed ^ UInt64(t.white.chainCount)) }
    measure("fileKey") { blackHole($0.fileKey.rawValue) }
    let reference = structures[1]
    let distance = StructureDistance()
    measure("StructureDistance") { blackHole(UInt64(distance.distance(reference, $0))) }
}

struct Reader {
    let data: Data
    var offset = 0
    mutating func u16() -> Int { defer { offset += 2 }; return Int(read(UInt16.self)) }
    mutating func u32() -> Int { defer { offset += 4 }; return Int(read(UInt32.self)) }
    mutating func u64() -> UInt64 { defer { offset += 8 }; return read(UInt64.self) }
    func read<T: FixedWidthInteger>(_: T.Type) -> T {
        data.withUnsafeBytes { T(littleEndian: $0.loadUnaligned(fromByteOffset: offset, as: T.self)) }
    }
}

func compare(_ path: String) {
    guard let data = FileManager.default.contents(atPath: path), data.prefix(4) == Data("PSR1".utf8) else {
        print("No se puede leer \(path)"); exit(1)
    }
    var r = Reader(data: data, offset: 4)
    let nKeys = r.u32()
    var keys: [PawnStructure] = []
    keys.reserveCapacity(nKeys)
    var swiftMasks: [UInt64] = []
    swiftMasks.reserveCapacity(nKeys)
    // Las genéricas no están en la referencia: se comparan solo los bits de las 28 del libro.
    let bookBits: UInt64 = (1 << 56) - 1
    var mismatches = 0
    var classifiedKeys = 0
    for _ in 0 ..< nKeys {
        let s = PawnStructure(white: r.u64(), black: r.u64())
        let python = r.u64()
        let swift = StructureCatalog.mask(s).rawValue
        if swift & bookBits != python {
            mismatches += 1
            if mismatches <= 10 {
                print("Distinta: \(s.fenPlacement) swift \(StructureSet(rawValue: swift & bookBits).map(\.description)) python \(StructureSet(rawValue: python).map(\.description))")
            }
        }
        keys.append(s)
        swiftMasks.append(swift)
    }
    let nGames = r.u32()
    var perBit = [Int](repeating: 0, count: 64)
    var withAny = 0
    var usedKeys = Set<Int>()
    for _ in 0 ..< nGames {
        let initial = r.u16()
        let n = r.u16()
        var seq: [Int] = []
        seq.reserveCapacity(n)
        for _ in 0 ..< n { seq.append(r.u32()) }
        // Igual que el script de referencia: el tramo cuenta si su primer ply deja la partida en la
        // jugada 8 o posterior (fullmove = 1 + plyAbsoluto / 2 ≥ 8 ⇒ plyAbsoluto ≥ 14).
        let spans = stableSpans(seq.map { keys[$0] }, minimumPlies: 6, firstEligiblePly: 14 - initial)
        var hit: UInt64 = 0
        for span in spans {
            // Recuperar el índice para reutilizar la máscara ya calculada.
            hit |= StructureCatalog.mask(span.structure).rawValue
        }
        for i in seq { usedKeys.insert(i) }
        let book = hit & bookBits
        if book != 0 { withAny += 1 }
        var rest = hit
        while rest != 0 {
            perBit[rest.trailingZeroBitCount] += 1
            rest &= rest - 1
        }
    }
    classifiedKeys = nKeys
    print("claves \(classifiedKeys); distintas de Python: \(mismatches)")
    print(String(format: "partidas %d; con alguna estructura del libro: %d (%.1f %%)", nGames, withAny, 100 * Double(withAny) / Double(nGames)))
    print("| Estructura | Libro % | Invertida % |")
    print("|---|--:|--:|")
    for kind in StructureKind.allCases {
        let a = Double(perBit[kind.rawValue * 2]) * 100 / Double(nGames)
        let b = Double(perBit[kind.rawValue * 2 + 1]) * 100 / Double(nGames)
        let label = kind.number.map { String(format: "%02d ", $0) } ?? "G  "
        print(String(format: "| %@%@ | %.2f | %.2f |", label, kind.name as NSString, a, b))
    }
    if mismatches > 0 { exit(2) }
}

/// Tabla del catálogo en Markdown (para el README).
func catalogTable() {
    print("| # | Estructura | Familia | p. PDF | Blancas | Negras | Típico | Especificidad |")
    print("|--:|---|---|--:|---|---|---|--:|")
    for d in StructureCatalog.definitions {
        let number = d.kind.number.map(String.init) ?? "G"
        var white = "—", black = "—"
        switch d.condition {
        case let .pattern(p):
            white = p.white.summary
            black = p.black.summary
        case .queensideMajority:
            white = "más peones en a–c que las negras; sin d"
            black = "sin d"
        }
        var typical: [String] = []
        if !d.typical.white.isEmpty { typical.append("blancas " + d.typical.white.summary) }
        if !d.typical.black.isEmpty { typical.append("negras " + d.typical.black.summary) }
        let page = d.bookPage.map(String.init) ?? "—"
        func cell(_ t: String) -> String { t.replacingOccurrences(of: "|", with: "\\|") }
        (white, black) = (cell(white), cell(black))
        typical = typical.map(cell)
        print("| \(number) | \(d.name) (`.\(d.kind)`) | \(d.family.name) | \(page) | \(white) | \(black) | \(typical.joined(separator: "; ")) | \(d.specificity) |")
    }
}

/// Textos de las 28 estructuras del libro en JSON, con las claves de la app:
/// `ps_structure_rule_XX` (regla en una línea) y `ps_structure_plans_XX` (planes con viñetas),
/// cada una con `es` y `en`.
func textsJSON() {
    var out: [String: [String: String]] = [:]
    for kind in StructureCatalog.bookKinds {
        let number = String(format: "%02d", kind.number!)
        var rule: [String: String] = [:]
        var plans: [String: String] = [:]
        for language in StructureLanguage.allCases {
            let text = kind.text(language)
            rule[language.rawValue] = text.rule
            plans[language.rawValue] = text.formattedPlans(language)
        }
        out["ps_structure_rule_\(number)"] = rule
        out["ps_structure_plans_\(number)"] = plans
    }
    let data = try! JSONSerialization.data(withJSONObject: out, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
    print(String(decoding: data, as: UTF8.self))
}

let args = CommandLine.arguments
switch args.dropFirst().first {
case "bench": bench(args.count > 2 ? args[2] : nil)
case "catalog": catalogTable()
case "texts": textsJSON()
case "compare" where args.count > 2: compare(args[2])
default:
    print("Uso: pawn-structures-tool catalog | texts | bench [REFERENCIA.bin] | compare REFERENCIA.bin")
}
