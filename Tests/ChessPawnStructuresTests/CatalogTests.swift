import Testing
@testable import ChessPawnStructures

@Suite("Catálogo de estructuras")
struct CatalogTests {
    @Test("Hay una fixture por estructura")
    func everyKindHasAFixture() {
        #expect(Set(Fixtures.all.map(\.kind)) == Set(StructureKind.allCases))
        #expect(Fixtures.all.count == StructureKind.allCases.count)
        #expect(StructureCatalog.bookKinds.count == 28)
    }

    @Test("Las definiciones siguen el orden de StructureKind")
    func definitionsAreOrdered() {
        for (i, d) in StructureCatalog.definitions.enumerated() {
            #expect(d.kind.rawValue == i)
        }
    }

    @Test("Fixture en la orientación del libro: la cumple y es la principal", arguments: Fixtures.all)
    func bookOrientation(_ fixture: StructureFixture) {
        let s = Fixtures.structure(fixture.fen)
        let id = StructureID(fixture.kind)
        #expect(StructureCatalog.classify(s).contains(id), "\(StructureCatalog.classify(s))")
        #expect(StructureCatalog.primary(s) == id, "\(StructureCatalog.ranked(s))")
        #expect(fixture.kind.definition.matches(s))
    }

    @Test("Fixture con colores invertidos: la cumple invertida y es la principal", arguments: Fixtures.all)
    func reversedOrientation(_ fixture: StructureFixture) {
        let reversedFEN = Fixtures.reversedColors(fixture.fen)
        let s = Fixtures.structure(reversedFEN)
        // La inversión por texto y la de bits coinciden.
        #expect(s == Fixtures.structure(fixture.fen).colorsReversed)
        let id = StructureID(fixture.kind, reversed: true)
        #expect(StructureCatalog.classify(s).contains(id), "\(StructureCatalog.classify(s))")
        #expect(StructureCatalog.primary(s) == id, "\(StructureCatalog.ranked(s))")
        #expect(fixture.kind.definition.matches(s, reversed: true))
    }

    @Test("Invertir colores intercambia las orientaciones de todo el conjunto", arguments: Fixtures.all)
    func reversalSwapsOrientation(_ fixture: StructureFixture) {
        let s = Fixtures.structure(fixture.fen)
        let swapped = Set(StructureCatalog.classify(s).map { StructureID($0.kind, reversed: !$0.reversed) })
        #expect(StructureCatalog.classify(s.colorsReversed) == swapped)
    }

