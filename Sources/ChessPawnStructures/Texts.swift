import Foundation

/// Idioma de los textos del catálogo.
public enum StructureLanguage: String, Hashable, Sendable, CaseIterable {
    case spanish = "es"
    case english = "en"

    /// Español si el idioma del `locale` es el español; inglés en cualquier otro caso.
    public init(locale: Locale) {
        self = locale.language.languageCode?.identifier == "es" ? .spanish : .english
    }
}

/// Textos de una estructura para mostrarla: nombre, regla en una línea y planes de cada bando.
///
/// Los textos están escritos para el paquete (ideas generales de dominio público), no copiados del
/// libro. Las casillas y los bandos siguen la orientación pedida: con colores invertidos, la regla de
/// la IQP habla de un peón aislado negro en d5 y los planes blancos son los negros del libro.
public struct StructureText: Hashable, Sendable {
    /// Nombre de la estructura (con «colores invertidos» si procede).
    public var name: String
    /// Qué define la estructura, en una línea.
    public var rule: String
    /// 2–3 planes típicos de las blancas.
    public var whitePlans: [String]
    /// 2–3 planes típicos de las negras.
    public var blackPlans: [String]

    public init(name: String, rule: String, whitePlans: [String], blackPlans: [String]) {
        self.name = name
        self.rule = rule
        self.whitePlans = whitePlans
        self.blackPlans = blackPlans
    }

    /// Planes de un bando.
    public func plans(for side: Side) -> [String] { side == .white ? whitePlans : blackPlans }

    /// Planes en un solo texto, con un encabezado por bando y una viñeta por plan:
    ///
    ///     Blancas:
    ///     • …
    ///
    ///     Negras:
    ///     • …
    public func formattedPlans(_ language: StructureLanguage) -> String {
        let (white, black) = language == .spanish ? ("Blancas", "Negras") : ("White", "Black")
        func block(_ title: String, _ plans: [String]) -> String {
            ([title + ":"] + plans.map { "• " + $0 }).joined(separator: "\n")
        }
        return block(white, whitePlans) + "\n\n" + block(black, blackPlans)
    }
}

/// Estructura principal de una posición con sus textos.
public struct StructureSummary: Hashable, Sendable {
    public var structure: StructureID
    public var text: StructureText

    public init(structure: StructureID, text: StructureText) {
        self.structure = structure
        self.text = text
    }
}

extension StructureKind {
    /// Textos en la orientación del libro.
    public func text(_ language: StructureLanguage) -> StructureText {
        StructureID(self).text(language)
    }

    /// Nombre en el idioma pedido.
    public func name(_ language: StructureLanguage) -> String {
        language == .spanish ? definition.name : definition.englishName
    }
}

extension StructureID {
    /// Textos en esta orientación: con `reversed`, se cambian los bandos, las casillas pasan a su
    /// simétrica vertical (d4 ↔ d5) y los planes blancos son los negros del libro.
    public func text(_ language: StructureLanguage) -> StructureText {
        let raw = StructureTexts.raw(kind, language)
        let suffix = language == .spanish ? " (colores invertidos)" : " (reversed colors)"
        let name = kind.name(language) + (reversed ? suffix : "")
        func resolve(_ s: String) -> String { StructureTexts.resolve(s, language, reversed: reversed) }
        return StructureText(
            name: name,
            rule: resolve(raw.rule),
            whitePlans: (reversed ? raw.black : raw.white).map(resolve),
            blackPlans: (reversed ? raw.white : raw.black).map(resolve)
        )
    }

    /// Textos en el idioma del `locale` (español o inglés).
    public func text(locale: Locale) -> StructureText { text(StructureLanguage(locale: locale)) }
}

extension PawnStructure {
    /// Estructura principal (`StructureCatalog.primary`) con su nombre, regla y planes en el idioma
    /// del `locale`; `nil` si no cumple ninguna estructura del catálogo.
    public func summary(locale: Locale = .current) -> StructureSummary? {
        summary(StructureLanguage(locale: locale))
    }

    /// Estructura principal con sus textos en el idioma pedido.
    public func summary(_ language: StructureLanguage) -> StructureSummary? {
        guard let id = StructureCatalog.primary(self) else { return nil }
        return StructureSummary(structure: id, text: id.text(language))
    }
}

// MARK: - Datos

/// Textos de las 32 estructuras en la orientación del libro.
///
/// Marcadores: `{W}` y `{B}` son los bandos («las blancas» / «White»); al invertir colores se
/// intercambian. Las casillas (`d4`, `b2-b4`, `Cd2-f1`…) se reflejan al invertir. La primera letra de
/// cada texto se pone en mayúscula al resolverlo.
enum StructureTexts {
    struct Raw {
        var rule: String
        var white: [String]
        var black: [String]
    }

