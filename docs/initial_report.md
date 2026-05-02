# Initial Report: Implementing optparse-applicative in Idris2

## Executive Summary

Implementing an `optparse-applicative`-equivalent library for Idris2 is **feasible and well-suited to Idris2's type system**. Estimated effort:

- **MVP (usable for personal tools):** 2-3 weeks
- **Production-ready library (completions, subcommands, rich errors):** 2-3 months

## Current Ecosystem

### Existing Solutions

**`System.Console.GetOpt`** (in `contrib` package)

- Direct port of Haskell's `getopt` library
- Imperative API: define a list of `OptDescr` descriptors, call `getOpt`, receive a `Result`
- Supports short/long options, required/optional arguments, error reporting
- **Limitations:**
  - No composable parser structure
  - No applicative or monadic DSL
  - Help generation is separate from parsing logic
  - No subcommand support
  - No type-safe option composition

**`getopts` package** (minimal, no source available in local cache)
- Appears to be a thin wrapper; insufficient for applicative-style parsing

**Gap:** There is **no applicative CLI parser** in the Idris2 ecosystem.

## Why Idris2 is Well-Suited

Idris2 provides all necessary tools:

- **GADTs** for representing parser grammar as a data structure
- **Applicative/Functor/Alternative** for composable parsing DSL
- **First-class types** for introspection and help generation
- **Totality checking** ensures parser definitions are well-formed

The core design pattern --- a free applicative encoding of CLI grammars --- maps cleanly to Idris2's features.

## Architecture Overview

### Core Design: Free Applicative Parser

```idris
||| The CLI parser is a GADT that can be interpreted for parsing
||| or introspected for help generation.
data Parser : Type -> Type where
  -- Primitive parsers
  Flag      : (names : List String) -> Parser Bool
  Option    : (names : List String) -> (metavar : String) -> Parser String
  Argument  : (metavar : String) -> Parser String
  -- Combinators
  Pure      : a -> Parser a
  App       : Parser (a -> b) -> Parser a -> Parser b
  Alt       : Parser a -> Parser a -> Parser a
```

### Key Modules

| Module | Responsibility |
|--------|---------------|
| `Options.Applicative.Types` | Core `Parser` GADT and result types |
| `Options.Applicative.Builder` | DSL combinators (`strOption`, `flag'`, `subparser`) |
| `Options.Applicative.Parser` | Argument lexer and runner |
| `Options.Applicative.Help` | Usage/help text generation |
| `Options.Applicative.BashCompletion` | Shell completion scripts |

## Effort Breakdown

### Phase 1: Core (Week 1)

| Task | Days | Description |
|------|------|-------------|
| `Parser` GADT + Free Applicative | 2-3 | Grammar representation with `Pure`, `App`, `Alt` |
| Basic runner | 2 | Convert `List String` -> parsed value or error |
| Builder DSL | 1-2 | `option`, `argument`, `flag` combinators |

### Phase 2: Essential Features (Week 2)

| Task | Days | Description |
|------|------|-------------|
| Subcommands | 2-3 | `Alternative` branching for `git commit`-style CLIs |
| Modifiers system | 2 | `long`, `short`, `help`, `metavar`, `value` modifiers |
| Help rendering | 2-3 | Alignment, grouping, subcommand summaries |
| Error messages | 1-2 | "Missing required option", "Invalid argument" |

### Phase 3: Polish (Weeks 3-4)

| Task | Days | Description |
|------|------|-------------|
| Multi-value options | 1-2 | `--file a --file b` -> `["a", "b"]` |
| Environment fallback | 1-2 | `MYAPP_HOST` as default for `--host` |
| Defaults & validation | 1 | Custom validators, `eitherReader` |
| Shell completions | 5-7 | Bash/zsh completion script generation |

### Phase 4: Advanced (Optional)

| Feature | Effort | Notes |
|---------|--------|-------|
| Dependent-type guarantees | 1-2 weeks | Make required/optional options type-safe |
| Config file integration | 3-5 days | Layer config files under CLI options |
| Man page generation | 2-3 days | From parser introspection |

## Idris2-Specific Considerations

### Advantages

1. **Type-safe option presence:** Could encode "this option is required" in the type, so `--host` without an argument is a compile-time error in the parser definition.
2. **Totality:** Parser definitions can be checked total, ensuring no infinite loops in help generation.
3. **Clean introspection:** Pure data representation makes walking the parser tree for help straightforward.

### Challenges

1. **Strict evaluation:** Unlike Haskell's lazy evaluation, Idris2 is strict. Recursive parser structures must be carefully designed to avoid forcing infinite trees.
2. **No `DeriveFunctor`:** Must write `Functor`/`Applicative` instances manually, though this is straightforward for a free structure.
3. **Smaller ecosystem:** No existing libraries for text alignment, terminal width detection, or ANSI colors --- may need to implement or depend on minimal utilities.

## Recommendation

**Start with a minimal core:**

1. Define the `Parser` GADT with `Pure`, `App`, `Alt`, and primitive constructors
2. Implement a simple runner for `List String`
3. Add builder combinators (`option`, `argument`, `subparser`)
4. Generate basic `--help` output

This gives a usable library in **2-3 weeks**. Shell completions and dependent-type enhancements can be added incrementally.

The fundamental design --- free applicative over a CLI grammar --- is a natural fit for Idris2 and will produce a library that is both more composable than `GetOpt` and potentially more type-safe than the Haskell original.

## References

- [optparse-applicative (Haskell)](https://github.com/pcapriotti/optparse-applicative)
- `System.Console.GetOpt` (Idris2 `contrib` package)
- Free Applicative pattern: Capriotti & Kaposi, "Free Applicative Functors"
