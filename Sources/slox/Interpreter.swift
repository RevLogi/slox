import Foundation

class Interpreter {
    enum LoxValue {
        case number(Double)
        case string(String)
        case boolean(Bool)
        case `nil`
    }

    func eval(_ expr: Expr) -> LoxValue {
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

        case let .grouping(expression): return eval(expression)

        case let .unary(op, expr):
            let expr: LoxValue = eval(expr)
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
            let left: LoxValue = eval(left)
            let right: LoxValue = eval(right)
            switch op.type {
            case .equal_equal:
                
        }
    }

    private func isTruthy(_ expr: LoxValue) -> Bool {
        switch expr {
        case .number, .string: return true
        case let .boolean(bool): return bool
        case .nil: return false
        }
    }
}
