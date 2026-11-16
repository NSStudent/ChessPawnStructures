/// Familias del catálogo (capítulos de *Chess Structures* de Flores Rios, más las genéricas).
public enum StructureFamily: Int, Hashable, Sendable, CaseIterable {
    /// d4 contra …d5.
    case queenPawn
    /// Siciliana abierta.
    case openSicilian
    case benoni
    case kingsIndian
    case french
    /// Misceláneas (capítulo 22).
    case miscellaneous
    /// Genéricas: no son capítulos del libro.
    case generic

    public var name: String {
        switch self {
        case .queenPawn: "d4 contra …d5"
        case .openSicilian: "Siciliana abierta"
        case .benoni: "Benoni"
        case .kingsIndian: "India de Rey"
        case .french: "Francesa"
        case .miscellaneous: "Misceláneas"
        case .generic: "Genéricas"
        }
    }
}

/// Estructura con nombre del catálogo: las 28 del libro (en su orden) y 4 genéricas.
public enum StructureKind: Int, Hashable, Sendable, CaseIterable, Comparable {
    case isolatedQueenPawn = 0
    case hangingPawns
    case caroKann
    case slav
    case carlsbad
    case stonewall
    case grunfeldCenter
    case najdorfI
    case najdorfII
    case hedgehog
    case maroczy
    case asymmetricBenoni
    case symmetricBenoni
    case kingsIndianI
    case kingsIndianII
    case kingsIndianIII
    case openKingsIndian
    case kingsIndianComplex
    case frenchI
    case frenchII
    case frenchIII
    case threeThreeVersusFourTwo
    case panov
    case dragon
    case scheveningen
    case benko
    case closedRuyLopez
    case ruyLopezFormation
    // Genéricas
    case queensideMajority
    case doubledCPawns
    case berlin
    case londonColle

    public static func < (lhs: StructureKind, rhs: StructureKind) -> Bool { lhs.rawValue < rhs.rawValue }

    /// Número de capítulo del libro (1…28); `nil` en las genéricas.
    public var number: Int? { rawValue < 28 ? rawValue + 1 : nil }

    public var isGeneric: Bool { rawValue >= 28 }

    /// Definición completa (regla, nombre, familia…).
    @inlinable
    public var definition: StructureDefinition { StructureCatalog.definitions[rawValue] }

    public var name: String { definition.name }
}

/// Una estructura del catálogo en una orientación concreta.
///
/// `reversed == false` es la orientación del diagrama del libro; `true`, la misma estructura con los
/// colores invertidos (por ejemplo, la Carlsbad de la Caro-Kann Cambio).
public struct StructureID: Hashable, Sendable, Comparable, CustomStringConvertible {
    public var kind: StructureKind
    public var reversed: Bool

    @inlinable
    public init(_ kind: StructureKind, reversed: Bool = false) {
        self.kind = kind
        self.reversed = reversed
    }

    /// Índice de bit en `StructureSet` (0…63): `kind * 2 + reversed`.
    @inlinable
    public var bit: Int { kind.rawValue &* 2 &+ (reversed ? 1 : 0) }

    @inlinable
    public init?(bit: Int) {
        guard (0 ..< 64).contains(bit), let kind = StructureKind(rawValue: bit >> 1) else { return nil }
        self.init(kind, reversed: bit & 1 == 1)
    }

    public static func < (lhs: StructureID, rhs: StructureID) -> Bool { lhs.bit < rhs.bit }

    public static func == (lhs: StructureID, rhs: StructureID) -> Bool { lhs.bit == rhs.bit }

    public func hash(into hasher: inout Hasher) { hasher.combine(UInt8(truncatingIfNeeded: bit)) }

    public var description: String { kind.name + (reversed ? " (colores invertidos)" : "") }
}

/// Conjunto de estructuras como bitset de 64 bits (32 estructuras × 2 orientaciones). Es el formato
/// pensado para guardar en el índice (`structuresVisited`).
public struct StructureSet: Hashable, Sendable, Sequence, ExpressibleByArrayLiteral {
    public var rawValue: UInt64

    @inlinable
    public init(rawValue: UInt64 = 0) { self.rawValue = rawValue }

    public init(arrayLiteral elements: StructureID...) { self.init(elements) }

    @inlinable
    public mutating func insert(_ id: StructureID) { rawValue |= 1 << UInt64(id.bit) }

