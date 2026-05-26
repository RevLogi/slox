import Foundation

@MainActor
class LoxInstance {
    private var fields: [String: LoxValue] = [:]
    private let klass: LoxClass

    init(_ klass: LoxClass) {
        self.klass = klass
    }

    func get(_ name: Token) throws -> LoxValue {
        if fields.keys.contains(name.lexeme) {
            return fields[name.lexeme]!
        }

        if let method = klass.findMethod(name.lexeme) {
            return .callable(method.bind(self))
        }

        throw RuntimeError(token: name,
                           message: "Undefined property '\(name.lexeme)'.")
    }

    func set(_ name: Token, _ value: LoxValue) {
        fields[name.lexeme] = value
    }
}

extension LoxInstance: CustomStringConvertible {
    nonisolated var description: String {
        return klass.name + " instance"
    }
}
