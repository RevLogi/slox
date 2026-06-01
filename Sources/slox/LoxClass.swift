import Foundation

class LoxClass: LoxInstance, LoxCallable {
    let name: String
    let methods: [String: LoxFunction]
    let superClass: LoxClass?

    init(_ name: String, _ superClass: LoxClass?, _ methods: [String: LoxFunction], _ klass: LoxClass?) {
        self.superClass = superClass
        self.name = name
        self.methods = methods
        super.init(klass)
    }

    func findMethod(_ name: String) -> LoxFunction? {
        if let method = methods[name] {
            return method
        }
        if let superClass = superClass {
            return superClass.findMethod(name)
        }
        return nil
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

    override nonisolated var description: String {
        return name
    }
}
