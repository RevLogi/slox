import Foundation

enum Stmt {
    case expression(_ expression: Expr)
    case print(_ expression: Expr)
    case `var`(_ name: Token, expression: Expr?)
    case block(_ statements: [Stmt?])
}
