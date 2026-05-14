import Foundation

indirect enum Expr {
    case assign(name: Token, expr: Expr)
    case logical(left: Expr, operator: Token, right: Expr)
    case binary(left: Expr, operator: Token, right: Expr)
    case call(_ callee: Expr, _ paren: Token, _ arguments: [Expr])
    case grouping(expression: Expr)
    case literal(value: Any?)
    case unary(operator: Token, right: Expr)
    case ternary(condition: Expr, _ then_branch: Expr, _ else_branch: Expr)
    case variable(name: Token)
    case lambda(_ params: [Token], _ body: [Stmt])
}

extension Expr: CustomStringConvertible {
    var description: String {
        switch self {
        case let .binary(left, op, right):
            return parenthesize(name: op.lexeme, exprs: left, right)
        case let .grouping(expr):
            return parenthesize(name: "group", exprs: expr)
        case let .literal(value):
            if let value = value {
                return "\(value)"
            } else {
                return "nil"
            }
        case let .unary(op, right):
            return parenthesize(name: op.lexeme, exprs: right)
        case let .ternary(condition, then_branch, else_branch):
            return "(? \(condition.description) \(then_branch.description) \(else_branch.description))"
        default: return ""
        }
    }

    private func parenthesize(name: String, exprs: Expr...) -> String {
        var builder = "(\(name)"
        for expr in exprs {
            builder += " \(expr.description)"
        }
        builder += ")"
        return builder
    }
}
