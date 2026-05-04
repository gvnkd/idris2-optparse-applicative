# idris2-optparse-applicative

A type-safe command-line option parser library for Idris2, built on a **free applicative functor** architecture. Inspired by Haskell's optparse-applicative, this library allows you to describe CLI interfaces as pure data structures that can be parsed, introspected, and extended.

**Status:** v0.4.0 ✅ — Subcommand flag scoping verified (cross-subcommand flags rejected). Two-pass parser with 23 library golden tests + 2 example tests. Command GADT enables proper per-subcommand option isolation.

---

## Features

- **Purely functional CLI parsing** — parsers are immutable data structures (free applicatives)
- **Type-safe composition** — combine parsers with `<*>` and `<|>`
- **Applicative/Alternative/Functor instances** — full typeclass hierarchy
- **Subcommands** — nested command trees via `Command` GADT constructor
- **Subcommand flag scoping** — cross-subcommand flags (e.g., `clean --template`) rejected automatically
- **Multi-value options** — bounded repetition with `manyUpTo` / `someUpTo`
- **Bash completion** — generate `complete -W` scripts from parser introspection
- **Modifier system** — configure options with `long`, `short`, `help`, `metavar`, `value`
- **Help text formatting** — grouped sections (global opts + per-subcommand), aligned columns, descriptions via `mhelp`
- **Error handling** — structured `ParseError` with human-readable rendering
- **Environment variable placeholders** — `envOption` for structural fallback
- **Validation framework** — `OptReader` typed converters with `validate` predicates

---

## Quick Start

### Building

Requires Idris2 v0.8.0 or later.

**Using Nix (recommended):**

```bash
nix develop --command build              # Build the library only
nix develop --command run-tests         # Build lib + test fixture, run 23 library golden tests
nix develop --command run-example-tests # Build lib + example, run 2 example golden tests
```

Inside `nix develop` shell, commands are available directly:

```bash
build              # Build the library only
run-tests          # Build lib, install it, build test fixture, run 23 lib golden tests
run-example-tests  # Build lib, install it, build example executable, run 2 example golden tests
```

**Manual build:**

```bash
# 1. Build the pure library
idris2 --build optparse-applicative.ipkg

# 2. Install to user registry (required before building examples)
idris2 --install optparse-applicative.ipkg

# 3. Build example application that depends on the library
idris2 -p optparse-applicative --build example/optparse-applicative-example.ipkg
```

Run the demo executable:

```bash
./example/build/exec/optparse-test --help            # Full help with grouped sections and descriptions
./example/build/exec/optparse-test clean -n          # Subcommand + flag (-n/--dry-run)
./example/build/exec/optparse-test init --template vue  # Subcommand + option (--template)
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
  Flag      : List String -> Maybe String -> Parser Bool
  Option    : List String -> String -> Maybe String -> Parser String
  Argument  : String -> Maybe String -> Parser String
  Command   : String -> Parser a -> Parser a     -- tags subparser with command name
  Pure      : a -> Parser a
  App       : Parser (a -> b) -> Parser a -> Parser b
  Alt       : Parser a -> Parser a -> Parser a
  Fail      : Parser a
```

- **Primitives:** `Flag`, `Option`, `Argument` are the leaf constructors (carry optional help text)
- **Command scoping:** `Command n px` tags each subparser branch with its name for dispatch routing
- **Combinators:** `Pure`, `App`, `Alt`, `Fail` form the applicative structure

This design separates **description** from **execution** — the same `Parser` tree can be:
1. Executed to parse real CLI arguments (two-pass: collectBindings → applyBindings)
2. Introspected to generate grouped help text (global opts + per-subcommand sections)
3. Traversed to extract option names for bash completion

### Typeclass Hierarchy

```idris
-- Functor: map a function over a parser
map f (Flag names h) = App (Pure f) (Flag names h)

-- Applicative: pure value and sequential application
pure = Pure
pf <*> pa = App pf pa

-- Alternative: failure and choice
empty = Fail
p1 <|> p2 = Alt p1 (force p2)
```

### Two-Pass Interpreter

The interpreter uses a two-phase architecture for correct positional interleaving:

**Pass 1 — Collection (`collectBindings`):** Global scan of all CLI args into flat binding state (`ParseBindings`)
- Flags matched by name → tracked as `(List String, Bool)` pairs
- Options consume next arg as value → tracked as `(List String, Maybe String)` pairs  
- Remaining strings accumulate in order as positionals

**Pass 2 — Application (`applyBindings`):** Walk parser tree once, dispatch on command names
- Positional arguments matching registered `Command` names route to corresponding subparser branches
- Nested flags/options resolved via recursive collect+apply cycles per subcommand
- Mutual finalizers handle end-of-input defaults (Flags → False)

### Subcommand Flag Scoping

Cross-subcommand flag injection is automatically rejected:

```bash
$ optparse-test clean --template          # Error: Unknown argument: --template (belongs to init)
$ optparse-test build -n                  # Error: Unknown argument: -n           (belongs to clean)
```