    @inlinable
    public mutating func formUnion(_ other: StructureSet) { rawValue |= other.rawValue }

    @inlinable
    public func union(_ other: StructureSet) -> StructureSet { StructureSet(rawValue: rawValue | other.rawValue) }

    @inlinable
    public var isEmpty: Bool { rawValue == 0 }

    @inlinable
    public init(_ id: StructureID) { rawValue = 1 << UInt64(id.bit) }

    @inlinable
    public init(_ ids: some Sequence<StructureID>) {
        rawValue = ids.reduce(0) { $0 | (1 << UInt64($1.bit)) }
    }

    @inlinable
    public func contains(_ id: StructureID) -> Bool { rawValue & (1 << UInt64(id.bit)) != 0 }

    /// Estructuras sin distinguir orientación.
    public var kinds: Set<StructureKind> { Set(map(\.kind)) }

    public var count: Int { rawValue.nonzeroBitCount }

    public struct Iterator: IteratorProtocol {
        var rest: UInt64
        public mutating func next() -> StructureID? {
            guard rest != 0 else { return nil }
            let bit = rest.trailingZeroBitCount
            rest &= rest - 1
            return StructureID(bit: bit)
        }
    }

    public func makeIterator() -> Iterator { Iterator(rest: rawValue) }
}

/// Regla de una estructura.
public enum StructureCondition: Hashable, Sendable {
    /// Casillas y columnas por bando (todas las del libro salvo ninguna excepción).
    case pattern(StructurePattern)
    /// Mayoría blanca en el flanco de dama: ningún bando tiene peones en la columna d y las blancas
    /// tienen más peones que las negras en a–c. Con colores invertidos, la mayoría es negra.
    case queensideMajority
}

/// Definición de una estructura del catálogo.
public struct StructureDefinition: Hashable, Sendable {
    public var kind: StructureKind
    /// Nombre en español.
    public var name: String
    /// Nombre en inglés.
    public var englishName: String
    public var family: StructureFamily
    /// Página del PDF del libro donde empieza el capítulo (`nil` en las genéricas).
    public var bookPage: Int?
    /// Lo que se exige.
    public var condition: StructureCondition
    /// Lo que suele acompañar sin exigirse (para similitud y ordenar, no para filtrar).
    public var typical: StructurePattern
    /// Peones que la regla obliga a tener (más = más específica).
    public var specificity: Int
    /// Columnas que la regla exige vacías (desempate entre reglas de igual especificidad).
    public var emptyFileCount: Int

    init(_ kind: StructureKind, _ name: String, _ englishName: String, _ family: StructureFamily,
         page: Int?, white: SidePattern = SidePattern(), black: SidePattern = SidePattern(),
         typical: StructurePattern = StructurePattern(), condition: StructureCondition? = nil) {
        self.kind = kind
        self.name = name
        self.englishName = englishName
        self.family = family
        bookPage = page
        let pattern = StructurePattern(white: white, black: black)
        self.condition = condition ?? .pattern(pattern)
        self.typical = typical
        switch self.condition {
        case let .pattern(p):
            specificity = p.forcedPawns
            emptyFileCount = p.white.emptyFiles.nonzeroBitCount + p.black.emptyFiles.nonzeroBitCount
        case .queensideMajority:
            specificity = 1
            emptyFileCount = 2
        }
    }

    /// ¿Se cumple en la orientación del libro?
    @inlinable
    public func matches(_ s: PawnStructure) -> Bool {
        switch condition {
        case let .pattern(p): p.matches(s)
        case .queensideMajority: StructureCatalog.queensideMajority(s)
        }
    }

    /// ¿Se cumple en la orientación indicada?
    @inlinable
    public func matches(_ s: PawnStructure, reversed: Bool) -> Bool {
        matches(reversed ? s.colorsReversed : s)
    }

    /// ¿Tiene también lo «típico»? (Siempre `true` si la estructura no define nada típico.)
    public func matchesTypical(_ s: PawnStructure, reversed: Bool = false) -> Bool {
        typical.matches(reversed ? s.colorsReversed : s)
    }
}

// MARK: - Catálogo

/// El catálogo: las 28 estructuras de Flores Rios y 4 genéricas, como reglas declarativas sobre
/// los peones (solo la colocación de los peones de cada diagrama; las reglas son propias).
public enum StructureCatalog {
    /// Duración mínima, en plies, para contar una estructura en una partida (decisión del 16 nov).
    public static let minimumPlies = 6

