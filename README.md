# idris2-optparse-applicative

A type-safe command-line option parser library for Idris2, built on a **free applicative functor** architecture. Inspired by Haskell's optparse-applicative, this library allows you to describe CLI interfaces as pure data structures that can be parsed, introspected, and extended.

**Status:** Beta — core interpreter complete, bounded multi-value support, subcommands, bash completion generation, and modifier system implemented.

---

## Features

- **Purely functional CLI parsing** — parsers are immutable data structures (free applicatives)
- **Type-safe composition** — combine parsers with `<*>` and `<|>`
- **Applicative/Alternative/Functor instances** — full typeclass hierarchy
- **Subcommands** — nested command trees via `Alt` branching
- **Multi-value options** — bounded repetition with `manyUpTo` / `someUpTo`
- **Bash completion** — generate `complete -W` scripts from parser introspection
- **Modifier system** — configure options with `long`, `short`, `help`, `metavar`, `value`
- **Help text formatting** — `alignColumns` and `formatOption` utilities
- **Error handling** — structured `ParseError` with human-readable rendering
- **Environment variable placeholders** — `envOption` for structural fallback
- **Validation framework** — `OptReader` typed converters with `validate` predicates

---

## Quick Start

### Building

Requires Idris2 v0.8.0 or later.

```bash
idris2 --build optparse-applicative.ipkg
```

Run the demo executable:

```bash
./build/exec/optparse-test --help       # Not yet implemented
./build/exec/optparse-test -v
./build/exec/optparse-test -o file.txt
./build/exec/optparse-test -v -o out.txt file1.txt file2.txt
```

### Minimal Example

```idris
import Options.Applicative.Types
import Options.Applicative.Builder
import Options.Applicative.Run

record Config where
  constructor MkConfig
  verbose : Bool
  output  : String

cliParser : Parser Config
cliParser = pure MkConfig
         <*> flag' ["-v", "--verbose"]
         <*> option ["-o", "--output"] "stdout"

main : IO ()
main = do
  config <- customExecParser cliParser
  putStrLn $ "verbose = " ++ show config.verbose
  putStrLn $ "output  = " ++ config.output
```

---

## Architecture

### Free Applicative Design

The `Parser a` type is a GADT representing a CLI parser as an abstract syntax tree:

```idris
data Parser : Type -> Type where
  Flag      : List String -> Parser Bool
  Option    : List String -> String -> Parser String
  Argument  : String -> Parser String
  Pure      : a -> Parser a
  App       : Parser (a -> b) -> Parser a -> Parser b
  Alt       : Parser a -> Parser a -> Parser a
  Fail      : Parser a
```

- **Primitives:** `Flag`, `Option`, `Argument` are the leaf constructors
- **Combinators:** `Pure`, `App`, `Alt`, `Fail` form the applicative structure
- **Interpretation:** `Run.idr` folds over the tree to consume CLI arguments

This design separates **description** from **execution** — the same `Parser` tree can be:
1. Executed to parse real CLI arguments
2. Introspected to generate help text
3. Traversed to extract option names for bash completion

### Typeclass Hierarchy

```idris
-- Functor: map a function over a parser
map f (Flag names) = App (Pure f) (Flag names)

-- Applicative: pure value and sequential application
pure = Pure
pf <*> pa = App pf pa

-- Alternative: failure and choice
empty = Fail
p1 <|> p2 = Alt p1 (force p2)
```

### Interpreter

`consumeArgs` is the core recursive driver. It walks the argument list and matches each argument against the leftmost applicable leaf in the parser tree. Key behaviors:

- **Flags:** match by name, return `True`, default to `False` if absent
- **Options:** consume two arguments (flag + value), error if value missing
- **Arguments:** always consume the next argument
- **App nodes:** reduce `pf` first, then `pa`, then apply `f x`
- **Alt nodes:** try left branch, fall back to right on failure
- **Empty args:** `finalizeParser` applies defaults (flags → `False`, options → error)

---

## API Reference

### Builder Combinators (`Options.Applicative.Builder`)

| Function | Signature | Description |
|----------|-----------|-------------|
| `flag'` | `List String -> Parser Bool` | Boolean flag with given names |
| `strOption` | `List String -> Parser String` | String option with given names |
| `argument` | `String -> Parser String` | Positional argument with metavar |
| `option` | `List String -> String -> Parser String` | Option with default value |
| `subparser` | `List (String, Parser a) -> Parser a` | Command dispatcher |
| `command` | `String -> Parser a -> (String, Parser a)` | Named subcommand |
| `info` | `Parser a -> String -> Parser a` | Attach description (passthrough) |

### Modifiers (`Options.Applicative.Modifiers`)

```idris
record Mod where
  longNames    : List String
  shortNames   : List String
  helpText     : Maybe String
  metavarText  : Maybe String
  defaultValue : Maybe String
```