    @Test("Posición inicial: ninguna estructura")
    func initialPosition() {
        let s = Fixtures.structure("rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
        #expect(StructureCatalog.classify(s).isEmpty)
        #expect(StructureCatalog.primary(s) == nil)
    }

    @Test("Solapes: gana la más específica")
    func overlaps() {
        // Maróczy con …g6: también cumple la Dragón (e4 sin d contra d6 g6 sin c).
        let maroczy = Fixtures.structure(Fixtures.all.first { $0.kind == .maroczy }!.fen)
        #expect(maroczy.structures.kinds.isSuperset(of: [.maroczy, .dragon]))
        #expect(maroczy.primaryStructure == StructureID(.maroczy))
        // 3–3 contra 4–2 también es mayoría blanca en el flanco de dama (genérica, va detrás).
        let threeThree = Fixtures.structure(Fixtures.all.first { $0.kind == .threeThreeVersusFourTwo }!.fen)
        #expect(threeThree.structures.contains(StructureID(.queensideMajority)))
        #expect(threeThree.primaryStructure == StructureID(.threeThreeVersusFourTwo))
        // Berlinesa: mayoría negra en el flanco de dama (genérica invertida) y Berlinesa.
        let berlin = Fixtures.structure(Fixtures.all.first { $0.kind == .berlin }!.fen)
        #expect(berlin.structures.contains(StructureID(.queensideMajority, reversed: true)))
        #expect(berlin.primaryStructure == StructureID(.berlin))
    }

    @Test("La orientación del libro va antes que la invertida a igual especificidad")
    func bookBeforeReversed() {
        // Carlsbad simétrica imposible; usamos la Stonewall doble: d4 e3 f4 contra d5 e6 f5.
        let s = Fixtures.pawns("a2 b2 c3 d4 e3 f4 g2 h2", "a7 b7 c6 d5 e6 f5 g7 h7")
        let set = StructureCatalog.classify(s)
        #expect(set.contains(StructureID(.stonewall)))
        #expect(set.contains(StructureID(.stonewall, reversed: true)))
        #expect(StructureCatalog.precedes(StructureID(.stonewall), StructureID(.stonewall, reversed: true)))
    }

    @Test("Reglas tal como las escribe la tabla del catálogo")
    func rulesMatchAnnex() {
        func summary(_ k: StructureKind) -> (String, String) {
            guard case let .pattern(p) = k.definition.condition else { return ("", "") }
            return (p.white.summary, p.black.summary)
        }
        #expect(summary(.isolatedQueenPawn) == ("d4 sin ce", "sin cd"))
        #expect(summary(.caroKann) == ("d4 c2|c3|c4 sin e", "c6 e6 sin d"))
        #expect(summary(.carlsbad) == ("d4 e2|e3 sin c", "d5 c6|c7 sin e"))
        #expect(summary(.maroczy) == ("c4 e4 sin d", "e7 d6|d7 sin c"))
        #expect(summary(.threeThreeVersusFourTwo) == ("columnas abcfgh sin de", "columnas abefgh sin cd"))
        #expect(summary(.benko) == ("d5 e4 sin c", "c5 d6 e7 sin ab"))
        #expect(summary(.closedRuyLopez) == ("c3 d5 e4", "b5 d6 e5 c4|c5"))
        #expect(summary(.stonewall) == ("d4", "d5 e6 f5"))
    }

    @Test("StructureSet y StructureID")
    func setAndID() {
        for bit in 0 ..< 64 {
            let id = StructureID(bit: bit)!
            #expect(id.bit == bit)
        }
        #expect(StructureID(bit: 64) == nil)
        var set: StructureSet = [StructureID(.carlsbad), StructureID(.carlsbad, reversed: true)]
        #expect(set.count == 2)
        #expect(set.kinds == [.carlsbad])
        set.insert(StructureID(.panov))
        #expect(Array(set) == [StructureID(.carlsbad), StructureID(.carlsbad, reversed: true), StructureID(.panov)])
    }

    @Test("Lo típico no filtra pero se puede consultar")
    func typical() {
        let iqp = Fixtures.structure(Fixtures.all[0].fen)
        #expect(StructureKind.isolatedQueenPawn.definition.matchesTypical(iqp))
        let noE6 = Fixtures.pawns("a2 b2 d4 f2 g2 h2", "a7 b7 f7 g7 h7")
        #expect(StructureCatalog.classify(noE6).contains(StructureID(.isolatedQueenPawn)))
        #expect(!StructureKind.isolatedQueenPawn.definition.matchesTypical(noE6))
    }

    @Test("Duración mínima: tramos de 6 plies")
    func spans() {
        let a = Fixtures.pawns("d4", "d5")
        let b = Fixtures.pawns("d4 e4", "d5")
        let iqp = Fixtures.structure(Fixtures.all[0].fen)
        let plies = [a, a, b, b, b, b, b, b, iqp, iqp, iqp, iqp, iqp]
        let spans = stableSpans(plies)
        #expect(spans == [StructureSpan(structure: b, firstPly: 3, plies: 6)])
        #expect(stableSpans(plies, minimumPlies: 5).map(\.structure) == [b, iqp])
        #expect(stableSpans(plies, minimumPlies: 5, firstEligiblePly: 4).map(\.structure) == [iqp])
        #expect(structuresVisited(plies + [iqp]).contains(StructureID(.isolatedQueenPawn)))
        #expect(!structuresVisited(plies).contains(StructureID(.isolatedQueenPawn)))
    }
}
