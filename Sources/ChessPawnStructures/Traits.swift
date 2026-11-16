/// Flanco del tablero para las mayorías.
public enum Flank: Hashable, Sendable, CaseIterable {
    /// Columnas a–d.
    case queenside
    /// Columnas e–h.
    case kingside

    @usableFromInline
    var mask: UInt64 {
        switch self {
        case .queenside: Bitboard.fileA | Bitboard.file(1) | Bitboard.file(2) | Bitboard.file(3)
        case .kingside: Bitboard.file(4) | Bitboard.file(5) | Bitboard.file(6) | Bitboard.fileH
        }
    }
}

// MARK: - Rasgos por bando
//
// Todos los rasgos se calculan para las blancas con desplazamientos de bits; los de las negras se
// obtienen aplicando la misma función a la estructura con colores invertidos y devolviendo el
// resultado con el espejo vertical. Así cada definición se escribe una sola vez.
//
// «Delante» significa hacia la fila 8 para las blancas y hacia la fila 1 para las negras.
// «Fila relativa» n es la fila n para las blancas y la 9 − n para las negras.

extension PawnStructure {
    /// Ejecuta `body(propios, rivales)` orientado como si `side` fuera las blancas y devuelve el
    /// bitboard en la orientación real.
    @inlinable @inline(__always)
    func oriented(_ side: Side, _ body: (UInt64, UInt64) -> UInt64) -> UInt64 {
        if side == .white { return body(white, black) }
        return Bitboard.flipVertical(body(Bitboard.flipVertical(black), Bitboard.flipVertical(white)))
    }

    /// **Aislados**: peones sin ningún peón propio en las columnas adyacentes (en cualquier fila).
    @inlinable
    public func isolated(_ side: Side) -> UInt64 {
        let own = self[side]
        return own & ~Bitboard.fileFill(Bitboard.east(own) | Bitboard.west(own))
    }

    /// **Doblados**: peones que comparten columna con otro peón propio. Se marcan todos los de la
    /// columna (en c3 y c4 se marcan los dos); `doubledCount` cuenta solo los sobrantes.
    @inlinable
    public func doubled(_ side: Side) -> UInt64 {
        let own = self[side]
        return own & (Bitboard.northFill(own << 8) | Bitboard.southFill(own >> 8))
    }

    /// Peones sobrantes en columnas con más de un peón propio: peones − columnas ocupadas.
    /// Con c3, c4 y c5 vale 2.
    @inlinable
    public func doubledCount(_ side: Side) -> Int {
        let own = self[side]
        return own.nonzeroBitCount - Bitboard.fileSet(own).nonzeroBitCount
    }

    /// **Pasados**: peones sin ningún peón rival delante en su columna ni en las adyacentes.
    /// Los peones propios no cuentan (dos peones doblados pueden ser ambos pasados).
    @inlinable
    public func passed(_ side: Side) -> UInt64 {
        oriented(side) { own, opp in
            // Casillas que vigilan los peones rivales hacia la fila 1: su columna y las adyacentes.
            let front = Bitboard.southFill(opp >> 8)
            return own & ~(front | Bitboard.east(front) | Bitboard.west(front))
        }
    }

    /// **Retrasados** (definición clásica): peones que no tienen ningún peón propio en columnas
    /// adyacentes a su altura o por detrás (nadie puede apoyarlos) y cuya casilla de avance está
    /// controlada por un peón rival. Un peón aislado no se cuenta como retrasado: el rasgo
    /// «aislado» es más fuerte y los dos se excluyen (como en Stockfish).
    @inlinable
    public func backward(_ side: Side) -> UInt64 {
        oriented(side) { own, opp in
            let neighbours = Bitboard.east(own) | Bitboard.west(own)
            let supportable = Bitboard.northFill(neighbours)
            let isolated = own & ~Bitboard.fileFill(neighbours)
            let stopAttacked = Bitboard.south(Bitboard.blackAttacks(opp))
            return own & ~supportable & ~isolated & stopAttacked
        }
    }

