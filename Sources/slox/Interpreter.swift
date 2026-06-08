import Foundation

@MainActor
class Interpreter {
    var environment = Environment()
    var locals: [UUID: (depth: Int, index: Int)] = [:]

    init() {
        // Prepare native function
        environment.define("clock", .callable(NativeFunction(arity: 0) { _, _ in .number(Date.timeIntervalSinceReferenceDate) }))
    }

    /// Recieve information from resolver
    /// Store place information for local variables
    func resolve(_ expr: Expr, _ depth: Int, _ index: Int) {
        switch expr {
        case let .variable(_, id),
             let .this(_, id),
             let .assign(_, _, id),
             let .super(_, _, id):
            locals[id] = (depth, index)

        default:
            break
        }
    }

    func lookupVariable(_ name: Token, _ id: UUID) throws -> LoxValue {
        let place = locals[id]
        if let (depth, index) = place {
            return environment.getAt(depth, index)
        } else {
            return try environment.get(name)
        }
    }

    func interpret(_ statements: [Stmt]) {
        do {
            for statement in statements {
                try execute(statement)
            }
        } catch let e as RuntimeError {
            Lox.runtimeError(e)
        } catch {
            print("Unknow error: \(error)")
        }
    }

    private func stringify(_ expr: LoxValue) -> String {
        switch expr {
        case .nil:
            return "nil"
        case let .number(num):
            return String(num)
        case let .boolean(bool):
            return String(bool)
        case let .string(str):
            return str
        case let .callable(callable):
            return String(describing: callable)
        case let .class(className):
            return String(describing: className)
        case let .instance(instance):
            return String(describing: instance)
        }
    }

    func execute(_ statement: Stmt) throws {
        switch statement {
        case let .class(name, superClassName, classInstanceMethods, classStaticMethods):
            var superClassVal: LoxValue? = nil
            var actualSuperClass: LoxClass? = nil
            if let superClassName = superClassName {
                superClassVal = try eval(superClassName)
                guard case let .class(extractedClass) = superClassVal else {
                    if case let .variable(name, _) = superClassName {
                        throw RuntimeError(token: name, message: "Superclass must be a class.")
                    }
                    throw RuntimeError(token: name, message: "Superclass must be a class.")
                }
                actualSuperClass = extractedClass
            }

            // Define then assign
            // Allow self-reference
            environment.define(name.lexeme, .nil)
            var instanceMethods: [String: LoxFunction] = [:]
            var staticMethods: [String: LoxFunction] = [:]

            let methodClosure: Environment
            if actualSuperClass != nil {
                let superEnv = Environment(enclosing: environment)
                superEnv.define("super", .class(actualSuperClass!))
                methodClosure = superEnv
            } else {
                methodClosure = environment
            }

            for case let .function(name, params, body) in classInstanceMethods {
                let function = LoxFunction(name, params, body, closure: methodClosure, isInitializer: name.lexeme == "init")
                instanceMethods[name.lexeme] = function
            }
            for case let .function(name, params, body) in classStaticMethods {
                let function = LoxFunction(name, params, body, closure: methodClosure, isInitializer: name.lexeme == "init")
                staticMethods[name.lexeme] = function
            }

            let metaClass = LoxClass("type", nil, staticMethods, nil)
            let klass = LoxClass(name.lexeme, actualSuperClass, instanceMethods, metaClass)

            try environment.assign(name, .class(klass))

        case let .print(expr):
            let value: LoxValue = try eval(expr)
            print(stringify(value))

        case let .expression(expr):
            let _: LoxValue = try eval(expr)

        case let .var(name, expression):
            if let expr = expression {
                let value = try eval(expr)
                environment.define(name.lexeme, value)
            } else {
                environment.define(name.lexeme, .nil)
            }

        case let .block(statements):
            try executeBlock(statements, Environment(enclosing: environment))

        case let .if(condition, thenBranch, elseBranch):
            if try isTruthy(eval(condition)) {
                try execute(thenBranch)
            } else {
                if let elseBranch = elseBranch {
                    try execute(elseBranch)
                }
            }

        case let .while(condition, body):
            while try isTruthy(eval(condition)) {
                do {
                    try execute(body)
                } catch ControlFlow.breakStatement {
                    break
                } catch ControlFlow.continueStatement {
                    continue
                }
            }

        case let .for(initializer, condition, increment, body):
            let forEnv = Environment(enclosing: environment)
            let prevEnv = environment
            environment = forEnv
            defer { environment = prevEnv }

            if let initializer = initializer {
                try execute(initializer)
            }
            while try isTruthy(eval(condition)) {
                do {
                    try execute(body)
                } catch ControlFlow.breakStatement {
                    break
                } catch ControlFlow.continueStatement {
                    if let increment = increment {
                        try execute(increment)
                    }
                    continue
                }
                if let increment = increment {
                    try execute(increment)
                }
            }

        case .break:
            throw ControlFlow.breakStatement

        case .continue:
            throw ControlFlow.continueStatement

        case let .function(name, params, body):
            let function = LoxFunction(name, params, body, closure: environment, isInitializer: false)
            environment.define(name.lexeme, .callable(function))

        case let .return(_, expr):
            var value: LoxValue = .nil
            if let expr = expr {
                value = try eval(expr)
            }
            throw Return(value: value)
        }
    }