    static func raw(_ kind: StructureKind, _ language: StructureLanguage) -> Raw {
        let entry = table[kind.rawValue]
        return language == .spanish ? entry.es : entry.en
    }

    static func resolve(_ text: String, _ language: StructureLanguage, reversed: Bool) -> String {
        let (white, black) = language == .spanish ? ("las blancas", "las negras") : ("White", "Black")
        var out = text
            .replacingOccurrences(of: "{W}", with: reversed ? "\u{0}" : white)
            .replacingOccurrences(of: "{B}", with: reversed ? white : black)
            .replacingOccurrences(of: "\u{0}", with: black)
        if reversed { out = flipSquares(out) }
        guard let first = out.first else { return out }
        return first.uppercased() + out.dropFirst()
    }

    /// Cambia cada casilla `[a-h][1-8]` por su simétrica vertical (d4 → d5).
    static func flipSquares(_ text: String) -> String {
        var scalars = Array(text.unicodeScalars)
        var i = 0
        while i + 1 < scalars.count {
            let file = scalars[i].value
            let rank = scalars[i + 1].value
            let nextIsDigit = i + 2 < scalars.count && (48 ... 57).contains(scalars[i + 2].value)
            if (97 ... 104).contains(file), (49 ... 56).contains(rank), !nextIsDigit {
                // '1' + '8' = 49 + 56 = 105: el dígito n pasa a 9 − n.
                scalars[i + 1] = Unicode.Scalar(UInt8(truncatingIfNeeded: 105 - rank))
                i += 2
            } else {
                i += 1
            }
        }
        var out = String.UnicodeScalarView()
        out.append(contentsOf: scalars)
        return String(out)
    }

