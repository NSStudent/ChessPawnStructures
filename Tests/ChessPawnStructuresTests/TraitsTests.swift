import Testing
@testable import ChessPawnStructures

private func sq(_ names: String) -> UInt64 { Square.mask(names) }
private func p(_ w: String, _ b: String) -> PawnStructure { Fixtures.pawns(w, b) }
private func files(_ letters: String) -> UInt8 { SidePattern.fileMask(letters) }

@Suite("Estructura de peones")
struct PawnStructureTests {
    @Test("FEN: lectura y campo de colocación")
    func fen() {
        let s = PawnStructure(fen: "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1")!
        #expect(s.white == sq("a2 b2 c2 d2 e4 f2 g2 h2"))
        #expect(s.black == Bitboard.rank(6))
        #expect(s.fenPlacement == "8/pppppppp/8/8/4P3/8/PPPP1PPP/8")
        #expect(PawnStructure(fen: s.fenPlacement) == s)
        #expect(s.hasPawn(.white, on: "e4"))
        #expect(!s.hasPawn(.black, on: "e4"))
    }

    @Test("FEN no válido", arguments: ["", "8/8/8/8/8/8/8", "9/8/8/8/8/8/8/8", "8/8/8/8/8/8/8/7", "8/8/8/8/8/8/8/ppppppppp", "8/8/8/8/8/8/8/x7"])
    func invalidFEN(_ fen: String) {
        #expect(PawnStructure(fen: fen) == nil)
    }

    @Test("a1 = bit 0 y h8 = bit 63, como Polyglot y python-chess")
    func bitConvention() {
        #expect(Square.index("a1") == 0)
        #expect(Square.index("h1") == 7)
        #expect(Square.index("a2") == 8)
        #expect(Square.index("h8") == 63)
        #expect(Square.index("i1") == nil)
        #expect(Square.name(27) == "d4")
    }

    @Test("Colores invertidos: espejo vertical y cambio de bando")
    func reversal() {
        let s = p("c4 d4", "e6")
        #expect(s.colorsReversed == p("e3", "c5 d5"))
        #expect(s.colorsReversed.colorsReversed == s)
        let start = PawnStructure(white: Bitboard.rank(1), black: Bitboard.rank(6))
        #expect(start.colorsReversed == start)
        #expect(p("a2 c3", "h7").mirroredHorizontally == p("h2 f3", "a7"))
    }

    @Test("Clave por columnas (modo Files de Scid)")
    func fileKey() {
        let start = PawnStructure(white: Bitboard.rank(1), black: Bitboard.rank(6))
        #expect(start.fileKey.description == "11111111/11111111")
        let s = p("a2 c3 c4 d4", "c5 c6 c7 h7")
        #expect(s.fileKey.counts(.white) == [1, 0, 2, 1, 0, 0, 0, 0])
        #expect(s.fileKey.counts(.black) == [0, 0, 3, 0, 0, 0, 0, 1])
        // Misma clave por columnas aunque cambien las filas.
        #expect(p("a3 c2 c5 d6", "c3 c4 c7 h2").fileKey == s.fileKey)
        #expect(p("a3", "").fileKey != p("b3", "").fileKey)
        #expect(FileKey(rawValue: s.fileKey.rawValue) == s.fileKey)
    }
}

@Suite("Rasgos")
struct TraitsTests {
    @Test("Aislados")
    func isolated() {
        // a2 sin peón en b; h-pawn sin g; d4 con c en otra fila no está aislado.
        let s = p("a2 c2 d4 h3", "a7 a6 e5")
        #expect(s.isolated(.white) == sq("a2 h3"))
        // Doblados y aislados: se marcan los dos.
        #expect(s.isolated(.black) == sq("a7 a6 e5"))
        // Sin vecino que «envuelva» de h a a.
        #expect(p("a4 h4", "").isolated(.white) == sq("a4 h4"))
        #expect(p("", "").isolated(.white) == 0)
    }

