/// Tramo de una partida con la misma estructura de peones.
public struct StructureSpan: Hashable, Sendable {
    public var structure: PawnStructure
    /// Plies jugados cuando aparece la estructura (la posición tras el ply `firstPly`, contando
    /// desde 1 para la primera jugada de la partida).
    public var firstPly: Int
    /// Plies seguidos con esta estructura.
    public var plies: Int

    public init(structure: PawnStructure, firstPly: Int, plies: Int) {
        self.structure = structure
        self.firstPly = firstPly
        self.plies = plies
    }
}

/// Recorre la secuencia de estructuras de una partida (una por ply, tras cada jugada) y devuelve los
/// tramos estables: los que duran al menos `minimumPlies` plies seguidos (6 por defecto) y empiezan
/// en el ply `firstEligiblePly` o después.
///
/// Para contar solo desde la jugada 8: `firstEligiblePly: 14` cuando la
/// partida empieza en la posición inicial (tras el ply 14 se juega la jugada 8).
public func stableSpans(
    _ plies: some Sequence<PawnStructure>,
    minimumPlies: Int = StructureCatalog.minimumPlies,
    firstEligiblePly: Int = 1
) -> [StructureSpan] {
    var out: [StructureSpan] = []
    var current: StructureSpan?
    var ply = 0
    for s in plies {
        ply += 1
        if current?.structure == s {
            current!.plies += 1
            continue
        }
        if let c = current, c.plies >= minimumPlies, c.firstPly >= firstEligiblePly { out.append(c) }
        current = StructureSpan(structure: s, firstPly: ply, plies: 1)
    }
    if let c = current, c.plies >= minimumPlies, c.firstPly >= firstEligiblePly { out.append(c) }
    return out
}

/// Estructuras del catálogo que aparecen en una partida con la duración mínima.
public func structuresVisited(
    _ plies: some Sequence<PawnStructure>,
    minimumPlies: Int = StructureCatalog.minimumPlies,
    firstEligiblePly: Int = 1
) -> StructureSet {
    stableSpans(plies, minimumPlies: minimumPlies, firstEligiblePly: firstEligiblePly)
        .reduce(into: StructureSet()) { $0.formUnion($1.structure.structures) }
}