    func executeBlock(_ statements: [Stmt?], _ environment: Environment) throws {
        let previous: Environment = self.environment
        defer {
            self.environment = previous
        }

        self.environment = environment
        for statement in statements {
            if let stmt = statement {
                try execute(stmt)
            }
        }
    }

    func eval(_ expr: Expr) throws -> LoxValue {
        switch expr {
        case let .super(keyword, methodName, id):
            let (depth, _) = locals[id]!
            let superClassVal = environment.getAt(depth, 0)
            guard case let .class(superClass) = superClassVal else {
                throw RuntimeError(token: keyword, message: "Superclass must be a class.")
            }
            // 'this' is always at depth-1, index 0
            let thisVal = environment.getAt(depth - 1, 0)
            guard case let .instance(instance) = thisVal else {
                throw RuntimeError(token: keyword, message: "Cannot find 'this' in super context.")
            }

            guard let method = superClass.findMethod(methodName.lexeme) else {
                throw RuntimeError(token: keyword, message: "Undefined property \(methodName.lexeme).")
            }

            // Handle getter methods
            if method.params == nil {
                return try method.bind(instance).call(interpreter: self, [])
            }
            return .callable(method.bind(instance))

        case let .set(object, name, value):
            let object = try eval(object)
            guard case let .instance(instance) = object else {
                throw RuntimeError(token: name,
                                   message: "Only instances have fields.")
            }
            let value = try eval(value)
            instance.set(name, value)
            return value

        case let .get(object, name):
            let object = try eval(object)
            if case let .instance(instance) = object {
                return try instance.get(name, interpreter: self)
            }
            // Allow using static method upon class
            if case let .class(klass) = object {
                return try klass.get(name, interpreter: self)
            }
            return .nil

        case let .this(keyword, id):
            return try lookupVariable(keyword, id)

        case let .assign(name, expr, id):
            let value = try eval(expr)
            let place = locals[id]
            if let (depth, index) = place {
                environment.assignAt(depth, index, value)
            } else {
                try environment.assign(name, value)
            }
            return value

        case let .logical(leftExpr, op, rightEpxr):
            let leftVal = try eval(leftExpr)
            if op.type == .or {
                if isTruthy(leftVal) {
                    return leftVal
                }
            } else {
                if !isTruthy(leftVal) {
                    return leftVal
                }
            }
            return try eval(rightEpxr)

        case let .literal(value):
            if let num = value as? Double {
                return .number(num)
            }
            if let str = value as? String {
                return .string(str)
            }
            if let bool = value as? Bool {
                return .boolean(bool)
            }
            return .nil

        case let .grouping(expression): return try eval(expression)

        case let .unary(op, expr):
            let expr: LoxValue = try eval(expr)
            switch op.type {
            case .bang:
                return .boolean(!isTruthy(expr))
            case .minus:
                if case let .number(num) = expr {
                    return .number(-num)
                } else {
                    throw RuntimeError(token: op, message: "Operand must be a number.")
                }
            default: return .nil
            }

        case let .binary(left, op, right):
            let left: LoxValue = try eval(left)
            let right: LoxValue = try eval(right)
            switch op.type {
            case .minus:
                return try evaluateMath(left, right, op) { $0 - $1 }
            case .slash:
                return try evaluateMath(left, right, op) {
                    if $1 == 0 {
                        throw RuntimeError(token: op, message: "Division by zero")
                    }
                    return $0 / $1
                }
            case .star:
                return try evaluateMath(left, right, op) { $0 * $1 }
            case .plus:
                if case let .number(l) = left, case let .number(r) = right {
                    return .number(l + r)
                }
                if case let .string(l) = left, case let .string(r) = right {
                    return .string(l + r)
                }
                if case let .string(l) = left, case let .number(r) = right {
                    return .string(l + String(r))
                }
                if case let .number(l) = left, case let .string(r) = right {
                    return .string(String(l) + r)
                }
                throw RuntimeError(token: op, message: "Operands must be numbers or strings.")
            case .greater:
                return try evaluateComparison(left, right, op) { $0 > $1 }
            case .greater_equal:
                return try evaluateComparison(left, right, op) { $0 >= $1 }
            case .less:
                return try evaluateComparison(left, right, op) { $0 < $1 }
            case .less_equal:
                return try evaluateComparison(left, right, op) { $0 <= $1 }
            case .bang_equal:
                return .boolean(!isEqual(left, right))
            case .equal_equal:
                return .boolean(isEqual(left, right))
            case .comma:
                return right
            default: return .nil
            }

        case let .ternary(condition, then_brach, else_brach):
            var expr: LoxValue
            let condition: LoxValue = try eval(condition)
            if isTruthy(condition) {
                expr = try eval(then_brach)
            } else {
                expr = try eval(else_brach)
            }
            return expr

        case let .variable(name, id):
            return try lookupVariable(name, id)

        case let .call(calleeExpr, paren, argumentsExpr):
            let callee = try eval(calleeExpr)
            let args = try argumentsExpr.map { try eval($0) }

            if case let .callable(function) = callee {
                if args.count != function.arity {
                    throw RuntimeError(token: paren, message: "Expect \(function.arity) arguments but got \(args.count).")
                }
                return try function.call(interpreter: self, args)
            } else if case let .class(klass) = callee {
                if args.count != klass.arity {
                    throw RuntimeError(token: paren, message: "Expect \(klass.arity) arguments but got \(args.count).")
                }
                return try klass.call(interpreter: self, args)
            } else {
                throw RuntimeError(token: paren, message: "Can only call functions and classes.")
            }

        case let .lambda(params, body):
            let lambda = LoxFunction(nil, params, body, closure: environment, isInitializer: false)
            return .callable(lambda)
        }
    }