This works because `Command` nodes isolate scope — Pass 1 only collects top-level global flags. Once a command name is dispatched in Pass 2, subcommand-specific flags are validated within their own collection cycle.

---

## API Reference

### Builder Combinators (`Options.Applicative.Builder`)

| Function | Signature | Description |
|----------|-----------|-------------|
| `flag'` | `List String -> Parser Bool` | Boolean flag with given names |
| `strOption` | `List String -> Parser String` | String option with given names |
| `argument` | `String -> Parser String` | Positional argument with metavar |
| `option` | `List String -> String -> Parser String` | Option with default value |
| `subparser` | `List (String, Parser a) -> Parser a` | Command dispatcher wrapping branches with `Command` tags |

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
| `long` / `short` | Add `--name`/`-n` style options |
| `help` / `metavar` | Set help text and metavariable placeholder |
| `value` | Set default value |
| `applyMod` | Generate `Parser String` from `Mod` config |

### Multi-Value (`Options.Applicative.Multi`)

| Function | Signature | Description |
|----------|-----------|-------------|
| `manyUpTo` | `Nat -> Parser a -> Parser (List a)` | Zero to N occurrences |
| `someUpTo` | `Nat -> Parser a -> Parser (List a)` | One to N occurrences |

### Help (`Options.Applicative.Help`)

| Function | Signature | Description |
|----------|-----------|-------------|
| `mhelp` | `Parser a -> String -> Parser a` | Attach help description to any parser node |
| `collectHelpInfo` | `String -> Parser a -> HelpInfo` | Separate global opts from per-command entries for grouped rendering |

### Execution (`Options.Applicative.Run`)

| Function | Signature | Description |
|----------|-----------|-------------|
| `runParserWith` | `Parser a -> List String -> ParseResult a` | Two-pass parse explicit argument list |
| `execParser` | `HasIO io => Parser a -> io (ParseResult a)` | Parse from system args via `getArgs` |
| `customExecParser` | `HasIO io => Parser a -> io a` | Parse and exit on failure with rendered error text |

---

## Testing

The project uses **Test.Golden** (from the Idris2 standard library) for regression testing. A dedicated test fixture (`tests/app/`) runs 23 library golden tests, while 2 minimal example tests verify the demo application.

### Running Tests

```bash
# Via Nix flake (recommended)
nix develop --command run-tests         # 23 library golden tests via test fixture
nix develop --command run-example-tests # 2 example golden tests against demo app

# Manual runs
cd tests/app && idris2 -p optparse-applicative --build test-app.ipkg   # build fixture
cd ../../tests && idris2 --build tests.ipkg && \
  ./build/test/exec/runtests ../app/build/exec/optparse-test-fixture    # run 23 tests

# Example app tests
(cd example/tests && idris2 --build tests.ipkg) && \
  cd build/test/exec && ./runtests ../../../../example/build/exec/optparse-test  # run 2 tests
```

### Test Coverage (25 total)

**Library (23 golden tests):** Flags, options, positionals, interleaving, full combos, help text generation, subcommand routing/scoping/validation (correct flags per command + cross-subcommand rejection).

**Example (2 golden tests):** `basic` (-v flag), `help` (grouped output verification).

---

## Known Issues & Limitations

### Integer Parsing

`autoInt`/`autoNat` digit accumulation fixed. Negative integers and floating point (`autoDouble`) remain structural placeholders.

### Unbounded Recursion

Unbounded `many`/`some` were removed due to infinite AST expansion. Use `manyUpTo n` / `someUpTo n` with explicit bounds.

### Environment Variables

`envOption`/`envOptionWithDefault` create structural placeholders only — no actual `getEnv` IO performed yet.

---

## Project Structure

```
src/Options/Applicative/*.idr    # Pure library (11 modules: Types, Builder, Run, Help, etc.)

example/src/Examples/CliMain.idr  # Working demo app with subcommands + help grouping
example/tests/                    # Example golden tests (basic/help)

tests/app/TestMain.idr            # Test fixture binary (mirrors example CLI for lib suite)
tests/*                           # Library golden tests (23 cases: flags, options, subcmds, etc.)
```

---

## Roadmap

### v0.4.0 (Current Release) ✅
- [x] Command GADT + subcommand flag scoping (cross-subcmd injection rejected)
- [x] Two-pass parser with positional interleaving support  
- [x] Help text introspection: grouped sections, aligned columns, descriptions via `mhelp`
- [x] Test suite split: 23 lib tests + 2 example tests

### Future
- [ ] IO-based argument fetching / environment variable resolution (`getEnv`)
- [ ] Negative integer and floating point parsing in Validation  
- [ ] Lazy unbounded `many`/`some` with explicit depth limits
- [ ] Dependent-type guarantees for required/optional options
- [ ] Config file integration

---

## License

MIT License — see LICENSE file for details.

---

## Acknowledgments

Inspired by [Haskell's optparse-applicative](https://github.com/pcapriotti/optparse-applicative) by Paolo Capriotti. Built for the Idris2 ecosystem using free applicative functors and GADTs.
