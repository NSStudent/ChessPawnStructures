/// Distancia entre estructuras para buscar «parecidas».
///
/// `d(a, b) = hamming · Σ|casillas distintas| + Σ peso_rasgo · |diferencia del rasgo|`
///
/// - **Hamming de peones**: casillas donde una estructura tiene un peón de un color y la otra no
///   (blancas y negras por separado). Mover un peón una casilla cuesta 2; quitarlo, 1.
/// - **Rasgos** (por bando, diferencia absoluta de recuentos): aislados, doblados sobrantes,
///   pasados, retrasados, islas y peones colgantes.
/// - **Columnas**: casillas de columna que cambian de estado (abiertas; semiabiertas de cada bando).
/// - **Mayorías**: 1 por flanco donde cambia quién tiene la mayoría.
///
/// Los pesos por defecto (`Weights.standard`) dan más importancia a los rasgos que cambian el plan
/// que a la casilla exacta de un peón: un peón pasado de más pesa como mover un peón dos casillas.
public struct StructureDistance: Sendable {
    public struct Weights: Hashable, Sendable {
        public var hamming: Double
        public var isolated: Double
        public var doubled: Double
        public var passed: Double
        public var backward: Double
        public var islands: Double
        public var hanging: Double
        public var openFile: Double
        public var semiOpenFile: Double
        public var majority: Double

        public init(hamming: Double, isolated: Double, doubled: Double, passed: Double, backward: Double,
                    islands: Double, hanging: Double, openFile: Double, semiOpenFile: Double, majority: Double) {
            self.hamming = hamming
            self.isolated = isolated
            self.doubled = doubled
            self.passed = passed
            self.backward = backward
            self.islands = islands
            self.hanging = hanging
            self.openFile = openFile
            self.semiOpenFile = semiOpenFile
            self.majority = majority
        }

        /// | Componente | Peso |
        /// |---|--:|
        /// | Hamming (por casilla) | 1 |
        /// | Aislados | 1,5 |
        /// | Doblados (sobrantes) | 1 |
        /// | Pasados | 4 |
        /// | Retrasados | 1 |
        /// | Islas | 1 |
        /// | Colgantes (por peón) | 1 |
        /// | Columna abierta | 1,5 |
        /// | Columna semiabierta | 1 |
        /// | Mayoría por flanco | 2 |
        public static let standard = Weights(
            hamming: 1, isolated: 1.5, doubled: 1, passed: 4, backward: 1,
            islands: 1, hanging: 1, openFile: 1.5, semiOpenFile: 1, majority: 2
        )

        /// Solo Hamming de peones.
        public static let hammingOnly = Weights(
            hamming: 1, isolated: 0, doubled: 0, passed: 0, backward: 0,
            islands: 0, hanging: 0, openFile: 0, semiOpenFile: 0, majority: 0
        )
    }

    public var weights: Weights

    public init(weights: Weights = .standard) { self.weights = weights }

    /// Casillas con peón distinto (blancas y negras por separado).
    @inlinable
    public static func hamming(_ a: PawnStructure, _ b: PawnStructure) -> Int {
        (a.white ^ b.white).nonzeroBitCount + (a.black ^ b.black).nonzeroBitCount
    }

    public func callAsFunction(_ a: PawnStructure, _ b: PawnStructure) -> Double {
        distance(a, b)
    }

    public func distance(_ a: PawnStructure, _ b: PawnStructure) -> Double {
        if a == b { return 0 }
        return distance(a, PawnTraits(a), b, PawnTraits(b))
    }

    /// Variante con rasgos ya calculados (útil al comparar una estructura contra muchas).
    public func distance(_ a: PawnStructure, _ ta: PawnTraits, _ b: PawnStructure, _ tb: PawnTraits) -> Double {
        let w = weights
        var d = w.hamming * Double(Self.hamming(a, b))
        for side in Side.allCases {
            let x = ta[side], y = tb[side]
            d += w.isolated * Double(abs(x.isolated.nonzeroBitCount - y.isolated.nonzeroBitCount))
            d += w.doubled * Double(abs(x.doubledCount - y.doubledCount))
            d += w.passed * Double(abs(x.passed.nonzeroBitCount - y.passed.nonzeroBitCount))
            d += w.backward * Double(abs(x.backward.nonzeroBitCount - y.backward.nonzeroBitCount))
            d += w.islands * Double(abs(x.islands - y.islands))
            d += w.hanging * Double(abs(x.hanging.nonzeroBitCount - y.hanging.nonzeroBitCount))
            d += w.semiOpenFile * Double((x.semiOpenFiles ^ y.semiOpenFiles).nonzeroBitCount)
        }
        d += w.openFile * Double((ta.openFiles ^ tb.openFiles).nonzeroBitCount)
        for flank in Flank.allCases where ta.majority(on: flank) != tb.majority(on: flank) {
            d += w.majority
        }
        return d
    }

    /// La estructura más cercana a `target` entre `candidates` (la primera en caso de empate), con
    /// su posición y su distancia. `nil` si no hay candidatas.
    ///
    /// Con `allowingReversedColors`, también compara contra cada candidata con los colores
    /// invertidos y se queda con la menor de las dos distancias.
    public func nearest<C: Collection>(
        _ target: PawnStructure,
        in candidates: C,
        allowingReversedColors: Bool = false
    ) -> (index: C.Index, structure: PawnStructure, distance: Double)? where C.Element == PawnStructure {
        let tt = PawnTraits(target)
        var best: (index: C.Index, structure: PawnStructure, distance: Double)?
        for i in candidates.indices {
            let c = candidates[i]
            var d = c == target ? 0 : distance(target, tt, c, PawnTraits(c))
            if allowingReversedColors, d > 0 {
                let r = c.colorsReversed
                d = min(d, r == target ? 0 : distance(target, tt, r, PawnTraits(r)))
            }
            if best == nil || d < best!.distance { best = (i, c, d) }
            if d == 0 { break }
        }
        return best
    }
}

extension PawnStructure {
    /// Distancia con los pesos estándar (ver `StructureDistance`).
    public func distance(to other: PawnStructure) -> Double {
        StructureDistance().distance(self, other)
    }
}

/// La estructura más cercana a `target` entre `candidates`, con los pesos estándar.
public func nearest<C: Collection>(
    _ target: PawnStructure,
    in candidates: C
) -> (index: C.Index, structure: PawnStructure, distance: Double)? where C.Element == PawnStructure {
    StructureDistance().nearest(target, in: candidates)
}
