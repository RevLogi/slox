import Foundation

@MainActor
class Interpreter {
    enum LoxValue {
        case number(Double)
        case string(String)
        case boolean(Bool)
        case `nil`
    }

    func interpret(_ expr: Expr) {
        do {
            let value: LoxValue = try eval(expr)
            print(stringify(value))
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
        }
    }

    func eval(_ expr: Expr) throws -> LoxValue {
        switch expr {
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
                    return .nil
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
