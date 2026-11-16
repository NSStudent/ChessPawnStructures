import Foundation
import Testing
@testable import ChessPawnStructures

/// Comparación con una implementación de referencia de las mismas reglas en Python (python-chess),
/// escrita aparte. `Tools/dump_reference.py` la importa y vuelca sus resultados.
@Suite("Referencia en Python")
struct ReferenceTests {
    /// Bits de las 28 estructuras del libro (las genéricas no están en la referencia).
    static let bookBits: UInt64 = (1 << 56) - 1

    static func sample() throws -> [(PawnStructure, UInt64)] {
        let url = try #require(Bundle.module.url(forResource: "reference-sample", withExtension: "txt", subdirectory: "Resources"))
        let text = try String(contentsOf: url, encoding: .utf8)
        return text.split(separator: "\n").compactMap { line in
            guard !line.hasPrefix("#") else { return nil }
            let parts = line.split(separator: " ").compactMap { UInt64($0, radix: 16) }
            guard parts.count == 3 else { return nil }
            return (PawnStructure(white: parts[0], black: parts[1]), parts[2])
        }
    }

    @Test("Muestra versionada: misma clasificación que Python clave a clave")
    func sampleParity() throws {
        let sample = try Self.sample()
        #expect(sample.count > 3000)
        var covered: UInt64 = 0
        for (s, python) in sample {
            let swift = StructureCatalog.mask(s).rawValue & Self.bookBits
            #expect(swift == python, "\(s.fenPlacement)")
            covered |= python
        }
        // La muestra tiene ejemplos positivos de las 28 estructuras en la orientación del libro.
        for kind in StructureCatalog.bookKinds {
            #expect(covered & (1 << UInt64(kind.rawValue * 2)) != 0, "\(kind.name) sin ejemplos")
        }
    }

    /// Volcado completo de `Tools/dump_reference.py` (100 k partidas de la Lumbras Gigabase OTB 2025): si la variable
    /// de entorno `PAWN_STRUCTURES_REFERENCE` apunta a él, se comparan todas las claves y se
    /// recalculan los % por partida (≥ 6 plies desde la jugada 8).
    @Test("Volcado completo (opcional)", .enabled(if: ProcessInfo.processInfo.environment["PAWN_STRUCTURES_REFERENCE"] != nil))
    func fullDump() throws {
        let path = ProcessInfo.processInfo.environment["PAWN_STRUCTURES_REFERENCE"]!
        let data = try #require(FileManager.default.contents(atPath: path))
        #expect(data.prefix(4) == Data("PSR1".utf8))
        var offset = 4
        func read<T: FixedWidthInteger>(_: T.Type) -> T {
            defer { offset += MemoryLayout<T>.size }
            return data.withUnsafeBytes { T(littleEndian: $0.loadUnaligned(fromByteOffset: offset, as: T.self)) }
        }
        let nKeys = Int(read(UInt32.self))
        var keys: [PawnStructure] = []
        var mismatches = 0
        for _ in 0 ..< nKeys {
            let s = PawnStructure(white: read(UInt64.self), black: read(UInt64.self))
            let python = read(UInt64.self)
            if StructureCatalog.mask(s).rawValue & Self.bookBits != python { mismatches += 1 }
            keys.append(s)
        }
        #expect(mismatches == 0)
        let nGames = Int(read(UInt32.self))
        var perBit = [Int](repeating: 0, count: 64)
        for _ in 0 ..< nGames {
            let initial = Int(read(UInt16.self))
            let n = Int(read(UInt16.self))
            let seq = (0 ..< n).map { _ in keys[Int(read(UInt32.self))] }
            var rest = structuresVisited(seq, firstEligiblePly: 14 - initial).rawValue
            while rest != 0 {
                perBit[rest.trailingZeroBitCount] += 1
                rest &= rest - 1
            }
        }
        // Cifras del script de referencia sobre las mismas 100 000 partidas (% con dos decimales).
        if nGames == 100_000 {
            func pct(_ n: Int) -> String { String(format: "%.2f", Double(n) * 100 / Double(nGames)) }
            for (kind, book, reversed) in Self.lumbras2025First100k {
                #expect(pct(perBit[kind.rawValue * 2]) == book, "\(kind.name)")
                #expect(pct(perBit[kind.rawValue * 2 + 1]) == reversed, "\(kind.name) invertida")
            }
        }
    }
}

extension ReferenceTests {
    /// Salida del script de medida de referencia sobre `LumbrasGigabase_OTB_2025.pgn` (100 000 partidas):
    /// (estructura, % libro, % invertida).
    static let lumbras2025First100k: [(StructureKind, String, String)] = [
        (.isolatedQueenPawn, "3.45", "3.78"),
        (.hangingPawns, "0.28", "0.38"),
        (.caroKann, "1.69", "0.22"),
        (.slav, "0.44", "0.15"),
        (.carlsbad, "2.56", "1.83"),
        (.stonewall, "1.33", "0.94"),
        (.grunfeldCenter, "0.31", "0.10"),
        (.najdorfI, "0.54", "0.04"),
        (.najdorfII, "2.53", "0.27"),
        (.hedgehog, "0.23", "0.01"),
        (.maroczy, "0.85", "0.12"),
        (.asymmetricBenoni, "0.52", "0.15"),
        (.symmetricBenoni, "0.50", "0.17"),
        (.kingsIndianI, "0.69", "0.18"),
        (.kingsIndianII, "0.42", "0.09"),
        (.kingsIndianIII, "0.66", "0.10"),
        (.openKingsIndian, "0.53", "0.28"),
        (.kingsIndianComplex, "0.12", "0.03"),
        (.frenchI, "1.00", "0.39"),
        (.frenchII, "1.44", "0.28"),
        (.frenchIII, "3.06", "0.51"),
        (.threeThreeVersusFourTwo, "2.63", "0.90"),
        (.panov, "0.22", "0.25"),
        (.dragon, "3.03", "0.47"),
        (.scheveningen, "1.52", "0.08"),
        (.benko, "0.20", "0.01"),
        (.closedRuyLopez, "0.10", "0.01"),
        (.ruyLopezFormation, "0.04", "0.01"),
    ]
}
