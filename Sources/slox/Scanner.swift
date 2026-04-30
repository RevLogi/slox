import Foundation

@MainActor
class Scanner {
    private let source: [Character]
    private var tokens = [Token]()
    private var current: Int = 0
    private var start: Int = 0
    private var line: Int = 1

    private static let keywords: [String: TokenType] = [
        "and": .and,
        "class": .class,
        "else": .else,
        "false": .`false`,
        "for": .for,
        "fun": .fun,
        "if": .if,
        "nil": .`nil`,
        "or": .or,
        "print": .print,
        "return": .return,
        "super": .`super`,
        "this": .this,
        "true": .`true`,
        "var": .var,
        "while": .while,
    ]

    init(_ source: String) {
        self.source = Array(source)
    }

    func scanTokens() -> [Token] {
        while !isEnd() {
            start = current
            scanToken()
        }

        tokens.append(Token(type: .eof, lexeme: "", literal: nil, line: line))
        return tokens
    }

    private func isEnd() -> Bool {
        return current >= source.count
    }

    private func scanToken() {
        let c: Character = advance()

        switch c {
        case "(": addToken(.left_paren)
        case ")": addToken(.right_paren)
        case "{": addToken(.left_brace)
        case "}": addToken(.right_brace)
        case ",": addToken(.comma)
        case ".": addToken(.dot)
        case "-": addToken(.minus)
        case "+": addToken(.plus)
        case ";": addToken(.semicolon)
        case "*": addToken(.star)
        case "!":
            addToken(match("=") ? .bang_equal : .bang)
        case "=":
            addToken(match("=") ? .equal_equal : .equal)
        case ">":
            addToken(match("=") ? .greater_equal : .greater)
        case "<":
            addToken(match("=") ? .less_equal : .less)
        case "/":
            if match("/") {
                while peek() != "\n", !isEnd() {
                    advance()
                }
            } else {
                addToken(.slash)
            }
        case " ", "\r", "\t": break
        case "\n": line += 1
        case "\"": string()
        default:
            if c.isNumber {
                number()
            } else if c.isLetter {
                identifier()
            } else {
                Lox.error(line: line, message: "Unexpected character.")
            }
        }
    }

    private func identifier() {
        while peek().isNumber || peek().isLetter {
            advance()
        }

        let text = String(source[start ..< current])
        let type: TokenType = Scanner.keywords[text] ?? .identifier

        addToken(type)
    }

    private func number() {
        while peek().isNumber {
            advance()
        }

        if peek() == ".", peekNext().isNumber {
            advance()

            while peek().isNumber {
                advance()
            }
        }

        let text = String(source[start ..< current])
        let value = Double(text)

        addToken(type: .number, literal: value)
    }

    private func string() {
        while peek() != "\"", !isEnd() {
            if peek() == "\n" { line += 1 }
            advance()
        }

        if isEnd() {
            Lox.error(line: line, message: "Unterminated string.")
        }

        advance()

        let value = String(source[start + 1 ..< current - 1])
        addToken(type: .string, literal: value)
    }

    private func peekNext() -> Character {
        if current + 1 >= source.count { return "\0" }
        return source[current + 1]
    }

    private func peek() -> Character {
        if isEnd() { return "\0" }
        return source[current]
    }

    private func match(_ expected: Character) -> Bool {
        if isEnd() { return false }
        if source[current] != expected { return false }

        current += 1
        return true
    }

    @discardableResult
    private func advance() -> Character {
        let new_char = source[current]
        current += 1
        return new_char
    }

    private func addToken(_ type: TokenType) {
        addToken(type: type, literal: nil)
    }

    private func addToken(type: TokenType, literal: Any?) {
        let text = String(source[start ..< current])
        tokens.append(Token(type: type, lexeme: text, literal: literal, line: line))
    }
}
