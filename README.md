# slox

A [Lox](https://craftinginterpreters.com) interpreter written in Swift. Based on the tree-walk interpreter from Part II of the book, with the following modifications and extensions.

## Deviations from the book

### Syntax

- **Semicolon-free.** Statements are terminated by newlines instead of `;`.
- **`continue` statement.** Supported inside `for`/`while` loops (the book only implements `continue` in clox, not jlox).
- **`break` statement.** Supported inside `for`/`while` loops (not present in jlox).
- **`lambda` expressions.** Anonymous functions: `lambda (x) { return x * 2 }`.
- **Ternary conditional.** `condition ? then_expr : else_expr`.
- **Comma operator.** `a, b` evaluates both, returns `b`.
- **Getter methods.** A method declared without `()` is automatically invoked on property access.
- **Static methods.** `class methodName()` inside a class body declares a static method, callable as `ClassName.methodName()`.

### Semantics

- **String + number concatenation.** `"value: " + 42` returns `"value: 42"`.
- **Boolean comparison.** Booleans are comparable (`false < true`), treated as 0/1.

### Internals

- **Swift** instead of Java. AST nodes use `indirect enum`; control flow (`break`/`continue`/`return`) uses thrown `Error` enums.
- **Index-based local storage.** Local variables are stored in arrays keyed by `(depth, index)` instead of name-based lookup at each depth — faster resolution.
- **Two-tier environment.** Globals use a name-based dictionary (supporting forward references); locals use index-based arrays.
- **UUID bridge.** The Resolver communicates resolved `(depth, index)` positions to the Interpreter via UUID-keyed maps rather than mutating the interpreter during the resolution pass.
- **`for` loop is a first-class AST node.** The parser returns a dedicated `.for` statement instead of desugaring to `while` — ensuring `continue` correctly runs the increment clause before the next iteration.

### Token additions

| Token | Book (jlox) | slox |
|-------|-------------|------|
| `break` | No | Yes |
| `continue` | No | Yes |
| `lambda` | No | Yes |
| `question` (`?`) | No | Yes |
| `colon` (`:`) | No | Yes |

### Error handling

- Unused local variables produce a warning on stderr.
- Exit codes: `64` (usage), `65` (parse error), `70` (runtime error), `74` (file not found).

## Build

```bash
swift build                    # debug
swift run                      # REPL
swift run slox script.lox      # run a file
```

Requires Swift 6.3+.
