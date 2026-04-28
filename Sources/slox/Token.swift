import Foundation

enum TokenType {
    case left_paren, right_paren, left_brace, right_brace
    case comma, dot, minus, plus, semicolon, slash, star

    case bang, bang_equal
    case equal, equal_equal
    case greater, greater_equal
    case less, less_equal

    case identifier, string, number

    case and, `class`, `else`, `false`, fun, `for`, `if`, `nil`, or
    case print, `return`, `super`, this, `true`, `var`, `while`
    case eof
}

struct Token: CustomStringConvertible {
    let type: TokenType
    let lexeme: String
    let literal: Any?
    let line: Int

    var description: String {
        return "\(type) \(lexeme) \(literal ?? "")"
    }
}
