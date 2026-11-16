/// Bando de un peón.
public enum Side: UInt8, Hashable, Sendable, CaseIterable {
    case white
    case black

    public var opponent: Side { self == .white ? .black : .white }
}

/// Estructura de peones: los bitboards de peones blancos y negros, sin piezas, turno ni enroques.
///
/// Convención de casillas: a1 = bit 0, b1 = bit 1, …, h1 = bit 7, a2 = bit 8, …, h8 = bit 63.
/// Es la de Polyglot y python-chess: los bitboards de peones de esos formatos se usan sin conversión.
///
/// El tipo es un valor de 16 bytes sin estado global: se puede usar como clave de diccionario
/// (por ejemplo, para clasificar una sola vez cada clave de peones distinta de una base).
public struct PawnStructure: Hashable, Sendable {
    /// Peones blancos.
    public var white: UInt64
    /// Peones negros.
    public var black: UInt64

    @inlinable
    public init(white: UInt64, black: UInt64) {
        self.white = white
        self.black = black
    }

    /// Bitboard de peones de un bando.
    @inlinable
    public subscript(side: Side) -> UInt64 {
        get { side == .white ? white : black }
        set {
            if side == .white { white = newValue } else { black = newValue }
        }
    }

    /// Todos los peones.
    @inlinable public var all: UInt64 { white | black }

    /// Colores invertidos: espejo vertical del tablero y cambio de bando. Un peón blanco en d4 pasa a
    /// ser un peón negro en d5. Es una involución: `s.colorsReversed.colorsReversed == s`.
    ///
    /// Con colores invertidos, la Carlsbad del Gambito de Dama Cambio es la de la Caro-Kann Cambio.
    @inlinable
    public var colorsReversed: PawnStructure {
        PawnStructure(white: Bitboard.flipVertical(black), black: Bitboard.flipVertical(white))
    }

    /// Espejo horizontal (columna a ↔ columna h), sin cambiar colores. No forma parte de las reglas
    /// del catálogo (el flanco importa), pero sirve para análisis propios.
    public var mirroredHorizontally: PawnStructure {
        PawnStructure(white: Self.mirrorFiles(white), black: Self.mirrorFiles(black))
    }

    /// Clave por columnas: número de peones por columna y color (el modo «Files» de Scid).
    @inlinable
    public var fileKey: FileKey { FileKey(self) }

    /// ¿Hay un peón de `side` en la casilla dada (por ejemplo `"d4"`)?
    public func hasPawn(_ side: Side, on square: String) -> Bool {
        guard let index = Square.index(square) else { return false }
        return self[side] & (1 << UInt64(index)) != 0
    }

    static func mirrorFiles(_ b: UInt64) -> UInt64 {
        var out: UInt64 = 0
        var rest = b
        while rest != 0 {
            let s = rest.trailingZeroBitCount
            rest &= rest - 1
            let file = s & 7
            out |= 1 << UInt64((s & ~7) | (7 - file))
        }
        return out
    }
}

// MARK: - FEN

extension PawnStructure {
    /// Lee los peones del primer campo de un FEN (el resto de campos se ignora).
    /// Devuelve `nil` si el campo de colocación no tiene 8 filas de 8 casillas.
    public init?(fen: String) {
        let placement = fen.split(separator: " ", maxSplits: 1).first.map(String.init) ?? ""
        let rows = placement.split(separator: "/", omittingEmptySubsequences: false)
        guard rows.count == 8 else { return nil }
        var white: UInt64 = 0
        var black: UInt64 = 0
        for (i, row) in rows.enumerated() {
            let rank = 7 - i
            var file = 0
            for ch in row {
                if let skip = ch.wholeNumberValue {
                    guard (1 ... 8).contains(skip) else { return nil }
                    file += skip
                    continue
                }
                guard file < 8, "pnbrqkPNBRQK".contains(ch) else { return nil }
                let bit: UInt64 = 1 << UInt64(rank * 8 + file)
                if ch == "P" { white |= bit } else if ch == "p" { black |= bit }
                file += 1
            }
            guard file == 8 else { return nil }
        }
        self.init(white: white, black: black)
    }