    /// Definiciones en el orden de `StructureKind`.
    public static let definitions: [StructureDefinition] = [
        // Familia 1 · d4 contra …d5
        .init(.isolatedQueenPawn, "Peón aislado (IQP)", "Isolated queen's pawn", .queenPawn, page: 14,
              white: SidePattern("d4", without: "ce"),
              black: SidePattern(without: "cd"),
              typical: StructurePattern(black: SidePattern("e6"))),
        .init(.hangingPawns, "Peones colgantes", "Hanging pawns", .queenPawn, page: 38,
              white: SidePattern("c4 d4", without: "be"),
              black: SidePattern(without: "cd"),
              typical: StructurePattern(black: SidePattern("e6"))),
        .init(.caroKann, "Formación Caro-Kann", "Caro-Kann formation", .queenPawn, page: 53,
              white: SidePattern("d4 c2|c3|c4", without: "e"),
              black: SidePattern("c6 e6", without: "d")),
        .init(.slav, "Formación Eslava", "Slav formation", .queenPawn, page: 71,
              white: SidePattern("d4 e3", without: "c"),
              black: SidePattern("c6 e6", without: "d")),
        .init(.carlsbad, "Carlsbad", "Carlsbad", .queenPawn, page: 88,
              white: SidePattern("d4 e3|e2", without: "c"),
              black: SidePattern("d5 c6|c7", without: "e")),
        .init(.stonewall, "Stonewall", "Stonewall", .queenPawn, page: 105,
              white: SidePattern("d4"),
              black: SidePattern("d5 e6 f5"),
              typical: StructurePattern(black: SidePattern("c6"))),
        .init(.grunfeldCenter, "Centro Grünfeld", "Grünfeld center", .queenPawn, page: 124,
              white: SidePattern("c3 d4 e4"),
              black: SidePattern("c5|c7", without: "d"),
              typical: StructurePattern(white: SidePattern(without: "b"))),
        // Familia 2 · Siciliana abierta
        .init(.najdorfI, "Najdorf Tipo I", "Najdorf type I", .openSicilian, page: 140,
              white: SidePattern("d5 c2|c3", without: "e"),
              black: SidePattern("d6 e5", without: "c")),
        .init(.najdorfII, "Najdorf Tipo II", "Najdorf type II", .openSicilian, page: 157,
              white: SidePattern("e4", without: "d"),
              black: SidePattern("d6 e5", without: "c"),
              typical: StructurePattern(white: SidePattern("c2|c3"))),
        .init(.hedgehog, "Erizo", "Hedgehog", .openSicilian, page: 180,
              white: SidePattern("c4 e4", without: "d"),
              black: SidePattern("a6 b6 d6 e6", without: "c")),
        .init(.maroczy, "Maróczy", "Maróczy bind", .openSicilian, page: 207,
              white: SidePattern("c4 e4", without: "d"),
              black: SidePattern("d6|d7 e7", without: "c"),
              typical: StructurePattern(black: SidePattern("g6"))),
        // Familia 3 · Benoni
        .init(.asymmetricBenoni, "Benoni asimétrica", "Asymmetric Benoni", .benoni, page: 226,
              white: SidePattern("d5 e4", without: "c"),
              black: SidePattern("c5 d6", without: "e")),
        .init(.symmetricBenoni, "Benoni simétrica", "Symmetric Benoni", .benoni, page: 242,
              white: SidePattern("c4 d5", without: "e"),
              black: SidePattern("c5 d6", without: "e")),
        // Familia 4 · India de Rey
        .init(.kingsIndianI, "India de Rey Tipo I", "King's Indian type I", .kingsIndian, page: 261,
              white: SidePattern("d5 e4", without: "c"),
              black: SidePattern("d6 e5", without: "c")),
        .init(.kingsIndianII, "India de Rey Tipo II", "King's Indian type II", .kingsIndian, page: 281,
              white: SidePattern("c4 d5 e4"),
              black: SidePattern("c5 d6 e5")),
        .init(.kingsIndianIII, "India de Rey Tipo III", "King's Indian type III", .kingsIndian, page: 297,
              white: SidePattern("c4 d5 e4"),
              black: SidePattern("c7 d6 e5")),
        .init(.openKingsIndian, "India de Rey abierta", "Open King's Indian", .kingsIndian, page: 323,
              white: SidePattern("c4 e4", without: "d"),
              black: SidePattern("d6 c6|c7", without: "e")),
        .init(.kingsIndianComplex, "Complejo India de Rey", "King's Indian complex", .kingsIndian, page: 338,
              white: SidePattern("c4 d4 e4"),
              black: SidePattern("d6 e5 c6|c7")),
        // Familia 5 · Francesa
        .init(.frenchI, "Francesa Tipo I", "French type I", .french, page: 353,
              white: SidePattern("d4", without: "e"),
              black: SidePattern("d5 e6", without: "f")),
        .init(.frenchII, "Francesa Tipo II", "French type II", .french, page: 364,
              white: SidePattern("e5 c3|c2", without: "d"),
              black: SidePattern("d5 e6", without: "c")),
        .init(.frenchIII, "Francesa Tipo III", "French type III", .french, page: 383,
              white: SidePattern("d4 e5"),
              black: SidePattern("d5 e6"),
              typical: StructurePattern(white: SidePattern(withFiles: "c"), black: SidePattern(withFiles: "c"))),
        // Misceláneas (capítulo 22)
        .init(.threeThreeVersusFourTwo, "3–3 contra 4–2", "3–3 vs 4–2", .miscellaneous, page: 400,
              white: SidePattern(without: "de", withFiles: "abcfgh"),
              black: SidePattern(without: "cd", withFiles: "abefgh")),
        .init(.panov, "Panov", "Panov", .miscellaneous, page: 403,
              white: SidePattern("c5 d4", without: "e"),
              black: SidePattern("d5 e6|e7", without: "c")),
        .init(.dragon, "Dragón", "Dragon", .miscellaneous, page: 408,
              white: SidePattern("e4", without: "d"),
              black: SidePattern("d6 g6", without: "c"),
              typical: StructurePattern(black: SidePattern("e7"))),
        .init(.scheveningen, "Scheveningen", "Scheveningen", .miscellaneous, page: 411,
              white: SidePattern("e4 c2|c3", without: "d"),
              black: SidePattern("d6 e6", without: "c")),
        .init(.benko, "Benko", "Benko", .miscellaneous, page: 415,
              white: SidePattern("d5 e4", without: "c"),
              black: SidePattern("c5 d6 e7", without: "ab")),
        .init(.closedRuyLopez, "Ruy López cerrada", "Closed Ruy Lopez", .miscellaneous, page: 417,
              white: SidePattern("c3 d5 e4"),
              black: SidePattern("b5 d6 e5 c4|c5")),
        .init(.ruyLopezFormation, "Formación López", "Ruy Lopez formation", .miscellaneous, page: 421,
              white: SidePattern("c3 d4 e4"),
              black: SidePattern("c5 d6 e5")),
        // Genéricas
        .init(.queensideMajority, "Mayoría en el flanco de dama", "Queenside majority", .generic, page: nil,
              condition: .queensideMajority),
        .init(.doubledCPawns, "Peones c doblados (Nimzo-Sämisch)", "Doubled c-pawns (Nimzo-Sämisch)", .generic, page: nil,
              white: SidePattern("c3 c4 d4")),
        .init(.berlin, "Berlinesa", "Berlin", .generic, page: nil,
              white: SidePattern("e5", without: "d"),
              black: SidePattern("c6 c7", without: "d")),
        .init(.londonColle, "Cadena de la Londres/Colle", "London/Colle chain", .generic, page: nil,
              white: SidePattern("c3 d4 e3"),
              black: SidePattern("d5"),
              typical: StructurePattern(white: SidePattern("f4"))),
    ]

