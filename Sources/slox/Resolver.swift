import Foundation

@MainActor
class Resolver {
    var interpreter: Interpreter
    private var scopes: [Scope] = []

    private struct VariableState {
        let name: Token
        var isDefined: Bool
        var isRead: Bool
        let index: Int
    }

    private struct Scope {
        var variables: [String: VariableState] = [:]
        var nextIndex: Int = 0
    }

    private enum FunctionType {
        case none, function, initializer, method
    }

    private enum ClassType {
        case none, `class`, subclass
    }

    private var currentFunction: FunctionType = .none
    private var currentClass: ClassType = .none

    init(_ interpreter: Interpreter) {
        self.interpreter = interpreter
    }

    func resolve(_ statements: [Stmt]) {
        for statement in statements {
            resolve(statement)
        }
    }

    func resolve(_ statement: Stmt) {
        switch statement {
        case let .class(name, superClass, instanceMethods, staticMethods):
            if let superClass = superClass {
                resolve(expr: superClass)
            }

            let methods = instanceMethods + staticMethods
            let enclosingClass = currentClass
            currentClass = .class

            declare(name)
            define(name)

            if case let .variable(superClassName, _) = superClass {
                if superClassName.lexeme == name.lexeme {
                    Lox.error(at: superClassName, message: "A class can't inherit from itself.")
                }
            }

            if superClass != nil {
                currentClass = .subclass
                beginScope()
                let scopeIndex = scopes.count - 1
                let superIndex = scopes[scopeIndex].nextIndex
                scopes[scopeIndex].nextIndex += 1
                scopes[scopeIndex].variables["super"] = VariableState(
                    name: name,
                    isDefined: true,
                    isRead: true,
                    index: superIndex
                )
            }

            beginScope()
            let scopeIndex = scopes.count - 1
            let thisIndex = scopes[scopeIndex].nextIndex
            scopes[scopeIndex].nextIndex += 1
            scopes[scopeIndex].variables["this"] = VariableState(
                name: name,
                isDefined: true,
                isRead: true,
                index: thisIndex
            )

            for case let .function(name, params, body) in methods {
                var declaration: FunctionType = .method
                if name.lexeme == "init" {
                    declaration = .initializer
                }
                resolveFunction(params, body, declaration)
            }
            endScope()

            if superClass != nil {
                endScope()
            }

            currentClass = enclosingClass

        case let .block(statements):
            beginScope()
            resolve(statements)
            endScope()

        case let .var(name, value):
            declare(name)
            if let value = value {
                resolve(expr: value)
            }
            define(name)

        case let .function(name, params, body):
            declare(name)
            define(name)
            resolveFunction(params, body, .function)

        case let .expression(expr):
            resolve(expr: expr)

        case let .if(condition, ifBranch, elseBranch):
            resolve(expr: condition)
            resolve(ifBranch)
            if let elseBranch = elseBranch {
                resolve(elseBranch)
            }

        case let .print(expr):
            resolve(expr: expr)

        case let .return(keyword, expr):
            if case .none = currentFunction {
                Lox.error(at: keyword, message: "Can't return from top-level code.")
            }
            if case .initializer = currentFunction {
                Lox.error(at: keyword, message: "Can't return a value from an initializer.")
            }
            if let expr = expr {
                resolve(expr: expr)
            }

        case let .while(condition, body):
            resolve(expr: condition)
            resolve(body)

        default:
            return
        }
    }

    func resolve(expr: Expr) {
        switch expr {
        case let .super(keyword, _, _):
            if currentClass != .subclass {
                Lox.error(at: keyword, message: "Can't use 'super' with no superclass")
            }
            resolveLocal(expr, keyword)

        case let .this(keyword, _):
            if currentClass == .none {
                Lox.error(at: keyword, message: "Can't use 'this' outside of a class.")
                break
            }
            resolveLocal(expr, keyword)

        case let .variable(name, _):
            if let scope = scopes.last, scope.variables[name.lexeme]?.isDefined == false {
                Lox.error(at: name, message: "Can't read local variable in its own initializer.")
            }
            resolveLocal(expr, name)

        case let .assign(name, value, _):
            resolve(expr: value)
            resolveLocal(expr, name)

        case let .binary(left, _, right):
            resolve(expr: left)
            resolve(expr: right)

        case let .call(callee, _, arguments):
            resolve(expr: callee)
            for argument in arguments {
                resolve(expr: argument)
            }

        case let .grouping(expr):
            resolve(expr: expr)

        case let .logical(left, _, right):
            resolve(expr: left)
            resolve(expr: right)

        case let .unary(_, right):
            resolve(expr: right)

        case let .ternary(condition, ifBranch, thenBranch):
            resolve(expr: condition)
            resolve(expr: ifBranch)
            resolve(expr: thenBranch)

        case let .lambda(params, body):
            resolveFunction(params, body, .function)

        case let .get(object, _):
            resolve(expr: object)

        case let .set(object, _, value):
            resolve(expr: value)
            resolve(expr: object)

        default:
            return
        }
    }

    private func resolveLocal(_ expr: Expr, _ name: Token) {
        for (depth, scope) in scopes.reversed().enumerated() {
            if scope.variables.keys.contains(name.lexeme) {
                interpreter.resolve(expr, depth, scope.variables[name.lexeme]!.index)
                let scopeIndex = scopes.count - 1 - depth
                scopes[scopeIndex].variables[name.lexeme]?.isRead = true
                break
            }
        }
    }

    private func resolveFunction(_ params: [Token]?, _ body: [Stmt], _ type: FunctionType) {
        let enclosingFunction = currentFunction
        currentFunction = type

        beginScope()
        for param in params ?? [] {
            declare(param)
            define(param)
        }
        resolve(body)
        endScope()

        currentFunction = enclosingFunction
    }

    private func declare(_ name: Token) {
        if scopes.isEmpty { return }
        let scopeLastIndex = scopes.count - 1

        if scopes[scopeLastIndex].variables[name.lexeme] != nil {
            Lox.error(at: name, message: "Already a variable with this name in this scope.")
        }

        let index = scopes[scopeLastIndex].nextIndex
        scopes[scopeLastIndex].nextIndex += 1

        scopes[scopeLastIndex].variables[name.lexeme] = VariableState(
            name: name,
            isDefined: false,
            isRead: false,
            index: index
        )
    }

    private func define(_ name: Token) {
        if scopes.isEmpty { return }

        scopes[scopes.count - 1].variables[name.lexeme]?.isDefined = true
    }

    private func beginScope() {
        scopes.append(Scope())
    }

    private func endScope() {
        let scope = scopes.removeLast()
        for (_, state) in scope.variables {
            if state.isRead == false {
                Lox.warn(at: state.name, message: "Local variable '\(state.name.lexeme)' is never used.")
            }
        }
    }
}
