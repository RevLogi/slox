import Foundation

@MainActor
class Parser {
    private let tokens: [Token]
    private var current: Int = 0
    private let allowExpression: Bool

    enum ParserError: Error {
        case failure
    }

    init(_ tokens: [Token], _ isREPL: Bool) {
        self.tokens = tokens
        allowExpression = isREPL
    }

    func parse() -> [Stmt]? {
        var statements: [Stmt] = []
        while !isEnd() {
            do {
                if let decl = try declaration() {
                    statements.append(decl)
                }
            } catch {
                return nil
            }
        }
        return statements
    }

    private func declaration() throws -> Stmt? {
        do {
            if match(.var) {
                return try varDeclaration()
            }
            return try statement()
        } catch {
            synchronize()
            return nil
        }
    }

    private func varDeclaration() throws -> Stmt {
        let name: Token = try consume(.identifier, message: "Expected variable name.")
        var initializer: Expr? = nil
        if match(.equal) {
            initializer = try expression()
        }
        if !allowExpression {
            try consume(.semicolon, message: "Expected ';' after variable declaration.")
        }
        return .var(name, expression: initializer)
    }

    private func statement() throws -> Stmt {
        if match(.print) {
            return try printStatement()
        }
        if match(.left_brace) {
            return try block()
        }
        return try expressionStatement()
    }

    private func block() throws -> Stmt {
        var statements: [Stmt?] = []
        while !check(.right_brace), !isEnd() {
            try statements.append(declaration() ?? nil)
        }
        try consume(.right_brace, message: "Expected '}' after block.")
        return .block(statements)
    }

    private func printStatement() throws -> Stmt {
        let value: Expr = try expression()
        try consume(.semicolon, message: "Expected ';' after value.")
        return .print(value)
    }

    private func expressionStatement() throws -> Stmt {
        let expr: Expr = try expression()
        if allowExpression, isEnd() {
            return .print(expr)
        }
        try consume(.semicolon, message: "Expected ';' after expression.")
        return .expression(expr)
    }

    private func expression() throws -> Expr {
        return try comma()
    }

    private func comma() throws -> Expr {
        var expr = try assignment()

        while match(.comma) {
            let op = previous()
            let right = try assignment()
            expr = .binary(left: expr, operator: op, right: right)
        }

        return expr
    }

    private func assignment() throws -> Expr {
        let expr: Expr = try conditional()
        if match(.equal) {
            let equals: Token = previous()
            let value: Expr = try assignment()
            if case let .variable(name) = expr {
                return .assign(name: name, expr: value)
            }

            throw error(at: equals, message: "Invalid assignment target.")
        }
        return expr
    }

    private func conditional() throws -> Expr {
        var expr = try equality()

        if match(.question) {
            let then_branch = try expression()
            try consume(.colon, message: "Expect ':' after then branch of conditional expression.")
            let else_branch = try conditional()
            expr = .ternary(condition: expr, then_branch, else_branch)
        }

        return expr
    }

    private func equality() throws -> Expr {
        var expr = try comparison()

        while match(.bang_equal, .equal_equal) {
            let op = previous()
            let right = try comparison()
            expr = .binary(left: expr, operator: op, right: right)
        }

        return expr
    }

    private func comparison() throws -> Expr {
        var expr = try term()

        while match(.greater, .greater_equal, .less, .less_equal) {
            let op = previous()
            let right = try term()
            expr = .binary(left: expr, operator: op, right: right)
        }

        return expr
    }

    private func term() throws -> Expr {
        var expr = try factor()

        while match(.plus, .minus) {
            let op = previous()
            let right = try factor()
            expr = .binary(left: expr, operator: op, right: right)
        }

        return expr
    }

    private func factor() throws -> Expr {
        var expr = try unary()

        while match(.slash, .star) {
            let op = previous()
            let right = try unary()
            expr = .binary(left: expr, operator: op, right: right)
        }

        return expr
    }

    private func unary() throws -> Expr {
        while match(.bang, .minus) {
            let op = previous()
            let right = try unary()
            return .unary(operator: op, right: right)
        }

        return try primary()
    }

    private func primary() throws -> Expr {
        if match(.false) { return .literal(value: false) }
        if match(.true) { return .literal(value: true) }
        if match(.nil) { return .literal(value: nil) }

        if match(.number, .string) {
            return .literal(value: previous().literal)
        }

        if match(.left_paren) {
            let expr = try expression()
            try consume(.right_paren, message: "Expect ')' after expression.")
            return .grouping(expression: expr)
        }

        if match(.identifier) {
            return .variable(name: previous())
        }

        if match(.bang_equal, .equal_equal) {
            try missingLeftOperand(consume: comparison)
        }
        if match(.greater, .greater_equal, .less, .less_equal) {
            try missingLeftOperand(consume: term)
        }
        if match(.plus) {
            try missingLeftOperand(consume: factor)
        }
        if match(.slash, .star) {
            try missingLeftOperand(consume: unary)
        }

        throw error(at: peek(), message: "Expected expression.")
    }

    private func missingLeftOperand(consume: () throws -> Expr) throws {
        let err = error(at: previous(), message: "Missing left-hand operand.")
        _ = try consume()
        throw err
    }

    @discardableResult
    private func consume(_ type: TokenType, message: String) throws -> Token {
        if check(type) { return advance() }

        throw error(at: peek(), message: message)
    }

    private func match(_ types: TokenType...) -> Bool {
        for type in types {
            if check(type) {
                advance()
                return true
            }
        }
        return false
    }

    @discardableResult
    private func advance() -> Token {
        if !isEnd() {
            current += 1
        }
        return previous()
    }

    private func isEnd() -> Bool {
        return peek().type == .eof
    }

    private func peek() -> Token {
        return tokens[current]
    }

    private func previous() -> Token {
        return tokens[current - 1]
    }

    private func check(_ type: TokenType) -> Bool {
        if isEnd() {
            return false
        }
        return peek().type == type
    }

    private func error(at token: Token, message: String) -> ParserError {
        Lox.error(at: token, message: message)
        return .failure
    }

    private func synchronize() {
        advance()

        while !isEnd() {
            if previous().type == .semicolon {
                return
            }

            switch peek().type {
            case .class, .fun, .var, .for, .if, .while, .print, .return: return
            default: advance()
            }
        }
    }
}
