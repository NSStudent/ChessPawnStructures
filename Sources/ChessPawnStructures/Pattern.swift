/// Condición sobre los peones de un bando: casillas exigidas, alternativas y columnas.
///
/// Se escribe como en la tabla del catálogo: `SidePattern("d4 c2|c3|c4", without: "e")` = peón en d4, un peón
/// en c2, c3 o c4, y ningún peón en la columna e.
public struct SidePattern: Hashable, Sendable {
    /// Casillas que deben tener peón (todas).
    public var required: UInt64
    /// Grupos de alternativas: al menos una casilla de cada grupo debe tener peón. Como mucho dos
    /// grupos (el catálogo nunca necesita más); un grupo vacío (0) no exige nada.
    public var alternative0: UInt64
    public var alternative1: UInt64
    /// Columnas sin ningún peón de este bando (bit 0 = columna a).
    public var emptyFiles: UInt8
    /// Columnas con algún peón de este bando (solo lo usa 3–3 contra 4–2).
    public var occupiedFiles: UInt8

    public init(required: UInt64 = 0, alternative0: UInt64 = 0, alternative1: UInt64 = 0,
                emptyFiles: UInt8 = 0, occupiedFiles: UInt8 = 0) {
        self.required = required
        self.alternative0 = alternative0
        self.alternative1 = alternative1
        self.emptyFiles = emptyFiles
        self.occupiedFiles = occupiedFiles
    }

    /// - Parameters:
    ///   - squares: casillas separadas por espacios; `c6|c7` es un grupo de alternativas.
    ///   - without: columnas sin peón, por ejemplo `"ce"`.
    ///   - withFiles: columnas que deben tener algún peón, por ejemplo `"abcfgh"`.
    public init(_ squares: String = "", without: String = "", withFiles: String = "") {
        var required: UInt64 = 0
        var alternatives: [UInt64] = []
        for token in squares.split(separator: " ") {
            if token.contains("|") {
                alternatives.append(token.split(separator: "|").reduce(0) { $0 | Square.mask(String($1)) })
            } else {
                required |= Square.mask(String(token))
            }
        }
        precondition(alternatives.count <= 2, "SidePattern admite como mucho dos grupos de alternativas")
        self.init(
            required: required,
            alternative0: alternatives.first ?? 0,
            alternative1: alternatives.count > 1 ? alternatives[1] : 0,
            emptyFiles: Self.fileMask(without),
            occupiedFiles: Self.fileMask(withFiles)
        )
    }

    static func fileMask(_ letters: String) -> UInt8 {
        letters.utf8.reduce(0) { acc, c in
            guard c >= UInt8(ascii: "a"), c <= UInt8(ascii: "h") else { return acc }
            return acc | (1 << (c - UInt8(ascii: "a")))
        }
    }

    /// ¿Cumplen la condición los peones `pawns`, cuyas columnas ocupadas son `files`?
    @inlinable @inline(__always)
    public func matches(_ pawns: UInt64, files: UInt8) -> Bool {
        (pawns & required) == required
            && (alternative0 == 0 || pawns & alternative0 != 0)
            && (alternative1 == 0 || pawns & alternative1 != 0)
            && files & emptyFiles == 0
            && files & occupiedFiles == occupiedFiles
    }

    @inlinable
    public func matches(_ pawns: UInt64) -> Bool { matches(pawns, files: Bitboard.fileSet(pawns)) }

    /// Peones que obliga a tener: casillas exigidas + un peón por grupo de alternativas + uno por
    /// columna ocupada exigida.
    public var forcedPawns: Int {
        required.nonzeroBitCount + (alternative0 != 0 ? 1 : 0) + (alternative1 != 0 ? 1 : 0)
            + occupiedFiles.nonzeroBitCount
    }

    /// No exige nada.
    public var isEmpty: Bool {
        required == 0 && alternative0 == 0 && alternative1 == 0 && emptyFiles == 0 && occupiedFiles == 0
    }

    /// Texto legible, como en la tabla del catálogo: `"d4 c2|c3|c4 / sin e"`.
    public var summary: String {
        // Por columna y después por fila, como en la tabla del catálogo («d5 e6 f5»).
        func ordered(_ b: UInt64) -> [String] { Square.names(b).sorted() }
        var parts: [String] = ordered(required)
        for alt in [alternative0, alternative1] where alt != 0 {
            parts.append(ordered(alt).joined(separator: "|"))
        }
        if occupiedFiles != 0 { parts.append("columnas " + Self.letters(occupiedFiles)) }
        if emptyFiles != 0 { parts.append("sin " + Self.letters(emptyFiles)) }
        return parts.isEmpty ? "—" : parts.joined(separator: " ")
    }

    static func letters(_ mask: UInt8) -> String {
        String((0 ..< 8).compactMap { mask & (1 << UInt8($0)) != 0 ? Array("abcdefgh")[$0] : nil })
    }
}

/// Condición sobre los dos bandos.
public struct StructurePattern: Hashable, Sendable {
    public var white: SidePattern
    public var black: SidePattern

    public init(white: SidePattern = SidePattern(), black: SidePattern = SidePattern()) {
        self.white = white
        self.black = black
    }

    @inlinable @inline(__always)
    public func matches(_ s: PawnStructure, whiteFiles: UInt8, blackFiles: UInt8) -> Bool {
        white.matches(s.white, files: whiteFiles) && black.matches(s.black, files: blackFiles)
    }

    @inlinable
    public func matches(_ s: PawnStructure) -> Bool {
        matches(s, whiteFiles: Bitboard.fileSet(s.white), blackFiles: Bitboard.fileSet(s.black))
    }

    public var isEmpty: Bool { white.isEmpty && black.isEmpty }
    public var forcedPawns: Int { white.forcedPawns + black.forcedPawns }
}
