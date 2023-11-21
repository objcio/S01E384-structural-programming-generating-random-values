import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest
import Structural
import StructuralMacros

let testMacros: [String: Macro.Type] = [
    "Structural": StructuralMacro.self,
]

final class StructuralTests: XCTestCase {
    func testMacro() throws {
        assertMacroExpansion(
            """
            @Structural
            struct Test {
                var foo: String
                var bar: Int
            }
            """,
            expandedSource: """
            struct Test {
                var foo: String
                var bar: Int

                typealias Structure = Struct<List<Property<String>, List<Property<Int>, Empty>>>

                static var structure: Structure {
                    Struct(name: "Test", properties: List(head: Property(name: "foo"), tail: List(head: Property(name: "bar"), tail: Empty())))
                }

                var to: Structure.Value {
                    (foo, (bar, ()))
                }

                static func from(_ s: Structure.Value) -> Self {
                    .init(foo: s.0, bar: s.1.0)
                }
            }

            extension Test: Structural {
            }
            """,
            macros: testMacros
        )
    }

    func testEnumMacro() throws {
        assertMacroExpansion(
            """
            @Structural enum Test {
                case foo
                case bar(String, count: Int)
            }
            """,
            expandedSource: """
            enum Test {
                case foo
                case bar(String, count: Int)

                typealias Structure = Enum<Choice<Empty, Choice<List<AssociatedValue<String>, List<AssociatedValue<Int>, Empty>>, Nothing>>>

                static var structure: Structure {
                    Enum(name: "Test", cases: Choice(first: Empty(), second: Choice(first: List(head: AssociatedValue(name: nil), tail: List(head: AssociatedValue(name: "count"), tail: Empty())), second: Nothing())))
                }

                var to: Structure.Value {
                    switch self {

                    case let .foo:
                        .first(())
                    case let .bar(x0, x1):
                        .second(.first((x0, (x1, ()))))
                    }
                }

                static func from(_ s: Structure.Value) -> Self {
                    switch s {
                    case .first(let f):
                        return .foo
                    case .second(let s):
                        switch s {
                        case .first(let f):
                            return .bar(f.0, count: f.1.0)
                        case .second(let s):
                            switch s {
                            }
                        }
                    }
                }
            }

            extension Test: Structural {
            }
            """,
            macros: testMacros
        )
    }

}