    private func evaluateMath(_ left: LoxValue, _ right: LoxValue, _ op: Token, operation: (Double, Double) throws -> Double) throws -> LoxValue {
        guard case let .number(l) = left, case let .number(r) = right else {
            throw RuntimeError(token: op, message: "Operands must be numbers.")
        }
        return try .number(operation(l, r))
    }

    private func evaluateComparison(_ left: LoxValue, _ right: LoxValue, _ op: Token, operation: (Double, Double) throws -> Bool) throws -> LoxValue {
        if case let .number(l) = left, case let .number(r) = right {
            return try .boolean(operation(l, r))
        }
        if case let .boolean(l) = left, case let .boolean(r) = right {
            let lVal = l ? 1.0 : 0.0
            let rVal = r ? 1.0 : 0.0
            return try .boolean(operation(lVal, rVal))
        }
        if case let .string(l) = left, case let .string(r) = right {
            return try .boolean(compareStrings(l, r, operation))
        }
        throw RuntimeError(token: op, message: "Operands must be numbers or booleans of the same type.")
    }

    private func compareStrings(_ left: String, _ right: String, _ op: (Double, Double) throws -> Bool) throws -> Bool {
        func recursiveCompare(_ lChars: ArraySlice<Character>, _ rChars: ArraySlice<Character>) throws -> Bool {
            if lChars.isEmpty, rChars.isEmpty {
                return try op(0, 0)
            }
            if lChars.isEmpty {
                return try op(0, 1)
            }
            if rChars.isEmpty {
                return try op(1, 0)
            }

            let lFirst = Double(lChars.first!.asciiValue ?? 0)
            let rFirst = Double(rChars.first!.asciiValue ?? 0)

            if lFirst == rFirst {
                return try recursiveCompare(lChars.dropFirst(), rChars.dropFirst())
            } else {
                return try op(lFirst, rFirst)
            }
        }

        return try recursiveCompare(Array(left)[...], Array(right)[...])
    }

    private func isTruthy(_ expr: LoxValue) -> Bool {
        switch expr {
        case .number, .string: return true
        case let .boolean(bool): return bool
        case .nil: return false
        case .callable: return true
        default: return true
        }
    }

    private func isEqual(_ a: LoxValue, _ b: LoxValue) -> Bool {
        switch (a, b) {
        case (.nil, .nil):
            return true
        case (.nil, _), (_, .nil):
            return false
        case let (.number(l), .number(r)):
            return l == r
        case let (.string(l), .string(r)):
            return l == r
        case let (.boolean(l), .boolean(r)):
            return l == r
        default:
            return false
        }
    }
}
