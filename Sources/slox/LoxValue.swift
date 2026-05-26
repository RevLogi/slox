import Foundation

enum LoxValue: @unchecked Sendable {
    case number(Double)
    case string(String)
    case boolean(Bool)
    case `nil`
    case `class`(LoxClass)
    case instance(LoxInstance)

    case callable(any LoxCallable)
}