    /// **Conectados**: peones que forman pareja con otro peón propio de una columna adyacente:
    /// lo defienden, están defendidos por él o están a su lado en la misma fila (falange). En
    /// a7-b6 los dos están conectados; un peón con vecinos solo lejos (c2 y d5) no lo está.
    @inlinable
    public func connected(_ side: Side) -> UInt64 {
        let own = self[side]
        return own & (Bitboard.whiteAttacks(own) | Bitboard.blackAttacks(own) | Bitboard.east(own) | Bitboard.west(own))
    }

    /// **Cadenas**: peones unidos en diagonal por relaciones de defensa (defienden o están
    /// defendidos por un peón propio). Devuelve todos los miembros de cadenas de 2 o más peones.
    @inlinable
    public func chainMembers(_ side: Side) -> UInt64 {
        let own = self[side]
        let links = Bitboard.whiteAttacks(own) | Bitboard.blackAttacks(own)
        return own & links
    }

    /// Cada cadena (componente conexa por diagonales) como bitboard, ordenadas por su casilla más baja.
    public func chains(_ side: Side) -> [UInt64] {
        var rest = chainMembers(side)
        var out: [UInt64] = []
        while rest != 0 {
            var component = rest & (0 &- rest)
            while true {
                let grown = (component | Bitboard.whiteAttacks(component) | Bitboard.blackAttacks(component)) & rest
                if grown == component { break }
                component = grown
            }
            out.append(component)
            rest &= ~component
        }
        return out
    }

    /// Número de cadenas de 2 o más peones.
    @inlinable
    public func chainCount(_ side: Side) -> Int {
        var rest = chainMembers(side)
        var n = 0
        while rest != 0 {
            var component = rest & (0 &- rest)
            while true {
                let grown = (component | Bitboard.whiteAttacks(component) | Bitboard.blackAttacks(component)) & rest
                if grown == component { break }
                component = grown
            }
            n += 1
            rest &= ~component
        }
        return n
    }

    /// **Base de cadena**: miembros de una cadena que no están defendidos por un peón propio
    /// (el punto de ataque clásico, por ejemplo d4 en la cadena d4-e5 de la Francesa Avance).
    @inlinable
    public func chainBases(_ side: Side) -> UInt64 {
        oriented(side) { own, _ in
            let members = own & (Bitboard.whiteAttacks(own) | Bitboard.blackAttacks(own))
            return members & ~Bitboard.whiteAttacks(own)
        }
    }

    /// Columnas ocupadas por peones de `side` (bit 0 = columna a).
    @inlinable
    public func files(_ side: Side) -> UInt8 { Bitboard.fileSet(self[side]) }

    /// **Islas**: grupos de columnas contiguas con algún peón propio. Con peones en a, b, d, e, f y h
    /// hay tres islas.
    @inlinable
    public func islands(_ side: Side) -> Int {
        let f = files(side)
        return (f & ~(f << 1)).nonzeroBitCount
    }

    /// **Peones colgantes**: una isla de exactamente dos columnas adyacentes con un solo peón propio
    /// en cada una, los dos en la misma fila relativa (3.ª a 5.ª), y ambas columnas sin peones
    /// rivales (semiabiertas para el rival). El caso de libro: c4 y d4 sin peones b ni e, contra
    /// un rival sin peones c ni d.
    @inlinable
    public func hanging(_ side: Side) -> UInt64 {
        oriented(side) { own, opp in
            let ownFiles = Bitboard.fileSet(own)
            let oppFiles = Bitboard.fileSet(opp)
            let ranks345 = Bitboard.rank(2) | Bitboard.rank(3) | Bitboard.rank(4)
            var out: UInt64 = 0
            for f in 0 ..< 7 {
                let pair: UInt8 = 0b11 << UInt8(f)
                guard ownFiles & pair == pair, oppFiles & pair == 0 else { continue }
                if f > 0, ownFiles & (1 << UInt8(f - 1)) != 0 { continue }
                if f < 6, ownFiles & (1 << UInt8(f + 2)) != 0 { continue }
                let left = own & Bitboard.file(f)
                let right = own & Bitboard.file(f + 1)
                guard left.nonzeroBitCount == 1, right.nonzeroBitCount == 1,
                      left << 1 == right, left & ranks345 != 0
                else { continue }
                out |= left | right
            }
            return out
        }
    }