    /// Campo de colocación FEN con solo los peones (útil para depurar y para tests).
    public var fenPlacement: String {
        var rows: [String] = []
        for rank in stride(from: 7, through: 0, by: -1) {
            var row = ""
            var empty = 0
            for file in 0 ..< 8 {
                let bit = Bitboard.square(file, rank)
                let ch: Character? = white & bit != 0 ? "P" : (black & bit != 0 ? "p" : nil)
                if let ch {
                    if empty > 0 { row += String(empty); empty = 0 }
                    row.append(ch)
                } else {
                    empty += 1
                }
            }
            if empty > 0 { row += String(empty) }
            rows.append(row)
        }
        return rows.joined(separator: "/")
    }
}

extension PawnStructure: CustomStringConvertible {
    /// Diagrama de 8 líneas (fila 8 arriba): `P` blanco, `p` negro, `.` vacío.
    public var description: String {
        var lines: [String] = []
        for rank in stride(from: 7, through: 0, by: -1) {
            var line = ""
            for file in 0 ..< 8 {
                let bit = Bitboard.square(file, rank)
                line.append(white & bit != 0 ? "P" : (black & bit != 0 ? "p" : "."))
            }
            lines.append(line)
        }
        return lines.joined(separator: "\n")
    }
}

// MARK: - Casillas

/// Utilidades de nombres de casillas («d4» ↔ 27).
public enum Square {
    /// Índice 0…63 de una casilla escrita como «d4»; `nil` si no es válida.
    public static func index(_ name: some StringProtocol) -> Int? {
        let chars = Array(name.utf8)
        guard chars.count == 2,
              chars[0] >= UInt8(ascii: "a"), chars[0] <= UInt8(ascii: "h"),
              chars[1] >= UInt8(ascii: "1"), chars[1] <= UInt8(ascii: "8")
        else { return nil }
        return Int(chars[1] - UInt8(ascii: "1")) * 8 + Int(chars[0] - UInt8(ascii: "a"))
    }

    /// Bitboard con las casillas dadas («d4 e5» o `["d4", "e5"]`). Las casillas no válidas se ignoran.
    public static func mask(_ names: String) -> UInt64 {
        names.split(separator: " ").reduce(0) { acc, n in
            acc | (index(n).map { 1 << UInt64($0) } ?? 0)
        }
    }

    /// Nombre de la casilla de índice 0…63.
    public static func name(_ index: Int) -> String {
        let files = Array("abcdefgh")
        return "\(files[index & 7])\(index / 8 + 1)"
    }

    /// Nombres de las casillas de un bitboard, de a1 a h8.
    public static func names(_ bitboard: UInt64) -> [String] {
        var out: [String] = []
        var rest = bitboard
        while rest != 0 {
            out.append(name(rest.trailingZeroBitCount))
            rest &= rest - 1
        }
        return out
    }
}

// MARK: - Clave por columnas

/// Número de peones por columna y color, empaquetado en 64 bits (4 bits por columna y color).
///
/// Es el modo «Files» de Scid: dos estructuras con la misma clave tienen los mismos peones en cada
/// columna aunque estén en filas distintas. Nibble `file` = blancas en esa columna, nibble
/// `8 + file` = negras. Como cada bando tiene como mucho 8 peones, 4 bits bastan.
public struct FileKey: Hashable, Sendable, Comparable {
    public var rawValue: UInt64

    @inlinable
    public init(rawValue: UInt64) { self.rawValue = rawValue }

    @inlinable
    public init(_ structure: PawnStructure) {
        var raw: UInt64 = 0
        for file in 0 ..< 8 {
            let mask = Bitboard.file(file)
            raw |= UInt64((structure.white & mask).nonzeroBitCount) << UInt64(4 * file)
            raw |= UInt64((structure.black & mask).nonzeroBitCount) << UInt64(4 * (8 + file))
        }
        rawValue = raw
    }

    /// Peones de `side` en la columna `file` (0 = a, 7 = h).
    @inlinable
    public func count(_ side: Side, file: Int) -> Int {
        let nibble = side == .white ? file : 8 + file
        return Int((rawValue >> UInt64(4 * nibble)) & 0xF)
    }

    /// Recuentos por columna de a a h.
    public func counts(_ side: Side) -> [Int] { (0 ..< 8).map { count(side, file: $0) } }

    public static func < (lhs: FileKey, rhs: FileKey) -> Bool { lhs.rawValue < rhs.rawValue }
}

extension FileKey: CustomStringConvertible {
    /// Por ejemplo `"11101111/11011111"`: recuentos blancos de a a h, barra, recuentos negros.
    public var description: String {
        let w = counts(.white).map(String.init).joined()
        let b = counts(.black).map(String.init).joined()
        return "\(w)/\(b)"
    }
}
