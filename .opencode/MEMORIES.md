# optparse-applicative - Adventure Memories

## Project Overview
Free applicative CLI parser library in Idris 2, inspired by Haskell's `optparse-applicative`. Three phases completed, tagged at `alpha` (commit `e914317`). Clean build across **12 modules**.

### Module Map
| Module | Purpose |
|--------|---------|
| `Types.idr` | Core Parser GADT (Flag, Option, Argument, Pure, App, Alt, Fail) + Functor/Applicative/Alternative instances |
| `Builder.idr` | DSL combinators: `strOption`, `flag'`, `argument`, `option`, `subparser`, `command`, `info` |
| `Run.idr` | Interpreter: mutual finalizers (`finalizeApp`/`finalizeParser`), argument consumption, step results |
| `Error.idr` | Error rendering/printing for parse failures |
| `Help.idr` | Help text generation: column alignment, option formatting |
| `Subparser.idr` | Subcommand routing: `mkConfig`, `progDesc`, `lookupCommand`, `mkSubparser` |
| `Modifiers.idr` | Parser modifiers (full Mod record and modifier functions) |
| `BashCompletion.idr` | Bash completion script generation; `isCompletionRequest`; `optionNames` AST traversal |
| `Env.idr` | Environment variable fallback: `envOption`, `envOptionWithDefault` |
| `Multi.idr` | Multi-value combinators: `many`, `some`, `concatOptions`, `consApp` |
| `Validation.idr` | Typed readers (OptReader GADT), `validate()` predicate, autoInt/str/autoNat/autoDouble |
| `Main.idr` | Test harness: `mainParser`, `testParse` exposed for REPL verification |

## Build Commands
```bash
# Clean rebuild (always start here)
rm -rf build/ttc/ && idris2 --build optparse-applicative.ipkg

# Query hole types (REPL heredoc)
idris2 --repl optparse-applicative.ipkg <<'EOF'
:import Options.Applicative.ModuleName
:t rhs_hole_name        # NO ? prefix!
EOF

# Verify current state
git log --oneline -5 && git tag -l
```

## Known Idris 0.8 Bugs & Workarounds

### GADT Polymorphic Unification Cache Bug (Critical)
**Symptom:** `Parser a` vs `?argTy -> ?retTy` mismatch when implementing functions with polymorphic GADT parameters like `optionWithReader : List String -> OptReader a -> Parser a`.

**Root cause:** Idris 0.8's unification cache incorrectly treats phantom type parameters in exported GADT constructors as dependent, failing to unify `Parser String` with `Parser a` when `a` is polymorphic.

**Workaround (applied):**
- Stabilize by removing the problematic signature entirely and documenting usage patterns
- Users compose `strOption` + `validate()` instead
- Documented in `Validation.idr` comments as "post-alpha" item

### Mutual Recursion & Stack Overflow
**Symptom:** During REPL session initialization (not parsing), deep recursive Applicative trees cause stack overflow when Idris tries to eagerly reduce them.

**Root cause:** Free ASTs are lazy at parse time but Idris 0.8's type checker can still force reduction in certain contexts (instance bodies, top-level declarations).

**Workaround (applied):**
- Use explicit helper functions (`consApp`) instead of inline `<$>` / `<*>` syntax for recursive parsers
- Keep recursion at the AST constructor level; `runParser` handles bounded consumption correctly since arguments are finite lists

### Public Export GADT Parser Bugs
**Symptom:** `public export data OptReader : Type -> Type where MkOptReader ...` fails with unification errors.

**Workaround (applied):**
- Use standard `export data` instead of `public export` for polymorphic GADTs
- This avoids the public interface checker from attempting to unify phantom types prematurely

## Architecture Decisions

### Mutual Finalizers in Run.idr
Flags default to `False` when arguments run out. Implemented via mutual block:
```idris
mutual
  finalizeApp : Parser (x -> a) -> Parser x -> Maybe a
  finalizeParser : Parser a -> Maybe a
```
This allows end-of-input traversal to replace unsatisfied `Flag` nodes with defaults before failing on missing required options.

### Lazy AST Construction in Multi.idr
`many` and `some` are safe because they only construct Applicative trees (`App`, `Alt`). Actual recursion depth is bounded by the input argument list length at parse time, not tree construction time.

```idris
consApp : Parser a -> Parser (List a) -> Parser (List a)
consApp pa pl = App (map (::) pa) pl

many p = Alt (Pure []) (consApp p (many p))  -- infinite but lazy!
some p = consApp p (many p)
```

### StepResult Enum for Interpreter States
Three states drive the interpreter loop:
- `StepSuccess` — parser satisfied, return value + leftover args
- `StepFailure` — irrecoverable error, abort with message
- `StepMore` — partial progress, re-enter loop with remaining args

## Style Guide Compliance
See `STYLE.md` in project root. Key conventions followed:
- GADT-style data declarations everywhere except plain enums
- Named arguments in function signatures
- 2-space indentation, no tabs, 80-char line limit
- `:=` for let bindings, aligned arrows in case expressions