    /// **Columnas abiertas**: sin peones de ningún color (bit 0 = columna a).
    @inlinable
    public var openFiles: UInt8 { ~(Bitboard.fileSet(white) | Bitboard.fileSet(black)) }

    /// **Columnas semiabiertas para `side`**: sin peones propios pero con algún peón rival
    /// (las que puede usar `side` con sus torres para presionar un peón).
    @inlinable
    public func semiOpenFiles(_ side: Side) -> UInt8 {
        ~files(side) & files(side.opponent)
    }

    /// Peones de `side` en un flanco (a–d o e–h).
    @inlinable
    public func pawnCount(_ side: Side, on flank: Flank) -> Int {
        (self[side] & flank.mask).nonzeroBitCount
    }

    /// **Mayoría por flanco**: el bando con más peones en ese flanco, o `nil` si están igualados.
    @inlinable
    public func majority(on flank: Flank) -> Side? {
        let w = pawnCount(.white, on: flank)
        let b = pawnCount(.black, on: flank)
        return w == b ? nil : (w > b ? .white : .black)
    }

    /// **Casillas débiles (agujeros)**: casillas de las filas relativas 3.ª y 4.ª de `side` que ya
    /// no pueden ser atacadas por ningún peón propio (no hay peones propios en columnas adyacentes
    /// por detrás de ellas) y que no están ocupadas por un peón propio. Son las casillas donde el
    /// rival puede asentar una pieza; por ejemplo d5 para las negras en la Najdorf Tipo II.
    @inlinable
    public func holes(_ side: Side) -> UInt64 {
        oriented(side) { own, _ in
            let zone = Bitboard.rank(2) | Bitboard.rank(3)
            return zone & ~Bitboard.northFill(Bitboard.whiteAttacks(own)) & ~own
        }
    }

    /// Todos los rasgos calculados de una vez.
    @inlinable
    public var traits: PawnTraits { PawnTraits(self) }
}

/// Resumen de rasgos de una estructura (para similitud y explicaciones).
public struct PawnTraits: Hashable, Sendable {
    public struct SideTraits: Hashable, Sendable {
        public var isolated: UInt64
        public var doubled: UInt64
        public var doubledCount: Int
        public var passed: UInt64
        public var backward: UInt64
        public var connected: UInt64
        public var chainMembers: UInt64
        public var chainCount: Int
        public var islands: Int
        public var hanging: UInt64
        public var holes: UInt64
        public var files: UInt8
        public var semiOpenFiles: UInt8
        public var queenside: Int
        public var kingside: Int

        @inlinable
        init(_ s: PawnStructure, _ side: Side) {
            isolated = s.isolated(side)
            doubled = s.doubled(side)
            doubledCount = s.doubledCount(side)
            passed = s.passed(side)
            backward = s.backward(side)
            connected = s.connected(side)
            chainMembers = s.chainMembers(side)
            chainCount = s.chainCount(side)
            islands = s.islands(side)
            hanging = s.hanging(side)
            holes = s.holes(side)
            files = s.files(side)
            semiOpenFiles = s.semiOpenFiles(side)
            queenside = s.pawnCount(side, on: .queenside)
            kingside = s.pawnCount(side, on: .kingside)
        }
    }

    public var white: SideTraits
    public var black: SideTraits
    public var openFiles: UInt8

    @inlinable
    public init(_ structure: PawnStructure) {
        white = SideTraits(structure, .white)
        black = SideTraits(structure, .black)
        openFiles = structure.openFiles
    }

    @inlinable
    public subscript(side: Side) -> SideTraits { side == .white ? white : black }

    /// Bando con mayoría en el flanco, o `nil` si están igualados.
    @inlinable
    public func majority(on flank: Flank) -> Side? {
        let (w, b) = flank == .queenside ? (white.queenside, black.queenside) : (white.kingside, black.kingside)
        return w == b ? nil : (w > b ? .white : .black)
    }
}
