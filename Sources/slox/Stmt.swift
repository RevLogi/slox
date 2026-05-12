import Foundation

indirect enum Stmt {
    case expression(_ expression: Expr)
    case `if`(_ condition: Expr, _ thenBranch: Stmt, _ elseBranch: Stmt?)
    case print(_ expression: Expr)
    case `while`(_ condition: Expr, _ body: Stmt)
    case `var`(_ name: Token, expression: Expr?)
    case `break`
    case block(_ statements: [Stmt?])
}
