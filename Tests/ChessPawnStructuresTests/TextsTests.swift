import Foundation
import Testing
@testable import ChessPawnStructures

@Suite("Textos del catálogo")
struct TextsTests {
    @Test("Las 32 estructuras tienen regla y 2–3 planes por bando en los dos idiomas",
          arguments: StructureKind.allCases)
    func complete(kind: StructureKind) {
        for language in StructureLanguage.allCases {
            for reversed in [false, true] {
                let text = StructureID(kind, reversed: reversed).text(language)
                #expect(!text.rule.isEmpty)
                #expect(text.rule.first!.isUppercase, "\(text.rule)")
                for plans in [text.whitePlans, text.blackPlans] {
                    #expect((2 ... 3).contains(plans.count), "\(kind) \(language)")
                    for plan in plans {
                        #expect(plan.first!.isUppercase && plan.hasSuffix("."), "\(plan)")
                    }
                }
                for line in [text.rule] + text.whitePlans + text.blackPlans {
                    #expect(!line.contains("{") && !line.contains("}"), "\(line)")
                }
            }
        }
    }

    @Test("La regla escrita nombra todas las casillas que exige la regla del catálogo",
          arguments: StructureKind.allCases)
    func ruleMentionsSquares(kind: StructureKind) {
        guard case let .pattern(p) = kind.definition.condition else { return }
        let squares = Square.names(p.white.required | p.white.alternative0 | p.white.alternative1
            | p.black.required | p.black.alternative0 | p.black.alternative1)
        for language in StructureLanguage.allCases {
            let rule = kind.text(language).rule
            for square in squares {
                #expect(rule.contains(square), "\(kind) \(language): falta \(square) en «\(rule)»")
            }
        }
    }

    @Test("Con colores invertidos se cambian bandos, casillas y planes")
    func reversed() {
        let book = StructureKind.isolatedQueenPawn.text(.spanish)
        let rev = StructureID(.isolatedQueenPawn, reversed: true).text(.spanish)
        #expect(book.rule == "Las blancas tienen un peón aislado en d4, sin peones c ni e, y las negras no tienen peones c ni d.")
        #expect(rev.rule == "Las negras tienen un peón aislado en d5, sin peones c ni e, y las blancas no tienen peones c ni d.")
        #expect(rev.name == "Peón aislado (IQP) (colores invertidos)")
        #expect(rev.whitePlans.first == "Bloquear el peón en d4, mejor con un caballo.")
        #expect(rev.blackPlans[1] == "Preparar la ruptura d5-d4 para abrir el centro cuando las piezas estén activas.")

        let en = StructureID(.carlsbad, reversed: true).text(.english)
        #expect(en.name == "Carlsbad (reversed colors)")
        #expect(en.rule.hasPrefix("Black has d5 and the e-pawn on e7 or e6"))
        #expect(en.blackPlans.first == "Minority attack: push b7-b5-b4 to leave a weak c-pawn.")
    }

    @Test("Reflejo de casillas: solo pares columna-fila, involución")
    func flip() {
        #expect(StructureTexts.flipSquares("Cd2-f1-g3, h2-h4-h5") == "Cd7-f8-g6, h7-h5-h4")
        #expect(StructureTexts.flipSquares("3–3 contra 4–2, columna c, a10") == "3–3 contra 4–2, columna c, a10")
        let text = "Push b2-b4-b5 and Nd2-f1-g3."
        #expect(StructureTexts.flipSquares(StructureTexts.flipSquares(text)) == text)
    }

    @Test("summary(locale:) devuelve la estructura principal en el idioma del locale")
    func summary() {
        let iqp = Fixtures.structure(Fixtures.all[0].fen)
        let es = iqp.summary(locale: Locale(identifier: "es_ES"))
        #expect(es?.structure == StructureID(.isolatedQueenPawn))
        #expect(es?.text.name == "Peón aislado (IQP)")
        let en = iqp.summary(locale: Locale(identifier: "en_US"))
        #expect(en?.text.name == "Isolated queen's pawn")
        #expect(en?.text.rule.hasPrefix("White has an isolated pawn on d4") == true)
        #expect(iqp.summary(locale: Locale(identifier: "fr_FR"))?.text.rule == en?.text.rule)
        let reversed = iqp.colorsReversed.summary(.spanish)
        #expect(reversed?.structure == StructureID(.isolatedQueenPawn, reversed: true))
        #expect(PawnStructure(white: 0, black: 0).summary(.english) == nil)
    }

    @Test("Planes con formato para la app")
    func formatted() {
        let text = StructureKind.panov.text(.spanish)
        let lines = text.formattedPlans(.spanish).split(separator: "\n", omittingEmptySubsequences: false)
        #expect(lines.first == "Blancas:")
        #expect(lines.contains("Negras:"))
        #expect(lines.filter { $0.hasPrefix("• ") }.count == text.whitePlans.count + text.blackPlans.count)
    }
}
