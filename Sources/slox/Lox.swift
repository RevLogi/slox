import Foundation

@main
@MainActor
struct Lox {
    static let interpreter = Interpreter()

    static var hadError = false
    static var hadRuntimeError = false

    static func main() {
        let args = CommandLine.arguments
        if args.count > 2 {
            print("Usage: slox [script]")
            exit(64)
        } else if args.count == 2 {
            runFile(path: args[1])
        } else {
            runPrompt()
        }
    }

    private static func runFile(path: String) {
        do {
            let contents = try String(contentsOfFile: path)
            run(source: contents)
            if hadError { exit(65) }
            if hadRuntimeError { exit(70) }
        } catch {
            print("Error: Could not read file in \(path)")
            exit(74)
        }
    }

    private static func runPrompt() {
        print("slox > ", terminator: "")
        while let line = readLine() {
            if line == "exit" || line == "quit" {
                print("exit")
                break
            }
            run(source: line)
            hadError = false
            print("slox > ", terminator: "")
        }
    }

    private static func run(source: String) {
        let scanner = Scanner(source)
        let tokens = scanner.scanTokens()
        let parser = Parser(tokens)

        guard let expression = parser.parse(), !hadError else {
            return
        }

        interpreter.interpret(expression)
    }

    static func error(line: Int, message: String) {
        report(line: line, where: "", message: message)
    }

    static func error(at token: Token, message: String) {
        if token.type == .eof {
            report(line: token.line, where: " at End", message: message)
        } else {
            report(line: token.line, where: "at \(token.lexeme)", message: message)
        }
    }

    private static func report(line: Int, where: String, message: String) {
        fputs("[line \(line)] Error \(`where`): \(message)\n", stderr)
        hadError = true
    }

    static func runtimeError(_ error: RuntimeError) {
        fputs("\(error.message)\n[line \(error.token.line)]", stderr)
        hadRuntimeError = true
    }
}
