import Foundation

class Environment {
    let enclosing: Environment?
    var globalValues: [String: LoxValue] = [:]
    var localValues: [LoxValue] = []

    private var root: Environment {
        var env = self
        while let e = env.enclosing {
            env = e
        }
        return env
    }

    init() {
        enclosing = nil
    }

    init(enclosing: Environment) {
        self.enclosing = enclosing
    }

    func get(_ name: Token) throws -> LoxValue {
        if let value = root.globalValues[name.lexeme] {
            return value
        } else {
            throw RuntimeError(token: name, message: "Undefined variable \(name.lexeme). (get)")
        }
    }

    func getAt(_ depth: Int, _ index: Int) -> LoxValue {
        return ancestor(depth).localValues[index]
    }

    func assignAt(_ distance: Int, _ index: Int, _ value: LoxValue) {
        return ancestor(distance).localValues[index] = value
    }

    private func ancestor(_ distance: Int) -> Environment {
        var environment = self
        for _ in 0 ..< distance {
            environment = environment.enclosing!
        }
        return environment
    }

    func define(_ name: String, _ value: LoxValue) {
        if enclosing == nil {
            defineGlobal(name, value)
        } else {
            defineLocal(value)
        }
    }

    func defineGlobal(_ name: String, _ value: LoxValue) {
        globalValues[name] = value
    }

    func defineLocal(_ value: LoxValue) {
        localValues.append(value)
    }

    func assign(_ name: Token, _ value: LoxValue) throws {
        if let _ = root.globalValues[name.lexeme] {
            root.globalValues[name.lexeme] = value
        } else {
            throw RuntimeError(token: name, message: "Undefined variable \(name.lexeme) (assign).")
        }
    }
}