## Type-Hole Workflow (v3)
Strictly follow these 8 steps. Do not skip or combine.

1. **Select a type hole** from the codebase
2. **Query compiler:** `idris2 --repl optparse-applicative.ipkg <<'EOF'; :import <Module>; :t rhs_<name>; EOF` (NO `?` prefix!)
3. **Fill the hole.** If pattern matching needed, consult Idris's casesplit suggestion first
4. **Check compilation:** `rm -rf build/ttc/ && idris2 --build optparse-applicative.ipkg`
5. **Query new holes** via REPL to verify expected types match plan
6. **Compare types** — ensure compiler output matches implementation logic
7. **Commit** with detailed message referencing step numbers and hole types
8. **Repeat** until build is clean

### Hole Querying Rules
| Syntax | Result | Use? |
|--------|--------|------|
| `:t rhs_name` | Context + expected type | YES |
| `:t ?rhs_name` | Nested useless hole | NO |

Holes inside instance bodies (`Functor where ...`) are **NOT** visible to REPL. Only top-level function holes are queryable.

## Git Tags
- `v0.0.0` — initial skeleton
- `pre-alpha` — phases 1-2 complete, phase 3 stabilization point
- `alpha` — all 12 modules clean build, many/some working, readers stable

## Deferred / Post-Alpha Items
| Item | Module | Blocker |
|------|--------|---------|
| `optionWithReader : List String -> OptReader a -> Parser a` | Validation.idr | GADT unification bug (see above) |
| Deep recursive parsers beyond 256 args | Multi.idr | Idris stack limit on large trees |
| IO-based argument fetching (`getArgs`) | Run.idr | Requires system library imports not in scope |

## Session Learnings
- **Python edits via `nix develop -c python3`** are reliable for complex indentation-sensitive changes in Idris files
- **Never combine steps** — the 8-step workflow prevents cascading type errors that take hours to debug
- **`mutual` blocks work reliably** in Idris 0.8; prefer them over forward references when possible
- **GADT phantom types + public export = unification hell**; always test with `export` first before promoting to `public export`

## Two-Pass Beta Release (2026-05-04)

### Two-Pass Parser Implementation
Completely replaced single-pass argument traversal with two-phase architecture:

**Pass 1 — Collection:** Global scan of all CLI args into a flat binding state (`ParseBindings`)
- Flags matched by `isKnownFlag` against tree leaves → tracked as `(List String, Bool)` pairs
- Options consume next arg as value → tracked as `(List String, Maybe String)` pairs
- Everything else accumulates in order as positionals

**Pass 2 — Application:** Walk parser tree once, look up bindings by name via `eqNames`
- `Flag names` → find matching entry in `bnds.flags`, default to False if unseen
- `Option nm` → find matching entry in `bnds.options`, return Nothing if absent
- `Argument _` → pull from head of `positionals` list (FIFO)
- Applicative structure reconstructed via App/Alt nodes walking

### Runtime Argument Filtering
`execParser` now strips internal runtime args from `getArgs`:
```idris
isUserArg : String -> Bool
isUserArg x = case unpack x of
    '/' :: _ => False   -- skip absolute paths (.so, .ttc)
    '-' :: 'l' :: _ => False  -- skip -l library refs
    '-' :: 'L' :: _ => False -- skip -L library dirs  
    _ => True
```

### Session Learnings from Two-Pass Implementation
- **`collectBindings`/`applyBindings` mutual block required** to avoid forward reference errors in Idris 0.8
- **Two-pass eliminates argument starvation:** flags/options no longer compete with positionals during tree traversal
- **Interleaving fixed by design:** global scan decouples argument order from parser tree shape
- **Golden tests validate correctness:** all 6 golden cases pass including `interleaved` and `flag-only`

### Architecture Changes
- Added `ParseBindings` record to `Types.idr`: flags, options, positionals lists
- Added `CollectResult` type: success/failure for collection phase
- All mutual helpers (`getAllFlagNames`, `checkFlag`, etc.) live in top-level mutual block in Run.idr
- Two-pass functions exportable; single-pass retained for backward compat

## Beta2 Bug Fixes (2026-05-03)

### Critical Bugs Fixed
1. **reduceApp order** - process pf before pa to prevent argument starvation in Applicative composition  
2. **tryLeftOrRight Alt backtracking** - handle StepMore from matchArg instead of propagating blindly  
3. **Option two-arg consumption** - return StepMore for Options to force consumption through consumeArgs  
4. **manyUpTo branch ordering** - swap branches so matching is tried before empty fallback  
5. **Unbounded many/some removal** - eliminated infinite AST expansion risk entirely

### Architecture Changes
- All interdependent helpers (reduceApp/tryLeftOrRight/goReduction) now in top-level mutual block
- Mutual block must include all functions with circular dependencies; order matters within block
- Idris 0.8 processes where clauses sequentially; nested definitions cause forward reference errors