    @Test("Doblados")
    func doubled() {
        let s = p("c3 c4 d4 g2 g3 g4", "c7 f7")
        #expect(s.doubled(.white) == sq("c3 c4 g2 g3 g4"))
        #expect(s.doubledCount(.white) == 3)
        #expect(s.doubled(.black) == 0)
        #expect(s.doubledCount(.black) == 0)
        // Doblados no contiguos.
        #expect(p("c2 c5", "").doubled(.white) == sq("c2 c5"))
    }

    @Test("Pasados")
    func passed() {
        // e5 pasado: nadie en d, e, f por delante. b4 no: el peón negro de a5 lo vigila.
        let s = p("b4 e5", "a5 d5 h7")
        #expect(s.passed(.white) == sq("e5"))
        // d5 negro: el blanco de e5 está a su lado, no delante → pasado. a5 vigilado por b4.
        #expect(s.passed(.black) == sq("d5 h7"))
        // Un rival detrás en columna adyacente no impide ser pasado.
        #expect(p("d5", "e4").passed(.white) == sq("d5"))
        // Sin envoltura entre a y h.
        #expect(p("h4", "a5").passed(.white) == sq("h4"))
        #expect(p("h4", "a5").passed(.black) == sq("a5"))
        // Los propios no cuentan.
        #expect(p("d4 d5", "").passed(.white) == sq("d4 d5"))
        // Bloqueado de frente: no es pasado.
        #expect(p("d4", "d5").passed(.white) == 0)
    }

    @Test("Retrasados (definición clásica)")
    func backward() {
        // d6 negro de la Najdorf: e5 está por delante, no hay c; d5 lo controla e4 → retrasado.
        let najdorf = p("e4 f2 g2", "d6 e5 f7")
        #expect(najdorf.backward(.black) == sq("d6"))
        // Con c7 (vecino por detrás) ya se puede apoyar: no es retrasado.
        #expect(p("e4 f2 g2", "c7 d6 e5 f7").backward(.black) == 0)
        // Con c6 (vecino a su altura) tampoco.
        #expect(p("e4", "c6 d6 e5").backward(.black) == 0)
        // Si la casilla de avance no está controlada por un peón rival, no es retrasado.
        #expect(p("f2 g2", "d6 e5 f7").backward(.black) == 0)
        // Un aislado no se cuenta como retrasado aunque su casilla esté controlada.
        #expect(p("e4", "d6").backward(.black) == 0)
        #expect(p("e4", "d6").isolated(.black) == sq("d6"))
        // Blancas: c3 con b4 y d4 por delante; c4 controlada por b5.
        #expect(p("b4 c3 d4", "b5").backward(.white) == sq("c3"))
        #expect(p("b2 c3 d4", "b5").backward(.white) == 0)
    }

    @Test("Conectados")
    func connected() {
        // Falange d4-e4, c3 defiende d4, h2 solo.
        let s = p("c3 d4 e4 h2", "a7 b6 g7")
        #expect(s.connected(.white) == sq("c3 d4 e4"))
        #expect(s.connected(.black) == sq("a7 b6"))
        #expect(p("a4 h5", "").connected(.white) == 0)
        // Sin envoltura: h3 y a4 no se defienden.
        #expect(p("h3 a4", "").connected(.white) == 0)
    }

    @Test("Cadenas")
    func chains() {
        // Francesa Avance: b2-c3-d4-e5 y f2-g3 son dos cadenas; h4 suelto.
        let s = p("b2 c3 d4 e5 f2 g3 h4", "d5 e6 f7")
        #expect(s.chainMembers(.white) == sq("b2 c3 d4 e5 f2 g3 h4"))
        // g3-h4 también es una relación de defensa: f2-g3-h4 forman una cadena.
        #expect(s.chains(.white) == [sq("b2 c3 d4 e5"), sq("f2 g3 h4")])
        #expect(s.chainCount(.white) == 2)
        #expect(s.chainBases(.white) == sq("b2 f2"))
        #expect(s.chains(.black) == [sq("d5 e6 f7")])
        #expect(s.chainBases(.black) == sq("f7"))
        #expect(p("d4 e4", "").chainCount(.white) == 0)
    }