    /// Las 28 estructuras del libro (sin las genéricas).
    public static var bookKinds: [StructureKind] { StructureKind.allCases.filter { !$0.isGeneric } }

    @inlinable
    static func queensideMajority(_ s: PawnStructure) -> Bool {
        let dFile = Bitboard.file(3)
        guard s.all & dFile == 0 else { return false }
        let abc = Bitboard.fileA | Bitboard.file(1) | Bitboard.file(2)
        return (s.white & abc).nonzeroBitCount > (s.black & abc).nonzeroBitCount
    }

    // MARK: Evaluación rápida

    /// Reglas compiladas a una tabla plana (sin enumeraciones ni existenciales en el bucle).
    @usableFromInline
    struct Compiled: Sendable {
        @usableFromInline var white: SidePattern
        @usableFromInline var black: SidePattern
        @usableFromInline var bit: UInt64
    }

    @usableFromInline
    static let compiled: [Compiled] = definitions.compactMap { d in
        guard case let .pattern(p) = d.condition else { return nil }
        return Compiled(white: p.white, black: p.black, bit: 1 << UInt64(d.kind.rawValue * 2))
    }

    @usableFromInline
    static let majorityBit: UInt64 = 1 << UInt64(StructureKind.queensideMajority.rawValue * 2)