| Function | Description |
|----------|-------------|
| `defaultMod` | Empty modifier config |
| `long` | Add `--name` style option |
| `short` | Add `-n` style option |
| `help` | Set help text |
| `metavar` | Set metavariable placeholder |
| `value` | Set default value |
| `applyMod` | Generate `Parser String` from `Mod` |

### Multi-Value (`Options.Applicative.Multi`)

| Function | Signature | Description |
|----------|-----------|-------------|
| `manyUpTo` | `Nat -> Parser a -> Parser (List a)` | Zero to N occurrences |
| `someUpTo` | `Nat -> Parser a -> Parser (List a)` | One to N occurrences |
| `concatOptions` | `Parser (List a) -> Parser (List a) -> Parser (List a)` | Concat two list parsers |

**Note:** Unbounded `many`/`some` were removed in Beta due to infinite AST expansion. Use `manyUpTo`/`someUpTo` with explicit bounds.

### Execution (`Options.Applicative.Run`)

| Function | Signature | Description |
|----------|-----------|-------------|
| `runParser` | `Parser a -> List String -> ParseResult a` | Parse explicit argument list |
| `runParserWith` | `Parser a -> List String -> ParseResult a` | Alias for `runParser` |
| `execParser` | `HasIO io => Parser a -> io (ParseResult a)` | Parse `getArgs` |
| `customExecParser` | `HasIO io => Parser a -> io a` | Parse and exit on failure |

### Error Handling (`Options.Applicative.Error`)

```idris
data ParseError = MissingOption String
                | InvalidOption String String
                | UnexpectedError String
```

| Function | Description |
|----------|-------------|
| `renderError` | Convert `ParseError` to human-readable string |
| `exitWithError` | Print error and return |
| `missingOptionError` | Format missing option message |
| `invalidOptionError` | Format invalid value message |
| `unexpectedError` | Format unexpected argument message |

### Validation (`Options.Applicative.Validation`)

| Function | Signature | Description |
|----------|-----------|-------------|
| `mkReader` | `Type -> String -> (String -> Maybe a) -> OptReader a` | Create typed reader |
| `optionWithReader` | `List String -> OptReader a -> Parser (Maybe a)` | Option with typed reader |
| `validate` | `(String -> Bool) -> String -> String -> Either String String` | Predicate validator |
| `autoInt` | `OptReader Int` | Integer reader |
| `autoNat` | `OptReader Nat` | Natural number reader |
| `autoDouble` | `OptReader Double` | Floating point reader (placeholder) |
| `str` | `OptReader String` | Identity reader |

### Bash Completion (`Options.Applicative.BashCompletion`)

| Function | Signature | Description |
|----------|-----------|-------------|
| `isCompletionRequest` | `List String -> Bool` | Check for `--bash-completion` flag |
| `optionNames` | `Parser a -> List String` | Extract all flag/option names |
| `bashCompletionScript` | `String -> Parser a -> String` | Generate `complete -W` script |

### Environment (`Options.Applicative.Env`)

| Function | Signature | Description |
|----------|-----------|-------------|
| `envOption` | `List String -> String -> Parser String` | Option with env var placeholder |
| `envOptionWithDefault` | `List String -> String -> String -> Parser String` | Option with env var default |

**Note:** Environment variable resolution is structural only (no `getEnv` IO) in Beta.

---

## Examples

### Flags and Options

```idris
parser : Parser (Bool, String)
parser = (,) <$> flag' ["-v", "--verbose"]
             <*> option ["-o", "--output"] "stdout"

-- ./prog -v -o file.txt  =>  Success (True, "file.txt")
-- ./prog                 =>  Success (False, "stdout")
```

### Positional Arguments

```idris
parser : Parser (List String)
parser = manyUpTo 16 (argument "FILE")

-- ./prog a.txt b.txt c.txt  =>  Success ["a.txt", "b.txt", "c.txt"]
-- ./prog                    =>  Success []
```

### Subcommands

```idris
data Cmd = Init | Build | Clean

cmdParser : Parser Cmd
  cmdParser = subparser
    [ ("init",  pure Init)
    , ("build", pure Build)
    , ("clean", pure Clean)
    ]

-- ./prog build  =>  Success Build
-- ./prog test   =>  Failure (MissingOption "Unsatisfied parser")
```

### Modifiers

```idris
verboseMod : Mod
verboseMod = long "verbose"
          |> short "v"
          |> help "Enable verbose output"

parser : Parser String
parser = applyMod verboseMod
```

### Bash Completion

```idris
script : String
script = bashCompletionScript "myapp" myParser

-- Output:
-- #!/bin/bash
-- complete -W "-v --verbose -o --output" myapp
```

---

## Testing

The project includes a test module `TestParse.idr` with sanity checks:

```idris
export testEmpty : ParseResult ToolConfig
testEmpty = runParserWith mainParser []

export testVerboseOnly : ParseResult ToolConfig
testVerboseOnly = runParserWith mainParser ["-v"]

export testOptionValue : ParseResult ToolConfig
testOptionValue = runParserWith mainParser ["--output", "results.json"]

export testFilesOnly : ParseResult ToolConfig
testFilesOnly = runParserWith mainParser ["src/Main.idr", "src/Types.idr"]

export testFullCombo : ParseResult ToolConfig
testFullCombo = runParserWith mainParser ["-v", "-o", "out.txt", "file1.txt", "file2.txt"]
```

Run the executable to verify:

```bash
./build/exec/optparse-test -v -o out.txt file1.txt file2.txt
```

---

## Known Issues & Limitations

### Positional Interleaving (Beta2 Planned)

The single-pass left-to-right tree traversal handles flags and options correctly when they appear in tree-matching order, but **out-of-order interleaving** can fail:

```bash
# Works: flag → option → positionals
./prog -v -o out.txt file1.txt

# May fail: option before flag
./prog -o out.txt -v file1.txt
# (Flag leaf skips -o, option may consume incorrectly)
```

**Workaround:** Place all flags first, then options, then positionals.

**Fix:** Two-pass parser planned for Beta2:
- Pass 1: Build substitution map (arg → leaf)
- Pass 2: Apply substitutions, then `finalizeParser` for defaults

### Integer Parsing (Beta2 Planned)

`readNatStr` in `Validation.idr` returns `Just 0` for any digit string instead of accumulating actual digits:

```idris
readNatStr cs = if all isDigit cs then Just 0 else Nothing  -- BUG
```

**Impact:** `autoInt`/`autoNat` readers always return `0`/`0`.

### Unbounded Recursion

`many`/`some` were removed in Beta. Use `manyUpTo n` / `someUpTo n` with explicit bounds to prevent infinite AST expansion and stack overflow.

### Environment Variables

`envOption`/`envOptionWithDefault` create parsers with placeholder defaults. No actual `getEnv` IO is performed in Beta.

### Help Text Introspection

`usage` and `helpText` generation are deferred to Beta2. `formatOption` and `alignColumns` work for manual help construction.

---

## Module Dependency Graph

```
Types
  ^
  |
Builder ----> Run ----> Help
  |           |
  v           v
Modifiers  Subparser
  |           |
  v           v
Error    BashCompletion
  ^
  |
Multi
  |
  v
Validation ----> Env
```

---

## Project Structure

```
src/
  Options/
    Applicative/
      Types.idr           -- Core GADT + typeclass instances
      Builder.idr         -- DSL combinators
      Run.idr             -- Parser interpreter
      Error.idr           -- Error rendering
      Modifiers.idr       -- Option modifier system
      Subparser.idr       -- Subcommand support
      Multi.idr           -- Multi-value parsing
      Validation.idr      -- Typed readers + validators
      Help.idr            -- Help text utilities
      BashCompletion.idr  -- Shell completion
      Env.idr             -- Environment variable placeholders
  Main.idr              -- Demo executable
  TestParse.idr         -- Sanity tests
```

---

## Contributing

### Type Hole Workflow

This project uses Idris2's type holes extensively during development. Follow this sequence:

1. Write signatures with type holes: `func args = ?rhs_func`
2. Compile immediately: `idris2 --build optparse-applicative.ipkg`
3. Read hole types via REPL: `idris2 --repl optparse-applicative.ipkg`
4. Fill holes one at a time, compile after each
5. Prefer `let ... in do` or `where` over nested `do` blocks
6. Use GADT-style data declarations

### Conventions

- 80 character line limit
- 2 spaces indentation, no tabs
- Align arrows in multi-line type signatures
- Document all exported top-level functions
- Use named arguments for functions with multiple args of same type

---

## Roadmap

### Beta (Current)
- [x] Core free applicative GADT
- [x] Functor/Applicative/Alternative instances
- [x] Parser interpreter with tree reduction
- [x] Flag, Option, Argument primitives
- [x] Subcommand support
- [x] Bounded multi-value parsing
- [x] Modifier system
- [x] Error rendering
- [x] Bash completion generation
- [x] IO integration (execParser, customExecParser)

### Beta2
- [ ] Two-pass parser for positional interleaving
- [ ] Fix `readNatStr` digit accumulation
- [ ] Full help text introspection (`usage`, `helpText`)
- [ ] Environment variable IO integration
- [ ] Lazy unbounded `many`/`some`

### Future
- [ ] Dependent-type guarantees for required/optional options
- [ ] Config file integration
- [ ] Man page generation
- [ ] Zsh completion support

---

## License

MIT License — see LICENSE file for details.

---

## Acknowledgments

Inspired by [Haskell's optparse-applicative](https://github.com/pcapriotti/optparse-applicative) by Paolo Capriotti. Built for the Idris2 ecosystem using free applicative functors and GADTs.