    @Test("Islas")
    func islands() {
        #expect(p("a2 b2 d4 e3 f2 h2", "").islands(.white) == 3)
        #expect(PawnStructure(white: Bitboard.rank(1), black: 0).islands(.white) == 1)
        #expect(p("", "").islands(.white) == 0)
        #expect(p("", "a7 c7 e7 g7").islands(.black) == 4)
    }

    @Test("Peones colgantes")
    func hanging() {
        let classic = p("a2 c4 d4 f2 g2 h2", "a7 b6 e6 f7 g7 h7")
        #expect(classic.hanging(.white) == sq("c4 d4"))
        #expect(classic.hanging(.black) == 0)
        // Con peón propio en b: ya no es una isla de dos columnas.
        #expect(p("a2 b2 c4 d4", "e6").hanging(.white) == 0)
        // Con peón rival en la columna c: no son colgantes.
        #expect(p("a2 c4 d4 g2", "c6 e6").hanging(.white) == 0)
        // En filas distintas tampoco.
        #expect(p("a2 c4 d5 g2", "e6").hanging(.white) == 0)
        // Negras: c5 y d5 (fila relativa 4).
        #expect(p("a2 b2 e3 f2", "a7 c5 d5 f7").hanging(.black) == sq("c5 d5"))
        // Sin vecinos en el borde: a4-b4.
        #expect(p("a4 b4 g2", "g7").hanging(.white) == sq("a4 b4"))
    }

    @Test("Columnas abiertas y semiabiertas")
    func files_() {
        let s = p("a2 b2 d4 f2 g2 h2", "a7 b7 e6 f7 g7 h7")
        #expect(s.openFiles == files("c"))
        #expect(s.semiOpenFiles(.white) == files("e"))
        #expect(s.semiOpenFiles(.black) == files("d"))
        #expect(p("", "").openFiles == 0xFF)
    }

    @Test("Mayorías por flanco")
    func majorities() {
        // Gambito de Dama con …c5 dxc5: mayoría blanca a–d (3 contra 2), negra e–h (4 contra 3).
        let s = p("a2 b2 c2 f2 g2 h2", "a7 b7 e6 f7 g7 h7")
        #expect(s.majority(on: .queenside) == .white)
        #expect(s.majority(on: .kingside) == .black)
        #expect(s.pawnCount(.white, on: .queenside) == 3)
        #expect(s.traits.majority(on: .queenside) == .white)
        #expect(p("a2", "a7").majority(on: .queenside) == nil)
    }

    @Test("Casillas débiles (agujeros)")
    func holes() {
        // Najdorf II: d5 es un agujero negro (sin peones c ni e por detrás que lo cubran).
        let s = p("a2 b2 c2 e4 f2 g2 h2", "a6 b7 d6 e5 f7 g7 h7")
        #expect(s.holes(.black) & sq("d5") != 0)
        #expect(s.holes(.black) & sq("f5") == 0) // g7 todavía puede cubrirla con …g6
        // La posición inicial no tiene agujeros.
        let start = PawnStructure(white: Bitboard.rank(1), black: Bitboard.rank(6))
        #expect(start.holes(.white) == 0)
        #expect(start.holes(.black) == 0)
        // Tras g3 (fianchetto) h3 ya no se puede cubrir con un peón; f3 sí (e2).
        #expect(p("a2 b2 c2 d2 e2 f2 g3 h2", "").holes(.white) == sq("h3"))
        // Tras f4, g4 y h4, g3 queda sin cobertura posible.
        #expect(p("a2 b2 c2 d2 e2 f4 g4 h4", "").holes(.white) & sq("g3") != 0)
        // Una casilla con peón propio no es un agujero.
        #expect(p("d4", "").holes(.white) & sq("d4") == 0)
    }

    @Test("PawnTraits resume los rasgos de los dos bandos")
    func summary() {
        let s = Fixtures.structure(Fixtures.all[0].fen) // IQP
        let t = s.traits
        #expect(t.white.isolated == sq("d4"))
        #expect(t.white.islands == 3)
        #expect(t.black.islands == 2)
        #expect(t.openFiles == files("c"))
        #expect(t[.white].semiOpenFiles == files("e"))
        #expect(t[.black].semiOpenFiles == files("d"))
        #expect(t.white.passed == 0)
        #expect(t.black.passed == 0)
    }
}
