import Foundation

@MainActor
class LoxFunction: LoxCallable {
    let name: Token?
    let params: [Token]
    let body: [Stmt]
    let closure: Environment

    var arity: Int {
        return params.count
    }

    init(_ name: Token, _ params: [Token], _ body: [Stmt], closure: Environment) {
        self.name = name
        self.params = params
        self.body = body
        self.closure = closure
    }

    init(_ params: [Token], _ body: [Stmt], closure: Environment) {
        name = nil
        self.params = params
        self.body = body
        self.closure = closure
    }

    func call(interpreter: Interpreter, _ arguments: [LoxValue]) throws -> LoxValue {
        let environment = Environment(enclosing: closure)
        for i in 0 ..< params.count {
            environment.define(params[i].lexeme, arguments[i])
        }

        do {
            try interpreter.executeBlock(body, environment)
        } catch let res as Return {
            return res.value
        }

        return .nil
    }
}

extension LoxFunction: CustomStringConvertible {
    nonisolated var description: String {
        if let name = name {
            return "<fn \(name.lexeme) >"
        } else {
            return "<lambda>"
        }
    }
}
