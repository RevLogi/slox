import Foundation

@MainActor
class LoxFunction: LoxCallable {
    /// lambda can be no name
    let name: Token?
    /// Let nil to represent getter and [] to represent no args
    let params: [Token]?

    let body: [Stmt]
    let closure: Environment
    let isInitializer: Bool

    var arity: Int {
        return params?.count ?? 0
    }

    // init params just keep in line with attributes
    init(_ name: Token?, _ params: [Token]?, _ body: [Stmt], closure: Environment, isInitializer: Bool) {
        self.name = name
        self.params = params
        self.body = body
        self.closure = closure
        self.isInitializer = isInitializer
    }

    // Allow to have `this` in the class field
    func bind(_ instance: LoxInstance) -> LoxFunction {
        let environment = Environment(enclosing: closure)
        environment.define("this", .instance(instance))
        return LoxFunction(name!, params, body, closure: environment, isInitializer: isInitializer)
    }

    func call(interpreter: Interpreter, _ arguments: [LoxValue]) throws -> LoxValue {
        let environment = Environment(enclosing: closure)
        if let count = params?.count {
            for i in 0 ..< count {
                environment.define(params![i].lexeme, arguments[i])
            }
        }

        do {
            try interpreter.executeBlock(body, environment)
        } catch let res as Return {
            if isInitializer {
                // init function always be the first in its envioronment
                // init function doesn't return value
                return closure.getAt(0, 0)
            }
            return res.value
        }

        if isInitializer {
            return closure.getAt(0, 0)
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
