import Testing
@testable import ChessPawnStructures

@Suite("Distancia entre estructuras")
struct DistanceTests {
    let all = Fixtures.all.map { Fixtures.structure($0.fen) }

    @Test("Cero consigo misma y simétrica")
    func metricBasics() {
        let d = StructureDistance()
        for a in all {
            #expect(d(a, a) == 0)
            for b in all {
                #expect(d(a, b) == d(b, a))
                if a != b { #expect(d(a, b) > 0) }
            }
        }
    }

    @Test("Hamming de peones")
    func hamming() {
        let a = Fixtures.pawns("d4 e4", "d5")
        #expect(StructureDistance.hamming(a, Fixtures.pawns("d4 e3", "d5")) == 2)
        #expect(StructureDistance.hamming(a, Fixtures.pawns("d4", "d5")) == 1)
        // Mismo cuadro pero de otro color: cuenta en los dos bitboards.
        #expect(StructureDistance.hamming(Fixtures.pawns("d4", ""), Fixtures.pawns("", "d4")) == 2)
        let onlyHamming = StructureDistance(weights: .hammingOnly)
        #expect(onlyHamming(a, Fixtures.pawns("d4 e3", "d5")) == 2)
    }

    @Test("Los rasgos pesan más que la casilla exacta")
    func traitsMatter() {
        let d = StructureDistance()
        let iqp = Fixtures.pawns("a2 b2 d4 f2 g2 h2", "a7 b7 e6 f7 g7 h7")
        // e6 → e7: dos casillas de Hamming, mismos rasgos.
        let iqpE7 = Fixtures.pawns("a2 b2 d4 f2 g2 h2", "a7 b7 e7 f7 g7 h7")
        // Sin el peón de e6: una sola casilla de Hamming, pero d4 pasa a ser pasado y la columna e
        // se abre (deja de ser semiabierta para las blancas) y desaparece la mayoría negra en e–h.
        let noE6 = Fixtures.pawns("a2 b2 d4 f2 g2 h2", "a7 b7 f7 g7 h7")
        #expect(StructureDistance.hamming(iqp, iqpE7) == 2)
        #expect(StructureDistance.hamming(iqp, noE6) == 1)
        #expect(d(iqp, iqpE7) == 2)
        #expect(d(iqp, noE6) == 1 + 4 + 1.5 + 1 + 2)
        #expect(d(iqp, iqpE7) < d(iqp, noE6))
    }

    @Test("nearest elige la más parecida")
    func nearest() {
        let iqp = Fixtures.structure(Fixtures.all.first { $0.kind == .isolatedQueenPawn }!.fen)
        // Una IQP casi igual (h3 en vez de h2) debe acercarse más a la IQP que a cualquier otra fixture.
        var target = iqp
        target.white = (target.white & ~Square.mask("h2")) | Square.mask("h3")
        let found = ChessPawnStructures.nearest(target, in: all)!
        #expect(found.structure == iqp)
        #expect(found.index == 0)
        #expect(found.distance == 2)
        #expect(ChessPawnStructures.nearest(target, in: [PawnStructure]()) == nil)
    }

    @Test("nearest con colores invertidos")
    func nearestReversed() {
        let carlsbad = Fixtures.structure(Fixtures.all.first { $0.kind == .carlsbad }!.fen)
        let others = all.filter { $0 != carlsbad }
        let d = StructureDistance()
        let plain = d.nearest(carlsbad.colorsReversed, in: others + [carlsbad])!
        let reversed = d.nearest(carlsbad.colorsReversed, in: others + [carlsbad], allowingReversedColors: true)!
        #expect(reversed.distance == 0)
        #expect(reversed.structure == carlsbad)
        #expect(plain.distance > 0)
    }
}