    /// Todas las estructuras que cumple `s`, en las dos orientaciones, como bitset. Es la ruta
    /// rápida (sin reservas de memoria) para indexar bases.
    @inlinable
    public static func mask(_ s: PawnStructure) -> StructureSet {
        let r = s.colorsReversed
        let wf = Bitboard.fileSet(s.white), bf = Bitboard.fileSet(s.black)
        let rwf = Bitboard.fileSet(r.white), rbf = Bitboard.fileSet(r.black)
        var out: UInt64 = 0
        compiled.withUnsafeBufferPointer { rules in
            for rule in rules {
                if rule.white.matches(s.white, files: wf), rule.black.matches(s.black, files: bf) {
                    out |= rule.bit
                }
                if rule.white.matches(r.white, files: rwf), rule.black.matches(r.black, files: rbf) {
                    out |= rule.bit << 1
                }
            }
        }
        if queensideMajority(s) { out |= majorityBit }
        if queensideMajority(r) { out |= majorityBit << 1 }
        return StructureSet(rawValue: out)
    }

    /// Todas las estructuras que cumple `s` (las dos orientaciones).
    public static func classify(_ s: PawnStructure) -> Set<StructureID> {
        let m = mask(s)
        if m.isEmpty { return [] }
        var out = Set<StructureID>(minimumCapacity: m.count)
        for id in m { out.insert(id) }
        return out
    }

    /// La estructura principal: la más específica de las que se cumplen.
    ///
    /// Orden: primero las del libro y después las genéricas; dentro de cada grupo, más peones
    /// obligados (`specificity`); a igualdad, más columnas exigidas vacías; después la orientación
    /// del libro antes que la invertida, y por último el orden del catálogo. Devuelve `nil` si no se cumple ninguna.
    public static func primary(_ s: PawnStructure) -> StructureID? {
        primary(in: mask(s))
    }

    /// La más específica de un conjunto ya calculado.
    @inlinable
    public static func primary(in set: StructureSet) -> StructureID? {
        var rest = set.rawValue
        guard rest != 0 else { return nil }
        var bestBit = -1
        var bestKey = UInt32.max
        priorityKeys.withUnsafeBufferPointer { keys in
            while rest != 0 {
                let bit = rest.trailingZeroBitCount
                rest &= rest - 1
                if keys[bit] < bestKey { bestKey = keys[bit]; bestBit = bit }
            }
        }
        return StructureID(bit: bestBit)
    }

    /// `true` si `a` debe ir antes que `b` como etiqueta principal.
    public static func precedes(_ a: StructureID, _ b: StructureID) -> Bool {
        priorityKeys[a.bit] < priorityKeys[b.bit]
    }

    /// Clave de orden por bit (menor = va antes): genérica, especificidad, columnas vacías exigidas,
    /// orientación, catálogo.
    @usableFromInline
    static let priorityKeys: [UInt32] = (0 ..< 64).map { bit in
        guard let id = StructureID(bit: bit) else { return UInt32.max }
        let d = definitions[id.kind.rawValue]
        let generic: UInt32 = id.kind.isGeneric ? 1 : 0
        let specificity = UInt32(255 - min(d.specificity, 255))
        let empty = UInt32(15 - min(d.emptyFileCount, 15))
        return generic << 24 | specificity << 16 | empty << 12 | UInt32(id.reversed ? 1 : 0) << 8
            | UInt32(id.kind.rawValue)
    }

    /// Estructuras de `s` ordenadas de más a menos específica.
    public static func ranked(_ s: PawnStructure) -> [StructureID] {
        mask(s).sorted(by: precedes)
    }
}

extension PawnStructure {
    /// Estructuras del catálogo que cumple (las dos orientaciones).
    @inlinable
    public var structures: StructureSet { StructureCatalog.mask(self) }

    /// Estructura principal (la más específica).
    public var primaryStructure: StructureID? { StructureCatalog.primary(self) }
}
