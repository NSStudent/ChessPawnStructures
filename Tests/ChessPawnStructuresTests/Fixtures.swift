@testable import ChessPawnStructures

/// Una posición típica por estructura, escrita a mano para estos tests (solo importa la colocación
/// de los peones; las piezas son plausibles pero no proceden de ninguna partida concreta).
struct StructureFixture: CustomTestStringConvertible, Sendable {
    let kind: StructureKind
    let fen: String

    var testDescription: String { kind.name }
}

enum Fixtures {
    static let all: [StructureFixture] = [
        .init(kind: .isolatedQueenPawn, fen: "r1bq1rk1/pp2bppp/2n1pn2/8/3P4/2NB1N2/PP3PPP/R1BQ1RK1 w - - 0 10"),
        .init(kind: .hangingPawns, fen: "r2q1rk1/p3bppp/1p2pn2/8/2PP4/5N2/P2B1PPP/R2QR1K1 b - - 0 14"),
        .init(kind: .caroKann, fen: "r2qkb1r/pp1n1ppp/2p1pn2/7P/3P4/3Q1NN1/PPPB1PP1/R3K2R w KQkq - 0 13"),
        .init(kind: .slav, fen: "r1bqkb1r/pp1n1ppp/2p1pn2/8/P1BP4/2N1PN2/1P3PPP/R1BQK2R w KQkq - 0 8"),
        .init(kind: .carlsbad, fen: "r1bq1rk1/pp1nbppp/2p2n2/3p2B1/3P4/2NBP3/PPQ1NPPP/R3K2R w KQ - 0 9"),
        .init(kind: .stonewall, fen: "rnbq1rk1/pp2b1pp/2p1pn2/3p1p2/2PP4/1P3NP1/P3PPBP/RNBQ1RK1 w - - 0 7"),
        .init(kind: .grunfeldCenter, fen: "r1bq1rk1/pp2ppbp/2n3p1/2p5/3PP3/2P1BN2/P3BPPP/R2QK2R w KQ - 0 10"),
        .init(kind: .najdorfI, fen: "r2q1rk1/1p2bppp/p2p1n2/3Pp3/8/1N6/PPP1BPPP/R2Q1RK1 b - - 0 13"),
        .init(kind: .najdorfII, fen: "r2q1rk1/1p2bppp/p2pbn2/4p3/4P3/1NN1B3/PPP1BPPP/R2Q1RK1 w - - 0 11"),
        .init(kind: .hedgehog, fen: "2rq1rk1/1b1nbppp/pp1ppn2/8/2PNP3/1PN1B3/P3BPPP/2RQ1RK1 w - - 0 14"),
        .init(kind: .maroczy, fen: "r1bq1rk1/pp2ppbp/2np1np1/8/2PNP3/2N1B3/PP2BPPP/R2QK2R w KQ - 0 9"),
        .init(kind: .asymmetricBenoni, fen: "rnbqr1k1/pp3pbp/3p1np1/2pP4/4P3/2N2N2/PP2BPPP/R1BQK2R w KQ - 0 9"),
        .init(kind: .symmetricBenoni, fen: "r1bq1rk1/pp2nppp/3p1n2/2pP4/2P5/2N2N2/PP3PPP/R1BQKB1R w KQ - 0 9"),
        .init(kind: .kingsIndianI, fen: "r1bq1rk1/pp1n1pbp/3p1np1/3Pp3/4P3/2N2N2/PP2BPPP/R1BQK2R w KQ - 0 9"),
        .init(kind: .kingsIndianII, fen: "r1bq1rk1/pp1n1pbp/3p1np1/2pPp3/2P1P3/2N2N2/PP2BPPP/R1BQK2R w KQ - 0 9"),
        .init(kind: .kingsIndianIII, fen: "r1bq1rk1/pppnnpbp/3p2p1/3Pp3/2P1P3/2N5/PP2BPPP/R1BQNRK1 b - - 0 10"),
        .init(kind: .openKingsIndian, fen: "r1bq1rk1/pp1n1pbp/2pp1np1/8/2PNP3/2N3P1/PP3PBP/R1BQ1RK1 w - - 0 10"),
        .init(kind: .kingsIndianComplex, fen: "r1bq1rk1/pppn1pbp/3p1np1/4p3/2PPP3/2N2N2/PP2BPPP/R1BQ1RK1 w - - 0 8"),
        .init(kind: .frenchI, fen: "r1b2rk1/pp2b1pp/1qn1pn2/2pp4/3P1P2/2P2N2/PP1NB1PP/R1BQ1RK1 w - - 0 11"),
        .init(kind: .frenchII, fen: "r1b1kbnr/pp3ppp/1qn1p3/3pP3/3N4/2PB4/PP3PPP/RNBQK2R b KQkq - 0 7"),
        .init(kind: .frenchIII, fen: "r1b1kbnr/pp3ppp/1qn1p3/2ppP3/3P4/2P2N2/PP3PPP/RNBQKB1R w KQkq - 0 6"),
        .init(kind: .threeThreeVersusFourTwo, fen: "r1b2rk1/pp2bppp/2n1pn2/8/8/2N2N2/PPP1BPPP/R1B2RK1 w - - 0 11"),
        .init(kind: .panov, fen: "r1bq1rk1/pp2bppp/2n1pn2/2Pp4/3P4/2N2N2/PP3PPP/R1BQKB1R w KQ - 0 9"),
        .init(kind: .dragon, fen: "r1bq1rk1/pp2ppbp/2np1np1/8/3NP3/2N1BP2/PPPQ2PP/R3KB1R w KQ - 0 9"),
        .init(kind: .scheveningen, fen: "r1bqkb1r/1p3ppp/p1nppn2/8/3NP3/2N1B3/PPP1BPPP/R2QK2R w KQkq - 0 8"),
        .init(kind: .benko, fen: "rn1q1rk1/4ppbp/b2p1np1/2pP4/4P3/2N2NP1/PP3P1P/R1BQ1RK1 b - - 0 11"),
        .init(kind: .closedRuyLopez, fen: "r1bq1rk1/4bppp/p2p1n2/nppPp3/4P3/2P2N1P/PPB2PP1/RNBQR1K1 b - - 0 12"),
        .init(kind: .ruyLopezFormation, fen: "r1bq1rk1/4bppp/p2p1n2/npp1p3/3PP3/2P2N1P/PPB2PP1/RNBQR1K1 b - - 0 12"),
        .init(kind: .queensideMajority, fen: "8/pp3pkp/6p1/8/8/1P4P1/P1P2PKP/8 w - - 0 30"),
        .init(kind: .doubledCPawns, fen: "r1bq1rk1/pp3ppp/2np1n2/2p1p3/2PP4/P1PBPN2/5PPP/R1BQK2R w KQ - 0 9"),
        .init(kind: .berlin, fen: "r1bk1b1r/ppp2ppp/2p5/4Pn2/8/5N2/PPP2PPP/RNB2RK1 w - - 0 9"),
        .init(kind: .londonColle, fen: "rn1qkb1r/pp3ppp/4pn2/2pp1b2/3P1B2/2P1PN2/PP3PPP/RN1QKB1R w KQkq - 0 5"),
    ]

    /// Invierte los colores de un FEN a nivel de texto (filas en orden inverso y mayúsculas ↔
    /// minúsculas), sin usar `PawnStructure`. Sirve para comprobar `colorsReversed` por otra vía.
    static func reversedColors(_ fen: String) -> String {
        let placement = fen.split(separator: " ").first!
        let rows = placement.split(separator: "/").reversed().map { row in
            String(row.map { ch -> Character in
                ch.isUppercase ? Character(ch.lowercased()) : Character(ch.uppercased())
            })
        }
        return rows.joined(separator: "/")
    }

    static func structure(_ fen: String) -> PawnStructure {
        guard let s = PawnStructure(fen: fen) else { fatalError("FEN no válido: \(fen)") }
        return s
    }

    /// Estructura solo con peones: `pawns("d4 e4", "d5 e5")`.
    static func pawns(_ white: String, _ black: String) -> PawnStructure {
        PawnStructure(white: Square.mask(white), black: Square.mask(black))
    }
}

import Testing
