import Foundation

@main
@MainActor
struct slox {
    static var hadError = false

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
        } catch {
            print("Error: Could not read file in \(path)")
            exit(74)
        }
    }

    private static func runPrompt() {
        print("slox > ", terminator: "")
        while let line = readLine() {
            run(source: line)
            hadError = false
            print("slox > ", terminator: "")
        }
    }

    private static func run(source: String) {
        let scanner = Scanner(source: source)
        let tokens = scanner.scanTokens()

        for token in tokens {
            print(token)
        }
    }

    static func error(line: Int, message: String) {
        report(line: line, where: "", message: message)
    }

    private static func report(line: Int, where: String, message: String) {
        fputs("[line \(line)] Error \(`where`): \(message)\n", stderr)
        hadError = true
    }
}
