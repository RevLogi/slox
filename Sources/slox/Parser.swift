import Foundation

@MainActor
class Parser {
    private let tokens: [Token]
    private var current: Int = 0
    private let allowExpression: Bool

    var currentLoop: LoopType = .none

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
            if match(.class) {
                return try classDeclaration()
            }
            if match(.var) {
                return try varDeclaration()
            }
            if match(.fun) {
                return try function("function")
            }
            return try statement()
        } catch {
            synchronize()
            return nil
        }
    }

    private func function(_ kind: String) throws -> Stmt {
        let name = try consume(.identifier, message: "Expect \(kind) name.")
        let parameters = try getParams(kind)
        let body = try getBody(name, kind)
        return .function(name, parameters, body)
    }

    private func lambda() throws -> Expr {
        let parameters = try getParams("lambda")
        let body = try getBody(peek(), "lambda")
        return .lambda(parameters, body)
    }

    private func getParams(_ kind: String) throws -> [Token] {
        try consume(.left_paren, message: "Expect '(' after \(kind) name.")
        var parameters: [Token] = []
        if !check(.right_paren) {
            repeat {
                if parameters.count >= 255 {
                    Lox.error(at: peek(), message: "Can't have more than 255 parameters.")
                }

                try parameters.append(consume(.identifier, message: "Expect parameter name."))
            } while match(.comma)
        }
        try consume(.right_paren, message: "Expect ')' after parameters.")
        return parameters
    }

    private func getBody(_ name: Token, _ kind: String) throws -> [Stmt] {
        try consume(.left_brace, message: "Expect '{' before \(kind) body.")
        let block: Stmt = try block()
        guard case let .block(body) = block else {
            throw error(at: name, message: "Expect \(kind) body to be a block.")
        }
        return body
    }

    private func classDeclaration() throws -> Stmt {
        let name: Token = try consume(.identifier, message: "Expect class name.")
        try consume(.left_brace, message: "Expect '{' before class body.")

        var methods: [Stmt] = []
        while !check(.right_brace), !isEnd() {
            try methods.append(function("method"))
        }
        try consume(.right_brace, message: "Expect '}' after class body.")

        return .class(name, methods)
    }

    private func varDeclaration() throws -> Stmt {
        let name: Token = try consume(.identifier, message: "Expect variable name.")
        var initializer: Expr? = nil
        if match(.equal) {
            initializer = try expression()
        }
        if !allowExpression {
            try consume(.semicolon, message: "Expect ';' after variable declaration.")
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
        if match(.if) {
            return try ifStatement()
        }
        if match(.while) {
            return try whileStatement()
        }
        if match(.for) {
            return try forStatement()
        }
        if match(.break) {
            return try breakStatement()
        }
        if match(.return) {
            return try returnStatement()
        }
        return try expressionStatement()
    }

    private func block() throws -> Stmt {
        var statements: [Stmt] = []
        while !check(.right_brace), !isEnd() {
            if let decl = try declaration() {
                statements.append(decl)
            }
        }
        try consume(.right_brace, message: "Expected '}' after block.")
        return .block(statements)
    }

    private func returnStatement() throws -> Stmt {
        let keyword = previous()
        var value: Expr? = nil
        if !check(.semicolon) {
            value = try expression()
        }

        try consume(.semicolon, message: "Expect ';' after return value.")
        return .return(keyword, value)
    }

    private func printStatement() throws -> Stmt {
        let value: Expr = try expression()
        try consume(.semicolon, message: "Expected ';' after value.")
        return .print(value)
    }

    private func ifStatement() throws -> Stmt {
        try consume(.left_paren, message: "Expect '(' after 'if'.")
        let condition = try expression()
        try consume(.right_paren, message: "Expect ')' after if condition.")

        let thenBranch: Stmt = try statement()
        var elseBranch: Stmt? = nil
        if match(.else) {
            elseBranch = try statement()
        }
        return .if(condition, thenBranch, elseBranch)
    }

    private func whileStatement() throws -> Stmt {
        try consume(.left_paren, message: "Expect '(' after 'while'.")
        let condition = try expression()
        try consume(.right_paren, message: "Expect ')' after condition.")

        let enclosingLoop = currentLoop
        currentLoop = .loop

        let body = try statement()
        currentLoop = enclosingLoop
        return .while(condition, body)
    }

    private func forStatement() throws -> Stmt {
        try consume(.left_paren, message: "Expect '(' after 'for'.")
        var initializer: Stmt?
        if match(.semicolon) {
            initializer = nil
        } else if match(.var) {
            initializer = try varDeclaration()
        } else {
            initializer = try expressionStatement()
        }

        var condition: Expr? = nil
        if !check(.semicolon) {
            condition = try expression()
        }
        try consume(.semicolon, message: "Expect ';' after loop condition.")

        var increment: Expr? = nil
        if !check(.right_paren) {
            increment = try expression()
        }
        try consume(.right_paren, message: "Expect ')' after for clauses.")

        let enclosingLoop = currentLoop
        currentLoop = .loop
        var body: Stmt = try statement()
        if let increment = increment {
            body = .block([body, .expression(increment)])
        }
        currentLoop = enclosingLoop

        if condition == nil {
            condition = .literal(value: true)
        }
        body = .while(condition!, body)

        if let initializer = initializer {
            body = .block([initializer, body])
        }

        return body
    }

    private func breakStatement() throws -> Stmt {
        if currentLoop == .none {
            Lox.error(at: previous(), message: "'break' statement should be inside a loop.")
        }
        try consume(.semicolon, message: "Expect ';' after break.")
        return .break
    }

    private func expressionStatement() throws -> Stmt {
        let expr: Expr = try expression()
        if allowExpression, isEnd() {
            return .print(expr)
        }
        try consume(.semicolon, message: "Expect ';' after expression.")
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
            if case let .variable(name, id) = expr {
                return .assign(name: name, expr: value, id)
            } else if case let .get(object, name) = expr {
                return .set(object, name, value)
            }

            throw error(at: equals, message: "Invalid assignment target.")
        }
        return expr
    }

    private func conditional() throws -> Expr {
        var expr = try logic_or()

        if match(.question) {
            let then_branch = try expression()
            try consume(.colon, message: "Expect ':' after then branch of conditional expression.")
            let else_branch = try conditional()
            expr = .ternary(condition: expr, then_branch, else_branch)
        }

        return expr
    }

    private func logic_or() throws -> Expr {
        var expr = try logic_and()

        while match(.or) {
            let op: Token = previous()
            let right = try logic_and()
            expr = .logical(left: expr, operator: op, right: right)
        }

        return expr
    }

    private func logic_and() throws -> Expr {
        var expr = try equality()

        while match(.and) {
            let op: Token = previous()
            let right = try equality()
            expr = .logical(left: expr, operator: op, right: right)
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

        return try call()
    }

    private func call() throws -> Expr {
        var expr: Expr = try primary()
        while true {
            if match(.left_paren) {
                expr = try finishCall(callee: expr)
            } else if match(.dot) {
                let name = try consume(.identifier, message: "Expect property name after'.'")
                expr = .get(expr, name)
            } else {
                break
            }
        }
        return expr
    }

    private func finishCall(callee: Expr) throws -> Expr {
        var arguments: [Expr] = []
        if !check(.right_paren) {
            repeat {
                if arguments.count >= 255 {
                    Lox.error(at: peek(), message: "Can't have more than 255 arguments.")
                }
                try arguments.append(expression())
            } while match(.comma)
        }

        let paren = try consume(.right_paren, message: "Expect ')' after arguments.")
        return .call(callee, paren, arguments)
    }

    private func primary() throws -> Expr {
        if match(.false) { return .literal(value: false) }
        if match(.true) { return .literal(value: true) }
        if match(.nil) { return .literal(value: nil) }

        if match(.this) { return .this(previous()) }

        if match(.lambda) {
            return try lambda()
        }

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