    // swiftlint:disable line_length
    static let table: [(es: Raw, en: Raw)] = [
        // 01 Peón aislado (IQP)
        (Raw(rule: "{W} tienen un peón aislado en d4, sin peones c ni e, y {B} no tienen peones c ni d.",
             white: ["Usar las casillas e5 y c5 para los caballos y atacar en el flanco de rey.",
                     "Preparar la ruptura d4-d5 para abrir el centro cuando las piezas estén activas.",
                     "Evitar cambios: el peón aislado da más juego con muchas piezas en el tablero."],
             black: ["Bloquear el peón en d5, mejor con un caballo.",
                     "Cambiar piezas hacia un final en el que d4 sea solo una debilidad.",
                     "Presionar d4 con las torres por la columna d y con las piezas menores."]),
         Raw(rule: "{W} has an isolated pawn on d4 with no c- or e-pawns, and {B} has no c- or d-pawn.",
             white: ["Use e5 and c5 for the knights and attack on the kingside.",
                     "Prepare the d4-d5 break to open the centre once the pieces are active.",
                     "Avoid exchanges: the isolated pawn gives more play with many pieces on the board."],
             black: ["Blockade the pawn on d5, ideally with a knight.",
                     "Trade pieces towards an endgame where d4 is just a weakness.",
                     "Pressure d4 with the rooks on the d-file and with the minor pieces."])),
        // 02 Peones colgantes
        (Raw(rule: "{W} tienen peones en c4 y d4, sin peones b ni e, y {B} no tienen peones c ni d.",
             white: ["Avanzar d4-d5 o c4-c5 en el momento justo para abrir líneas.",
                     "Aprovechar las columnas b y e semiabiertas y el espacio central para atacar.",
                     "Mantener los dos peones a la par: un avance sin preparar deja casillas débiles."],
             black: ["Presionar c4 y d4 con las piezas para forzar el avance de uno de ellos.",
                     "Tras c4-c5 o d4-d5, ocupar la casilla que queda libre delante del otro peón.",
                     "Cambiar piezas: en el final los peones colgantes suelen ser débiles."]),
         Raw(rule: "{W} has pawns on c4 and d4 with no b- or e-pawns, and {B} has no c- or d-pawn.",
             white: ["Push d4-d5 or c4-c5 at the right moment to open lines.",
                     "Use the half-open b- and e-files and the central space to attack.",
                     "Keep the two pawns side by side: an unprepared advance leaves weak squares."],
             black: ["Pressure c4 and d4 with the pieces to force one of them forward.",
                     "After c4-c5 or d4-d5, occupy the square left free in front of the other pawn.",
                     "Trade pieces: hanging pawns are usually weak in the endgame."])),
        // 03 Formación Caro-Kann
        (Raw(rule: "{W} tienen un peón en d4 (y el c en c2, c3 o c4) sin peón e; {B} tienen c6 y e6 sin peón d.",
             white: ["Aprovechar el espacio central y la casilla e5 para un caballo.",
                     "Ganar espacio en el flanco de rey, por ejemplo avanzando el peón h.",
                     "Preparar d4-d5 si el rival se retrasa en el desarrollo."],
             black: ["Liberarse con las rupturas c6-c5 o e6-e5.",
                     "Desarrollarse detrás de la cadena c6-e6 y buscar cambios.",
                     "Elegir el enroque según dónde ataque el rival y contraatacar en el centro."]),
         Raw(rule: "{W} has a pawn on d4 (and the c-pawn on c2, c3 or c4) with no e-pawn; {B} has c6 and e6 with no d-pawn.",
             white: ["Use the central space and the e5 square for a knight.",
                     "Gain space on the kingside, for example by pushing the h-pawn.",
                     "Prepare d4-d5 if the opponent falls behind in development."],
             black: ["Free the position with the c6-c5 or e6-e5 breaks.",
                     "Develop behind the c6-e6 chain and look for exchanges.",
                     "Castle away from the opponent's attack and counter in the centre."])),
        // 04 Formación Eslava
        (Raw(rule: "{W} tienen d4 y e3 sin peón c; {B} tienen c6 y e6 sin peón d.",
             white: ["Preparar e3-e4 para dominar el centro.",
                     "Instalar un caballo en e5 y usar la columna c semiabierta."],
             black: ["Responder a e3-e4 con c6-c5 o e6-e5 para no quedarse sin espacio.",
                     "Tener lista la ruptura liberadora e6-e5.",
                     "Aprovechar en el final la mayoría de peones del flanco de dama."]),
         Raw(rule: "{W} has d4 and e3 with no c-pawn; {B} has c6 and e6 with no d-pawn.",
             white: ["Prepare e3-e4 to take over the centre.",
                     "Post a knight on e5 and use the half-open c-file."],
             black: ["Meet e3-e4 with c6-c5 or e6-e5 so as not to run out of space.",
                     "Keep the freeing e6-e5 break ready.",
                     "Use the queenside pawn majority in the endgame."])),
        // 05 Carlsbad
        (Raw(rule: "{W} tienen d4 y el peón e en e2 o e3, sin peón c; {B} tienen d5 y el peón c en c6 o c7, sin peón e.",
             white: ["Ataque de minorías: avanzar b2-b4-b5 para dejar un peón c débil.",
                     "Preparar f2-f3 y e3-e4 para ganar el centro.",
                     "Atacar en el flanco de rey si el rival se vuelca en el flanco de dama."],
             black: ["Llevar un caballo a e4 y apoyarlo con f7-f5.",
                     "Atacar en el flanco de rey con piezas mientras el rival juega en el flanco de dama.",
                     "Frenar el ataque de minorías con b7-b5 o cubriendo bien c6."]),
         Raw(rule: "{W} has d4 and the e-pawn on e2 or e3 with no c-pawn; {B} has d5 and the c-pawn on c6 or c7 with no e-pawn.",
             white: ["Minority attack: push b2-b4-b5 to leave a weak c-pawn.",
                     "Prepare f2-f3 and e3-e4 to win the centre.",
                     "Attack on the kingside if the opponent commits to the queenside."],
             black: ["Bring a knight to e4 and support it with f7-f5.",
                     "Attack on the kingside with pieces while the opponent plays on the queenside.",
                     "Slow the minority attack with b7-b5 or by covering c6 well."])),
        // 06 Stonewall
        (Raw(rule: "{W} tienen d4; {B} tienen la cadena d5-e6-f5.",
             white: ["Ocupar e5 con un caballo y cambiar el alfil rival que defiende esa casilla.",
                     "Abrir el centro con c4 o e2-e4 para aprovechar la casilla e5.",
                     "Jugar en el flanco de dama, donde el rival tiene menos piezas."],
             black: ["Instalar un caballo en e4, sostenido por d5 y f5.",
                     "Atacar en el flanco de rey con g7-g5 o llevando piezas hacia h6 y g6.",
                     "Vigilar e5 y buscar actividad para el alfil de c8."]),
         Raw(rule: "{W} has d4; {B} has the d5-e6-f5 chain.",
             white: ["Occupy e5 with a knight and trade off the enemy bishop that guards it.",
                     "Open the centre with c4 or e2-e4 to make the most of e5.",
                     "Play on the queenside, where the opponent has fewer pieces."],
             black: ["Post a knight on e4, supported by d5 and f5.",
                     "Attack on the kingside with g7-g5 or by bringing pieces to h6 and g6.",
                     "Watch e5 and find activity for the c8 bishop."])),
        // 07 Centro Grünfeld
        (Raw(rule: "{W} tienen c3, d4 y e4; {B} tienen el peón c en c5 o c7 y no tienen peón d.",
             white: ["Mantener el centro y preparar d4-d5 para ganar espacio.",
                     "Atacar en el flanco de rey con el apoyo del centro.",
                     "Si el rival cambia en d4, aprovechar un peón d pasado."],
             black: ["Presionar d4 con c7-c5, el alfil de g7 y los caballos.",
                     "Provocar d4-d5 y bloquear después el centro.",
                     "Usar la mayoría de peones del flanco de dama en el final."]),
         Raw(rule: "{W} has c3, d4 and e4; {B} has the c-pawn on c5 or c7 and no d-pawn.",
             white: ["Keep the centre and prepare d4-d5 to gain space.",
                     "Attack on the kingside with the support of the centre.",
                     "If the opponent exchanges on d4, make use of a passed d-pawn."],
             black: ["Pressure d4 with c7-c5, the g7 bishop and the knights.",
                     "Provoke d4-d5 and then blockade the centre.",
                     "Use the queenside pawn majority in the endgame."])),
        // 08 Najdorf Tipo I
        (Raw(rule: "{W} tienen d5 (y el peón c en c2 o c3) sin peón e; {B} tienen d6 y e5 sin peón c.",
             white: ["Mantener el puesto de d5 y presionar el peón retrasado d6.",
                     "Ganar espacio en el flanco de dama con c2-c4 y b2-b4."],
             black: ["Atacar en el flanco de rey con f7-f5.",
                     "Jugar en el flanco de dama con b7-b5 y la columna c semiabierta."]),
         Raw(rule: "{W} has d5 (and the c-pawn on c2 or c3) with no e-pawn; {B} has d6 and e5 with no c-pawn.",
             white: ["Hold the d5 outpost and pressure the backward d6-pawn.",
                     "Gain queenside space with c2-c4 and b2-b4."],
             black: ["Attack on the kingside with f7-f5.",
                     "Play on the queenside with b7-b5 and the half-open c-file."])),
        // 09 Najdorf Tipo II
        (Raw(rule: "{W} tienen e4 sin peón d; {B} tienen d6 y e5 sin peón c.",
             white: ["Controlar d5 y ocuparlo con una pieza.",
                     "Atacar en el flanco de rey con f2-f4 o g2-g4 según los enroques."],
             black: ["Preparar d6-d5 para liberar el juego y deshacerse del peón retrasado.",
                     "Presionar por la columna c semiabierta contra c2 o c3.",
                     "Disputar d5 con las piezas para que el rival no lo ocupe."]),
         Raw(rule: "{W} has e4 with no d-pawn; {B} has d6 and e5 with no c-pawn.",
             white: ["Control d5 and occupy it with a piece.",
                     "Attack on the kingside with f2-f4 or g2-g4, depending on the castling."],
             black: ["Prepare d6-d5 to free the game and get rid of the backward pawn.",
                     "Press down the half-open c-file against c2 or c3.",
                     "Contest d5 with the pieces so the opponent cannot occupy it."])),
        // 10 Erizo
        (Raw(rule: "{W} tienen c4 y e4 sin peón d; {B} tienen a6, b6, d6 y e6 sin peón c.",
             white: ["Usar el espacio para impedir las rupturas b6-b5 y d6-d5.",
                     "Preparar con calma un ataque en el flanco de rey con f2-f4 y g2-g4.",
                     "No precipitarse: el rival espera a que un avance prematuro deje debilidades."],
             black: ["Esperar con las piezas bien colocadas y preparar b6-b5 o d6-d5.",
                     "Presionar c4 y e4 con los alfiles y los caballos."]),
         Raw(rule: "{W} has c4 and e4 with no d-pawn; {B} has a6, b6, d6 and e6 with no c-pawn.",
             white: ["Use the space to prevent the b6-b5 and d6-d5 breaks.",
                     "Calmly prepare a kingside attack with f2-f4 and g2-g4.",
                     "Don't rush: the opponent is waiting for a premature advance to leave weaknesses."],
             black: ["Wait with well-placed pieces and prepare b6-b5 or d6-d5.",
                     "Pressure c4 and e4 with the bishops and knights."])),
        // 11 Maróczy
        (Raw(rule: "{W} tienen c4 y e4 sin peón d; {B} tienen e7 y el peón d en d6 o d7, sin peón c.",
             white: ["Controlar d5 para restringir las piezas rivales.",
                     "Ganar espacio en el flanco de dama con b2-b4 y c4-c5."],
             black: ["Preparar las rupturas b7-b5 o f7-f5.",
                     "Cambiar piezas menores para aliviar la falta de espacio.",
                     "Presionar c4 y e4 con el alfil de g7 y por la columna c."]),
         Raw(rule: "{W} has c4 and e4 with no d-pawn; {B} has e7 and the d-pawn on d6 or d7, with no c-pawn.",
             white: ["Control d5 to restrict the opponent's pieces.",
                     "Gain queenside space with b2-b4 and c4-c5."],
             black: ["Prepare the b7-b5 or f7-f5 breaks.",
                     "Trade minor pieces to ease the lack of space.",
                     "Pressure c4 and e4 with the g7 bishop and down the c-file."])),
        // 12 Benoni asimétrica
        (Raw(rule: "{W} tienen d5 y e4 sin peón c; {B} tienen c5 y d6 sin peón e.",
             white: ["Preparar e4-e5 para abrir el centro.",
                     "Frenar la mayoría rival del flanco de dama con a2-a4.",
                     "Presionar el peón d6."],
             black: ["Avanzar la mayoría del flanco de dama con b7-b5.",
                     "Presionar e4 con el alfil de g7 y la columna e semiabierta.",
                     "Bloquear e5 con una pieza."]),
         Raw(rule: "{W} has d5 and e4 with no c-pawn; {B} has c5 and d6 with no e-pawn.",
             white: ["Prepare e4-e5 to open the centre.",
                     "Slow the opponent's queenside majority with a2-a4.",
                     "Put pressure on the d6-pawn."],
             black: ["Advance the queenside majority with b7-b5.",
                     "Pressure e4 with the g7 bishop and the half-open e-file.",
                     "Blockade e5 with a piece."])),
        // 13 Benoni simétrica
        (Raw(rule: "{W} tienen c4 y d5 sin peón e; {B} tienen c5 y d6 sin peón e.",
             white: ["Instalar un caballo en e4 y presionar d6.",
                     "Ganar espacio en el flanco de rey con f2-f4."],
             black: ["Usar e5 como casilla para un caballo.",
                     "Preparar b7-b5 para minar c4."]),
         Raw(rule: "{W} has c4 and d5 with no e-pawn; {B} has c5 and d6 with no e-pawn.",
             white: ["Post a knight on e4 and pressure d6.",
                     "Gain kingside space with f2-f4."],
             black: ["Use e5 as a knight outpost.",
                     "Prepare b7-b5 to undermine c4."])),
        // 14 India de Rey Tipo I
        (Raw(rule: "{W} tienen d5 y e4 sin peón c; {B} tienen d6 y e5 sin peón c.",
             white: ["Jugar en el flanco de dama por la columna c semiabierta.",
                     "Llevar un caballo a c4 y presionar d6."],
             black: ["Romper con f7-f5 y atacar en el flanco de rey.",
                     "Usar c5 como casilla para un caballo."]),
         Raw(rule: "{W} has d5 and e4 with no c-pawn; {B} has d6 and e5 with no c-pawn.",
             white: ["Play on the queenside along the half-open c-file.",
                     "Bring a knight to c4 and pressure d6."],
             black: ["Break with f7-f5 and attack on the kingside.",
                     "Use c5 as a knight outpost."])),
        // 15 India de Rey Tipo II
        (Raw(rule: "{W} tienen c4, d5 y e4; {B} tienen c5, d6 y e5.",
             white: ["Preparar la ruptura b2-b4 en el flanco de dama.",
                     "Contener el ataque rival en el flanco de rey, con f2-f3 si hace falta."],
             black: ["Atacar en el flanco de rey con f7-f5 y g6-g5.",
                     "Preparar b7-b5 para abrir también el flanco de dama."]),
         Raw(rule: "{W} has c4, d5 and e4; {B} has c5, d6 and e5.",
             white: ["Prepare the b2-b4 break on the queenside.",
                     "Contain the opponent's kingside attack, with f2-f3 if needed."],
             black: ["Attack on the kingside with f7-f5 and g6-g5.",
                     "Prepare b7-b5 to open the queenside as well."])),
        // 16 India de Rey Tipo III
        (Raw(rule: "{W} tienen c4, d5 y e4; {B} tienen c7, d6 y e5.",
             white: ["Avanzar c4-c5 para abrir la columna c y atacar c7.",
                     "Ganar espacio en el flanco de dama con b2-b4."],
             black: ["Atacar al rey con f7-f5-f4 y g6-g5.",
                     "Llevar piezas al flanco de rey antes de que el rival abra el flanco de dama."]),
         Raw(rule: "{W} has c4, d5 and e4; {B} has c7, d6 and e5.",
             white: ["Push c4-c5 to open the c-file and attack c7.",
                     "Gain queenside space with b2-b4."],
             black: ["Attack the king with f7-f5-f4 and g6-g5.",
                     "Bring pieces to the kingside before the opponent opens the queenside."])),
        // 17 India de Rey abierta
        (Raw(rule: "{W} tienen c4 y e4 sin peón d; {B} tienen d6 y el peón c en c6 o c7, sin peón e.",
             white: ["Presionar el peón d6 por la columna d.",
                     "Ganar espacio con f2-f4 y e4-e5 cuando sea seguro."],
             black: ["Preparar d6-d5 para liberar el juego.",
                     "Presionar c4 y e4 con el alfil de g7 y las demás piezas.",
                     "Usar e5 como casilla para un caballo."]),
         Raw(rule: "{W} has c4 and e4 with no d-pawn; {B} has d6 and the c-pawn on c6 or c7, with no e-pawn.",
             white: ["Pressure the d6-pawn down the d-file.",
                     "Gain space with f2-f4 and e4-e5 when it is safe."],
             black: ["Prepare d6-d5 to free the game.",
                     "Pressure c4 and e4 with the g7 bishop and the other pieces.",
                     "Use e5 as a knight outpost."])),
        // 18 Complejo India de Rey
        (Raw(rule: "{W} tienen c4, d4 y e4; {B} tienen d6, e5 y el peón c en c6 o c7.",
             white: ["Elegir el momento de cerrar con d4-d5 o de cambiar en e5.",
                     "Ganar espacio en el flanco de dama."],
             black: ["Mantener la tensión en e5 hasta que un cambio convenga.",
                     "Preparar f7-f5 o el juego en el flanco de dama según cómo se cierre el centro."]),
         Raw(rule: "{W} has c4, d4 and e4; {B} has d6, e5 and the c-pawn on c6 or c7.",
             white: ["Choose the moment to close with d4-d5 or to exchange on e5.",
                     "Gain space on the queenside."],
             black: ["Keep the tension on e5 until an exchange is favourable.",
                     "Prepare f7-f5 or queenside play depending on how the centre closes."])),
        // 19 Francesa Tipo I
        (Raw(rule: "{W} tienen d4 sin peón e; {B} tienen d5 y e6 sin peón f.",
             white: ["Ocupar e5 con un caballo.",
                     "Presionar el peón e6 por la columna e."],
             black: ["Atacar por la columna f semiabierta.",
                     "Preparar e6-e5 para quitarse la debilidad de e6.",
                     "Activar o cambiar el alfil de c8."]),
         Raw(rule: "{W} has d4 with no e-pawn; {B} has d5 and e6 with no f-pawn.",
             white: ["Occupy e5 with a knight.",
                     "Pressure the e6-pawn down the e-file."],
             black: ["Attack along the half-open f-file.",
                     "Prepare e6-e5 to get rid of the e6 weakness.",
                     "Activate or trade the c8 bishop."])),
        // 20 Francesa Tipo II
        (Raw(rule: "{W} tienen e5 y el peón c en c2 o c3, sin peón d; {B} tienen d5 y e6 sin peón c.",
             white: ["Mantener e5 y usar d4 como casilla para las piezas.",
                     "Atacar en el flanco de rey aprovechando el espacio."],
             black: ["Atacar e5 con f7-f6 y con las piezas.",
                     "Ocupar la columna c semiabierta y presionar c3."]),
         Raw(rule: "{W} has e5 and the c-pawn on c2 or c3 with no d-pawn; {B} has d5 and e6 with no c-pawn.",
             white: ["Hold e5 and use d4 as a square for the pieces.",
                     "Attack on the kingside using the extra space."],
             black: ["Attack e5 with f7-f6 and with the pieces.",
                     "Take the half-open c-file and pressure c3."])),
        // 21 Francesa Tipo III
        (Raw(rule: "{W} tienen la cadena d4-e5; {B} tienen la cadena d5-e6.",
             white: ["Atacar en el flanco de rey con f2-f4-f5.",
                     "Mantener firme d4, la base de la cadena."],
             black: ["Atacar la base d4 con c7-c5.",
                     "Romper con f7-f6 contra e5.",
                     "Buscar el cambio del alfil de c8, que tiene poco juego."]),
         Raw(rule: "{W} has the d4-e5 chain; {B} has the d5-e6 chain.",
             white: ["Attack on the kingside with f2-f4-f5.",
                     "Keep d4, the base of the chain, firmly protected."],
             black: ["Strike at the base d4 with c7-c5.",
                     "Break with f7-f6 against e5.",
                     "Look to trade the passive c8 bishop."])),
        // 22 3–3 contra 4–2
        (Raw(rule: "{W} tienen peones en las columnas a, b, c, f, g y h (sin d ni e); {B} en a, b, e, f, g y h (sin c ni d).",
             white: ["Avanzar la mayoría del flanco de dama para crear un peón pasado.",
                     "Llevar pronto el rey al centro en el final."],
             black: ["Avanzar la mayoría central con e6-e5 y f7-f5.",
                     "Frenar la mayoría rival del flanco de dama con las piezas."]),
         Raw(rule: "{W} has pawns on the a, b, c, f, g and h files (no d or e); {B} on a, b, e, f, g and h (no c or d).",
             white: ["Advance the queenside majority to create a passed pawn.",
                     "Bring the king to the centre early in the endgame."],
             black: ["Advance the central majority with e6-e5 and f7-f5.",
                     "Hold back the opponent's queenside majority with the pieces."])),
        // 23 Panov
        (Raw(rule: "{W} tienen c5 y d4 sin peón e; {B} tienen d5 y el peón e en e6 o e7, sin peón c.",
             white: ["Avanzar b2-b4-b5 con la mayoría del flanco de dama.",
                     "Controlar e5 para frenar la ruptura rival."],
             black: ["Romper la cadena con b7-b6 o con e6-e5.",
                     "Atacar d4, la base de la cadena."]),
         Raw(rule: "{W} has c5 and d4 with no e-pawn; {B} has d5 and the e-pawn on e6 or e7, with no c-pawn.",
             white: ["Push b2-b4-b5 with the queenside majority.",
                     "Control e5 to stop the opponent's central break."],
             black: ["Break the chain with b7-b6 or with e6-e5.",
                     "Attack d4, the base of the chain."])),
        // 24 Dragón
        (Raw(rule: "{W} tienen e4 sin peón d; {B} tienen d6 y g6 sin peón c.",
             white: ["Atacar al rey rival con h2-h4-h5 y abrir la columna h.",
                     "Controlar d5 y cambiar el alfil de g7."],
             black: ["Atacar por la columna c semiabierta, incluso con un sacrificio de calidad en c3.",
                     "Aprovechar el alfil de g7 en la gran diagonal."]),
         Raw(rule: "{W} has e4 with no d-pawn; {B} has d6 and g6 with no c-pawn.",
             white: ["Attack the enemy king with h2-h4-h5 and open the h-file.",
                     "Control d5 and trade off the g7 bishop."],
             black: ["Attack down the half-open c-file, even with an exchange sacrifice on c3.",
                     "Make use of the g7 bishop on the long diagonal."])),
        // 25 Scheveningen
        (Raw(rule: "{W} tienen e4 y el peón c en c2 o c3, sin peón d; {B} tienen d6 y e6 sin peón c.",
             white: ["Atacar en el flanco de rey con g2-g4-g5 o con f2-f4 y e4-e5.",
                     "Presionar d6 si el rival abre el centro antes de tiempo."],
             black: ["Preparar las rupturas d6-d5 o e6-e5.",
                     "Contraatacar en el flanco de dama con b7-b5 y la columna c."]),
         Raw(rule: "{W} has e4 and the c-pawn on c2 or c3 with no d-pawn; {B} has d6 and e6 with no c-pawn.",
             white: ["Attack on the kingside with g2-g4-g5 or with f2-f4 and e4-e5.",
                     "Pressure d6 if the opponent opens the centre too early."],
             black: ["Prepare the d6-d5 or e6-e5 breaks.",
                     "Counterattack on the queenside with b7-b5 and the c-file."])),
        // 26 Benko
        (Raw(rule: "{W} tienen d5 y e4 sin peón c; {B} tienen c5, d6 y e7 sin peones a ni b.",
             white: ["Consolidar y llevar al final el peón de más del flanco de dama.",
                     "Defender a2 y b2 de la presión por las columnas a y b."],
             black: ["Presionar a2 y b2 con las torres en las columnas a y b.",
                     "Aprovechar el alfil de g7 en la gran diagonal.",
                     "Mantener la presión sin prisa: la compensación es duradera."]),
         Raw(rule: "{W} has d5 and e4 with no c-pawn; {B} has c5, d6 and e7 with no a- or b-pawns.",
             white: ["Consolidate and take the extra queenside pawn into the endgame.",
                     "Defend a2 and b2 against the pressure on the a- and b-files."],
             black: ["Pressure a2 and b2 with the rooks on the a- and b-files.",
                     "Make use of the g7 bishop on the long diagonal.",
                     "Keep up the pressure patiently: the compensation is long-lasting."])),
        // 27 Ruy López cerrada
        (Raw(rule: "{W} tienen c3, d5 y e4; {B} tienen d6, e5 y el peón c en c4 o c5.",
             white: ["Llevar piezas al flanco de rey (por ejemplo, el caballo por d2, f1 y g3) y preparar f2-f4 o g2-g4.",
                     "Abrir el flanco de dama con a2-a4 y b2-b4 cuando convenga."],
             black: ["Ganar espacio en el flanco de dama con a7-a5 y b5-b4.",
                     "Preparar f7-f5 para contraatacar en el flanco de rey."]),
         Raw(rule: "{W} has c3, d5 and e4; {B} has d6, e5 and the c-pawn on c4 or c5.",
             white: ["Bring pieces to the kingside (for example the knight via d2, f1 and g3) and prepare f2-f4 or g2-g4.",
                     "Open the queenside with a2-a4 and b2-b4 at the right moment."],
             black: ["Gain queenside space with a7-a5 and b5-b4.",
                     "Prepare f7-f5 to counter on the kingside."])),
        // 28 Formación López
        (Raw(rule: "{W} tienen c3, d4 y e4; {B} tienen d6, e5 y el peón c en c5, c6 o c7.",
             white: ["Mantener la tensión y elegir el momento de cerrar con d4-d5.",
                     "Mejorar las piezas con el caballo por d2, f1 y g3 antes de abrir el juego."],
             black: ["Sostener e5 y presionar d4 con las piezas y, si está en c5, con el peón c.",
                     "Cambiar en d4 si las piezas propias quedan activas, aunque d6 quede algo débil."]),
         Raw(rule: "{W} has c3, d4 and e4; {B} has d6, e5 and the c-pawn on c5, c6 or c7.",
             white: ["Keep the tension and choose the moment to close with d4-d5.",
                     "Improve the pieces with the knight via d2, f1 and g3 before opening the game."],
             black: ["Hold e5 and pressure d4 with the pieces and, if it is on c5, with the c-pawn.",
                     "Exchange on d4 if the pieces end up active, even if d6 is left a little weak."])),
        // G Mayoría en el flanco de dama
        (Raw(rule: "Ningún bando tiene peón d y {W} tienen más peones que {B} en las columnas a, b y c.",
             white: ["Avanzar la mayoría para crear un peón pasado.",
                     "Simplificar hacia el final, donde la mayoría pesa más."],
             black: ["Usar la mayoría del centro o del flanco de rey para atacar.",
                     "Frenar los peones del flanco de dama con el rey o con piezas."]),
         Raw(rule: "Neither side has a d-pawn and {W} has more pawns than {B} on the a, b and c files.",
             white: ["Advance the majority to create a passed pawn.",
                     "Simplify towards the endgame, where the majority counts for more."],
             black: ["Use the central or kingside majority to attack.",
                     "Hold back the queenside pawns with the king or with pieces."])),
        // G Peones c doblados (Nimzo-Sämisch)
        (Raw(rule: "{W} tienen peones doblados en c3 y c4, más un peón en d4.",
             white: ["Aprovechar la pareja de alfiles y el centro para atacar.",
                     "Preparar f2-f3 y e3-e4 para ganar el centro."],
             black: ["Bloquear la posición y atacar el peón c4.",
                     "Cerrar el centro con c7-c5 y d7-d6 para frenar a los alfiles."]),
         Raw(rule: "{W} has doubled pawns on c3 and c4, plus a pawn on d4.",
             white: ["Use the bishop pair and the centre to attack.",
                     "Prepare f2-f3 and e3-e4 to win the centre."],
             black: ["Keep the position closed and attack the c4-pawn.",
                     "Lock the centre with c7-c5 and d7-d6 to blunt the bishops."])),
        // G Berlinesa
        (Raw(rule: "{W} tienen e5 sin peón d; {B} tienen peones doblados en c6 y c7 sin peón d.",
             white: ["Usar la mayoría del flanco de rey para crear un peón pasado.",
                     "Llevar el rey hacia el centro y mantener las piezas activas."],
             black: ["Aprovechar la pareja de alfiles.",
                     "Frenar la mayoría rival del flanco de rey con peones y piezas."]),
         Raw(rule: "{W} has e5 with no d-pawn; {B} has doubled pawns on c6 and c7 with no d-pawn.",
             white: ["Use the kingside majority to create a passed pawn.",
                     "Bring the king towards the centre and keep the pieces active."],
             black: ["Make use of the bishop pair.",
                     "Hold back the opponent's kingside majority with pawns and pieces."])),
        // G Cadena de la Londres/Colle
        (Raw(rule: "{W} tienen la cadena c3-d4-e3 (a veces con f4) contra el peón d5 de {B}.",
             white: ["Llevar un caballo a e5 y atacar en el flanco de rey.",
                     "Preparar e3-e4 para abrir el centro."],
             black: ["Romper con c7-c5 contra d4.",
                     "Preparar e7-e5 para liberar el juego."]),
         Raw(rule: "{W} has the c3-d4-e3 chain (sometimes with f4) against {B}'s d5-pawn.",
             white: ["Bring a knight to e5 and attack on the kingside.",
                     "Prepare e3-e4 to open the centre."],
             black: ["Break with c7-c5 against d4.",
                     "Prepare e7-e5 to free the game."])),
    ]
    // swiftlint:enable line_length
}
