/// Operaciones de bitboard para peones. Convención: a1 = bit 0, b1 = bit 1, …, h8 = bit 63
/// (la misma que Polyglot y python-chess).
@usableFromInline
enum Bitboard {
    @usableFromInline static let fileA: UInt64 = 0x0101_0101_0101_0101
    @usableFromInline static let fileH: UInt64 = fileA << 7
    @usableFromInline static let notFileA: UInt64 = ~fileA
    @usableFromInline static let notFileH: UInt64 = ~fileH
    @usableFromInline static let rank1: UInt64 = 0xFF

    @inlinable @inline(__always)
    static func file(_ index: Int) -> UInt64 { fileA << UInt64(index) }

    @inlinable @inline(__always)
    static func rank(_ index: Int) -> UInt64 { rank1 << UInt64(8 * index) }

    @inlinable @inline(__always)
    static func square(_ file: Int, _ rank: Int) -> UInt64 { 1 << UInt64(rank * 8 + file) }

    /// Un paso hacia la fila 8.
    @inlinable @inline(__always) static func north(_ b: UInt64) -> UInt64 { b << 8 }
    /// Un paso hacia la fila 1.
    @inlinable @inline(__always) static func south(_ b: UInt64) -> UInt64 { b >> 8 }
    /// Un paso hacia la columna h.
    @inlinable @inline(__always) static func east(_ b: UInt64) -> UInt64 { (b << 1) & notFileA }
    /// Un paso hacia la columna a.
    @inlinable @inline(__always) static func west(_ b: UInt64) -> UInt64 { (b >> 1) & notFileH }

    /// Cada casilla más todas las de su columna hacia la fila 8.
    @inlinable @inline(__always)
    static func northFill(_ b: UInt64) -> UInt64 {
        var b = b
        b |= b << 8
        b |= b << 16
        b |= b << 32
        return b
    }

    /// Cada casilla más todas las de su columna hacia la fila 1.
    @inlinable @inline(__always)
    static func southFill(_ b: UInt64) -> UInt64 {
        var b = b
        b |= b >> 8
        b |= b >> 16
        b |= b >> 32
        return b
    }

    /// Columnas completas de las casillas dadas.
    @inlinable @inline(__always)
    static func fileFill(_ b: UInt64) -> UInt64 { northFill(b) | southFill(b) }

    /// Columnas ocupadas como byte (bit 0 = columna a).
    @inlinable @inline(__always)
    static func fileSet(_ b: UInt64) -> UInt8 { UInt8(truncatingIfNeeded: southFill(b)) }

    /// Casillas atacadas por peones blancos.
    @inlinable @inline(__always)
    static func whiteAttacks(_ w: UInt64) -> UInt64 { ((w << 9) & notFileA) | ((w << 7) & notFileH) }

    /// Casillas atacadas por peones negros.
    @inlinable @inline(__always)
    static func blackAttacks(_ b: UInt64) -> UInt64 { ((b >> 7) & notFileA) | ((b >> 9) & notFileH) }

    /// Espejo vertical (fila 1 ↔ fila 8).
    @inlinable @inline(__always)
    static func flipVertical(_ b: UInt64) -> UInt64 { b.byteSwapped }

    @inlinable @inline(__always)
    static func count(_ b: UInt64) -> Int { b.nonzeroBitCount }
}
