import Foundation

indirect enum Stmt {
    case `class`(_ name: Token, _ superClass: Expr?, _ instanceMethods: [Stmt], _ staticMethods: [Stmt])
    case expression(_ expression: Expr)
    case function(_ name: Token, _ params: [Token]?, _ body: [Stmt])

    case `return`(_ keyword: Token, _ value: Expr?)
    case `if`(_ condition: Expr, _ thenBranch: Stmt, _ elseBranch: Stmt?)
    case print(_ expression: Expr)
    case `while`(_ condition: Expr, _ body: Stmt)
    case `for`(_ initialization: Stmt?, _ condition: Expr, _ increment: Stmt?, _ body: Stmt)
    case `var`(_ name: Token, expression: Expr?)
    case `break`, `continue`
    case block(_ statements: [Stmt])
}
