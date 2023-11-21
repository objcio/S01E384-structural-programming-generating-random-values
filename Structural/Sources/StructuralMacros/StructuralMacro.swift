import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

struct StructuralError: Error {
    var message: String
}

typealias EnumCase = (identifier: TokenSyntax, parameters: [(identifier: TokenSyntax?, type: TypeSyntax)])

extension DeclSyntax {
    var asStoredProperty: (TokenSyntax, TypeSyntax)? {
        get throws {
            guard let v = self.as(VariableDeclSyntax.self) else { return nil }
            guard v.bindings.count == 1 else { throw StructuralError(message: "Multiple bindings not supported.") }
            let binding = v.bindings.first!
            guard binding.accessorBlock == nil else { return nil }
            guard let id = binding.pattern.as(IdentifierPatternSyntax.self) else { throw StructuralError(message: "Only Identifier patterns supported.")
            }
            guard let type = binding.typeAnnotation?.type else { throw StructuralError(message: "Only properties with explicit types supported.")}
            return (id.identifier, type)
        }
    }

    var asEnumCase: EnumCase? {
        get throws {
            guard let v = self.as(EnumCaseDeclSyntax.self) else { return nil }
            guard v.elements.count == 1 else { throw StructuralError(message: "Multiple cases not supported.") }
            let case_ = v.elements.first!
            let params = case_.parameterClause?.parameters.map { param in
                (param.firstName, param.type)
            }
            return (case_.name, params ?? [])
        }
    }
}


public struct StructuralMacro: MemberMacro, ExtensionMacro {
    public static func expansion(of node: AttributeSyntax, attachedTo declaration: some DeclGroupSyntax, providingExtensionsOf type: some TypeSyntaxProtocol, conformingTo protocols: [TypeSyntax], in context: some MacroExpansionContext) throws -> [ExtensionDeclSyntax] {
        let decl: DeclSyntax = "extension \(type.trimmed): Structural {}"
        return [
            decl.as(ExtensionDeclSyntax.self)!
        ]
    }

    public static func expansion(of node: AttributeSyntax, providingMembersOf declaration: some DeclGroupSyntax, in context: some MacroExpansionContext) throws -> [DeclSyntax] {
        if let structDecl = declaration.as(StructDeclSyntax.self) {
            try structExpansion(of: node, providingMembersOf: structDecl, in: context)
        } else if let enumDecl = declaration.as(EnumDeclSyntax.self) {
            try enumExpansion(of: node, providingMembersOf: enumDecl, in: context)
        } else {
            throw StructuralError(message: "Only works on structs and enums")
        }
    }

    public static func structExpansion(of node: AttributeSyntax, providingMembersOf declaration: StructDeclSyntax, in context: some MacroExpansionContext) throws -> [DeclSyntax] {
        let storedProperties = try declaration.memberBlock.members.compactMap { item in
            try item.decl.asStoredProperty
        }
        let typeDecl: DeclSyntax = storedProperties.reversed().reduce("Empty", { result, prop in
            "List<Property<\(prop.1)>, \(result)>"
        })
        let propsDecl: DeclSyntax = storedProperties.reversed().reduce("()", { result, prop in
            "(\(prop.0), \(result))"
        })
        let propsStructDecl: DeclSyntax = storedProperties.reversed().reduce("Empty()", { result, prop in
            "List(head: Property(name: \(literal: prop.0.text)), tail: \(result))"
        })
        let fromDecl = zip(storedProperties.indices, storedProperties).map { (idx, prop) in
            let tails = Array(repeating: ".1", count: idx).joined()
            return "\(prop.0): s\(tails).0"
        }.joined(separator: ", ")
        return [
            "typealias Structure = Struct<\(typeDecl)>",
            """
            static var structure: Structure {
                Struct(name: \(literal: declaration.name.text), properties: \(propsStructDecl))
            }
            """,
            """
            var to: Structure.Value {
                \(propsDecl)
            }
            """,
            """
            static func from(_ s: Structure.Value) -> Self {
                .init(\(raw: fromDecl))
            }
            """
        ]
    }

    public static func enumExpansion(of node: AttributeSyntax, providingMembersOf declaration: EnumDeclSyntax, in context: some MacroExpansionContext) throws -> [DeclSyntax] {
        let cases = try declaration.memberBlock.members.compactMap { item in
            try item.decl.asEnumCase
        }
        let typeDecl: DeclSyntax = cases.reversed().reduce("Nothing") { result, case_ in
            let paramList: DeclSyntax = case_.parameters.reversed().reduce("Empty", { result, param in
                "List<AssociatedValue<\(param.type)>, \(result)>"
            })
            return "Choice<\(paramList), \(result)>"
        }
        let structureCasesDecl: DeclSyntax = cases.reversed().reduce("Nothing()") { result, case_ in
            let paramList: DeclSyntax = case_.parameters.reversed().reduce("Empty()", { result, param in
                let name: DeclSyntax = param.identifier.map { "\(literal: $0.text)" } ?? "nil"
                return "List(head: AssociatedValue(name: \(name)), tail: \(result))"
            })
            return "Choice(first: \(paramList), second: \(result))"
        }
        let casesDecl: [DeclSyntax] = zip(cases.indices, cases).map { idx, case_ in
            let bindings = (0..<case_.parameters.count).map { "x\($0)" }
            let list: DeclSyntax = bindings.reversed().reduce("()") { result, binding in
                "(\(raw: binding), \(result))"
            }
            let choice: DeclSyntax = Array(repeating: (), count: idx).reduce(".first(\(list))") { result, _ in
                ".second(\(result))"
            }
            let commaSeparatedBindings: DeclSyntax = bindings.isEmpty ? "" : "(\(raw: bindings.joined(separator: ", ")))"
            return """
                    case let .\(case_.identifier)\(commaSeparatedBindings):
                        \(choice)
                    """
        }
        let joinedCasesDecl: DeclSyntax = casesDecl.reduce("") { result, cd in
            "\(result)\n\(cd)"
        }

        func fromDecl(remainder: [EnumCase]) -> DeclSyntax {
            guard let f = remainder.first else {
                return """
                        switch s {
                        }
                        """
            }
            let paramList = f.parameters.enumerated().map { idx, param in
                let prefix = "f" + Array(repeating: ".1", count: idx).joined() + ".0"
                return param.identifier.map { "\($0): \(prefix)" } ?? prefix
            }.joined(separator: ", ")
            return """
                    switch s {
                    case .first(let f):
                        return .\(raw: f.identifier)\(raw: paramList.isEmpty ? "" : "(\(paramList))")
                    case .second(let s):
                        \(fromDecl(remainder: Array(remainder.dropFirst())))
                    }
                    """
        }
        return [
            "typealias Structure = Enum<\(typeDecl)>",
            """
            static var structure: Structure {
                Enum(name: \(literal: declaration.name.text), cases: \(structureCasesDecl))
            }
            """,
            """
            var to: Structure.Value {
                switch self {
                \(joinedCasesDecl)
                }
            }
            """,
            """
            static func from(_ s: Structure.Value) -> Self {
                \(fromDecl(remainder: cases))
            }
            """
        ]
    }
}

@main
struct StructuralPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        StructuralMacro.self
    ]
}
