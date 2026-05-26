import Foundation

class LoxClass: LoxCallable {
    let name: String
    let methods: [String: LoxFunction]

    init(_ name: String, _ methods: [String: LoxFunction]) {
        self.name = name
        self.methods = methods
    }

    func findMethod(_ name: String) -> LoxFunction? {
        return methods[name]
    }

    func call(interpreter: Interpreter, _ arguments: [LoxValue]) throws -> LoxValue {
        let instance = LoxInstance(self)
        if let initializer = findMethod("init") {
            _ = try initializer.bind(instance).call(interpreter: interpreter, arguments)
        }
        return .instance(instance)
    }

    var arity: Int {
        guard let initializer = findMethod("init") else {
            return 0
        }
        return initializer.arity
    }
}

extension LoxClass: CustomStringConvertible {
    nonisolated var description: String {
        return name
    }
}
