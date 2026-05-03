# Plan: Implementing `Options.Applicative.Run`

## Overview

`Run.idr` is the **interpreter** for the free applicative `Parser` GADT. It takes a parsed AST (`Parser a`) and a list of CLI arguments, then produces a `ParseResult a`. Without this module, the library cannot execute parsers — it can only build them.

## Current State

- `Types.idr` defines the GADT correctly.
- `Functor` instance is complete.
- `Applicative.<*>` and `Alternative.empty` are still holes (see [Decision: Adding `Fail`](#decision-adding-fail)).
- `Run.idr` is **100% holes** — 5 functions, all unimplemented.
- **47 total holes** across the codebase.

## Interpreter Strategy: Stateful Tree Reduction

The `Parser` GADT is a **free applicative** — it describes the shape of a CLI without execution semantics. To run it, we fold over the tree, consuming arguments and replacing matched leaves with `Pure value`.

### Core Idea

1. Start with parser tree `p` and argument list `args`.
2. For each argument, find the leftmost unsatisfied leaf in `p` that can consume it.
3. Replace that leaf with `Pure matchedValue`.
4. `App` nodes naturally propagate: `App (Pure f) (Pure x)` collapses toward `Pure (f x)`.
5. Repeat until `args` is empty.
6. If the resulting tree is `Pure result`, succeed. If unsatisfied leaves remain, fail.

### Why Not Simple Left-to-Right?

In a naïve left-to-right fold over `App pf pa`, we would consume arguments for `pf` first, then `pa`. This breaks real CLI semantics where flags can appear in any order (`--output file --verbose` vs `--verbose --output file`).

Instead, we **search the tree** for a matching leaf on every argument, which gives us order-independent option parsing.

## Decision: Adding `Fail`

`Alternative.empty` is currently a hole. The `Parser` GADT has no representation for "always fails." We need to add a `Fail` constructor:

```idris
Fail : Parser a
```

This is required for:
- `Alternative.empty`
- `subparser []` base case in `Builder.idr`
- Backtracking in `Alt` when the left branch is exhausted

### Impact
- `Fail` is a **new constructor** in the GADT.
- All functions in `Run.idr` must handle it (always returns `StepFailure`).
- `Help.idr`, `BashCompletion.idr` must ignore or handle `Fail` in introspection.

**Resolution:** Add `Fail` to `Parser` before implementing `Run.idr`.

## Function-by-Function Plan

### 1. `matchArg : Parser a -> String -> StepResult a`

Attempts to match **one** argument against a leaf in the parser tree. Returns the updated tree and remaining arguments.

**Leaf Cases:**
- `Flag names`: If `arg` is in `names`, return `StepSuccess True args`.
- `Argument mv`: Always matches. Return `StepSuccess arg args`.
- `Pure x`: Already satisfied. Return `StepSuccess x (arg :: args)` — do NOT consume.
- `Fail`: Return `StepFailure` with `UnexpectedError`.

**Branch Cases:**
- `App pf pa`: Search for a match in `pa` first (right side), then `pf`. If `pa` is already `Pure`, search `pf`. Replace the matched subtree and return updated `App`.
- `Alt p1 p2`: Try `p1`. If `StepFailure`, try `p2`.

**Option Problem:** `Option` requires **two** arguments (flag name + value). `matchArg` only receives one `String`.

**Resolution Options:**
1. **Change signature:** `matchArg : Parser a -> String -> List String -> StepResult a` — allows consuming the next arg for Option values.
2. **Handle atomically in `consumeArgs`:** `matchArg` skips Option; `consumeArgs` pattern-matches on Option directly.

**Recommendation:** Option 2 for now. Keep `matchArg` focused on single-arg matching. Let `consumeArgs` handle multi-arg constructs.

### 2. `consumeArgs : Parser a -> List String -> StepResult a`

Main recursive driver. Repeatedly applies arguments to the parser tree.

```idris
consumeArgs p [] = finalize p
consumeArgs p (arg :: args) =
  case matchArg p arg of
    StepSuccess value rest       => consumeArgs (replaceLeaf p arg value) rest
    StepFailure err              => StepFailure err
    StepMore p' rest             => consumeArgs p' rest
```

**For `Option names mv`:**
```idris
consumeArgs (Option names mv) (arg :: val :: rest) =
  if arg `elem` names
  then StepSuccess val rest
  else StepFailure (InvalidOption arg ...)
```

**Tree Update Logic:**
When `matchArg` finds a match, we need a helper `replaceLeaf` that rebuilds the tree with the matched leaf replaced by `Pure value`. This helper is internal to `Run.idr`.

```idris
replaceLeaf : Parser a -> String -> b -> Parser a
-- Traverses the tree, replaces the first matching leaf with Pure value
```

**Note:** `replaceLeaf` is the trickiest part. It needs to preserve the GADT's type structure while substituting. With `App`, we may need to track which side was matched.

### 3. `runParser : Parser a -> List String -> ParseResult a`

Orchestrates the full parse.

```idris
runParser p args =
  case consumeArgs p args of
    StepSuccess result []        => Success result
    StepSuccess result remaining => Failure (UnexpectedError "...")
    StepFailure err              => Failure err
    StepMore p' []               => Failure (MissingOption "...")
    StepMore p' remaining        => consumeArgs p' remaining  -- should not happen
```

**Edge Cases:**
- Unconsumed arguments after successful parse → error.
- Parser still needs more input after args exhausted → `MissingOption`.

### 4. `execParser : Parser a -> IO (ParseResult a)`

Wraps `runParser` with `getArgs`.

```idris
execParser p = do
  args <- getArgs
  pure (runParser p args)
```

### 5. `customExecParser : Parser a -> IO a`

Like `execParser` but exits on failure.

```idris
customExecParser p = do
  result <- execParser p
  case result of
    Success a         => pure a
    Failure err       => exitWithError err  -- from Error.idr
    CompletionInvoked => pure a  -- or handle differently
```

## Type Hole Workflow

Per `.opencode/MEMORIES.md`:

1. **Add `Fail` constructor** to `Parser` in `Types.idr`.
2. **Fill `Applicative.<*>`** → `App pf pa`.
3. **Fill `Alternative.empty`** → `Fail`.
4. **Implement `matchArg`** with a top-level hole, compile, query REPL.
5. **Implement `consumeArgs`** — may need `replaceLeaf` helper.
6. **Implement `runParser`** — straightforward wrapper.
7. **Implement `execParser` / `customExecParser`** — IO glue.
8. **Build and verify** after each function.

**WARNING:** Holes inside `where` blocks or instance bodies are NOT visible to the REPL. Keep helper functions at the top level or use `let` with explicit signatures if needed.

## Dependencies on Other Modules

| Module | What Run.idr Needs |
|--------|-------------------|
| `Types` | `Parser`, `ParseResult`, `StepResult`, `ParseError` constructors |
| `Error` | `renderError`, `exitWithError` for `customExecParser` |
| `Help` | May need `usage` for error messages (optional) |
| `Env` | Not directly — env fallback happens at parser construction time |

## Module Dependency Graph (Updated)

```
Types
  ^
  |
Builder ----> Run ----> Help
  |    \      |
  |     \     v
  v      \  Error
Modifiers  Subparser
```

## Risks & Open Questions

1. **`replaceLeaf` typing:** Replacing a leaf inside a `Parser a` while preserving types is non-trivial with `App`. We may need the tree to carry evidence of which leaves have been filled, or use a different representation during parsing.

2. **Option + `App` interaction:** If `App (Option ["-o"] "FILE") (Flag ["-v"])` receives args `["-v", "-o", "file"]`, the tree search must match Flag first (one arg), then Option (two args). `consumeArgs` must handle variable consumption correctly.

3. **`Alt` backtracking depth:** Deep `Alt` trees (e.g., many subcommands) could cause stack issues. Not a concern for MVP.

4. **`CompletionInvoked` handling:** Currently a stub in `ParseResult`. Should `runParser` check for `--help` or `--bash-completion` before parsing? Probably yes, in `execParser`.

## Definition of Done

- [ ] `Fail` constructor added to `Parser` GADT
- [ ] `Applicative` and `Alternative` instances complete in `Types.idr`
- [ ] `matchArg` compiles and handles all `Parser` constructors
- [ ] `consumeArgs` compiles and recursively reduces parser trees
- [ ] `runParser` returns `Success` or `Failure` for all inputs
- [ ] `execParser` reads `getArgs` and calls `runParser`
- [ ] `customExecParser` handles errors with `exitWithError`
- [ ] Clean build: `rm -rf build/ttc/ && idris2 --build optparse-applicative.ipkg` passes
- [ ] No holes remain in `Run.idr`

## Next Steps After Run.idr

1. **`Error.idr`** — implement `renderError` and formatters (needed by `customExecParser`).
2. **`Help.idr`** — implement `usage` and `helpText` (introspects `Parser` tree).
3. **`Builder.idr`** — fill `subparser []` with `empty`/`Fail`.
4. **`Subparser.idr`** — connect to `Builder.subparser`.
