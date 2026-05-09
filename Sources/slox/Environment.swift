import Foundation

class Environment {
    let enclosing: Environment?
    var values: [String: LoxValue?] = [:]

    init() {
        enclosing = nil
    }

    init(enclosing: Environment) {
        self.enclosing = enclosing
    }

    func get(_ name: Token) throws -> LoxValue {
        if let value = values[name.lexeme] {
            if value == nil {
                throw RuntimeError(token: name, message: "Unitialized variable.")
            }
            return value!
        } else {
            if let enclosing = enclosing {
                return try enclosing.get(name)
            } else {
                throw RuntimeError(token: name, message: "Undefined variable \(name.lexeme).")
            }
        }
    }

    func define(_ name: String, _ value: LoxValue?) {
        values[name] = value
    }

    func assign(_ name: Token, _ value: LoxValue) throws {
        if let _ = values[name.lexeme] {
            values[name.lexeme] = value
        } else {
            if let enclosing = enclosing {
                return try enclosing.assign(name, value)
            } else {
                throw RuntimeError(token: name, message: "Undefined variable \(name.lexeme).")
            }
        }
    }
}
