import Foundation

@MainActor
protocol LoxCallable {
    var arity: Int { get }
    func call(interpreter: Interpreter, _ arguments: [LoxValue]) throws -> LoxValue
}

struct NativeFunction: LoxCallable {
    let arity: Int
    let callable: (Interpreter, [LoxValue]) throws -> LoxValue

    func call(interpreter: Interpreter, _ arguments: [LoxValue]) throws -> LoxValue {
        return try callable(interpreter, arguments)
    }
}

extension NativeFunction: CustomStringConvertible {
    nonisolated var description: String {
        return "<native fn>"
    }
}
