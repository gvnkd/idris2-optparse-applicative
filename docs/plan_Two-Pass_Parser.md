# Plan: Two-Pass Parser for Positional Interleaving

## Problem Statement

The current single-pass parser in `Run.idr` processes CLI arguments via recursive descent: `consumeArgs` walks the argument list left-to-right while simultaneously traversing the `Parser` tree. When a leaf (e.g., `Flag`) doesn't match the current argument, it skips it via `consumeArgs p rest` — permanently losing that argument to other leaves in the tree.

### Concrete Failure Example

```idris
parser : Parser (Bool, String)
parser = (,) <$> flag' ["-v"] <*> option ["-o"] "stdout"
```

With arguments `["-o", "file.txt", "-v"]`:
1. `reduceApp` processes `pf` (the `flag' ["-v"]`) first
2. `consumeArgs` on `Flag ["-v"]` sees `"-o"`, doesn't match, skips to `"file.txt"`
3. Still doesn't match, skips to `"-v"`, matches, returns `True`
4. `goReduction` processes `pa` (the `option ["-o"]`) with **empty** remaining args
5. Option falls back to default `"stdout"`
6. Result: `(True, "stdout")` — **WRONG**, option value `file.txt` was lost

The correct result should be `(True, "file.txt")`.

### Root Cause

Arguments are consumed eagerly by the first leaf that encounters them in tree-traversal order. If `pf` is a `Flag` and `pa` is an `Option`, the flag leaf skips over option args until it finds its own name. Those skipped args are never offered to the option leaf.

## Solution: Two-Pass Parser

Separate argument matching from tree reduction:

1. **Pass 1 — Collect:** Scan all arguments, match named arguments (flags/options) by their explicit names, build a binding map. Remaining arguments become positionals.
2. **Pass 2 — Apply:** Walk the `Parser` tree, assign values from the binding map or positional queue, apply defaults via `finalizeParser`.

This is the standard approach in mature CLI parsers (Haskell optparse-applicative, Python argparse, etc.): named arguments are resolved globally first, then positionals are assigned in tree order.

---

## Pass 1: Named Argument Collection

### Input
- `Parser a` — the parser tree (used for introspection, not consumption)
- `List String` — raw CLI arguments

### Output
```idris
record ParseState where
  constructor MkParseState
  flagValues    : List (List String, Bool)        -- (names, wasPresent)
  optionValues  : List (List String, Maybe String) -- (names, maybeValue)
  positionalArgs : List String                     -- unconsumed args
```

### Algorithm

```idris
collectNamed : Parser a -> List String -> ParseState
collectNamed p args = go args (emptyState p)

  where
    -- Initialize state from tree structure
    emptyState : Parser a -> ParseState
    emptyState p = case p of
      Flag names       => MkParseState [(names, False)] [] []
      Option names _   => MkParseState [] [(names, Nothing)] []
      Argument _       => MkParseState [] [] []
      Pure _           => MkParseState [] [] []
      Fail             => MkParseState [] [] []
      App pf pa        => mergeState (emptyState pf) (emptyState pa)
      Alt p1 p2        => mergeState (emptyState p1) (emptyState p2)

    mergeState : ParseState -> ParseState -> ParseState
    mergeState s1 s2 = MkParseState
      (s1.flagValues ++ s2.flagValues)
      (s1.optionValues ++ s2.optionValues)
      []

    -- Collect by scanning args left-to-right
    go : List String -> ParseState -> ParseState
    go [] state = state
    go (arg :: rest) state =
      case findFlag arg state of
        Just state' => go rest state'
        Nothing => case findOption arg rest state of
          Just (state', rest') => go rest' state'
          Nothing => go rest (addPositional arg state)
```

**Key behaviors:**
- **Flags:** When arg matches any flag name, mark that flag as `True`, remove arg
- **Options:** When arg matches any option name, consume next arg as value, remove both
- **Positionals:** Any unmatched arg goes to `positionalArgs`
- **Duplicates:** If a flag appears multiple times, last one wins (or combine if multi-value)
- **`--` separator:** Any args after `--` are treated as positionals exclusively

### Why This Handles Interleaving

Pass 1 scans the **entire** argument list globally. It doesn't care about tree traversal order. Whether `-v` appears before or after `-o file.txt`, both are found and recorded:

```
Args: ["-o", "file.txt", "-v"]

Pass 1 result:
  flagValues    = [("-v", True)]
  optionValues  = [("-o", Just "file.txt")]
  positionalArgs = []
```

The flag and option are matched regardless of position because the scan is global, not recursive.

---

## Pass 2: Tree Application

### Input
- `Parser a` — the parser tree
- `ParseState` — collected bindings from Pass 1

### Output
- `ParseResult a` — success with value or failure with error

### Algorithm

```idris
applyBindings : Parser a -> ParseState -> ParseResult a
applyBindings p state = case go p state of
  (Just val, [])   => Success val
  (Just val, rest) => Failure (UnexpectedError "Extra arguments: " ++ show rest)
  (Nothing, _)     => Failure (MissingOption "Unsatisfied parser")

  where
    go : Parser a -> ParseState -> (Maybe a, List String)
    go p state = case p of
      Flag names =>
        case lookupFlag names state of
          True  => (Just True, state.positionalArgs)
          False => (Just False, state.positionalArgs)  -- default

      Option names _ =>
        case lookupOption names state of
          Just val => (Just val, state.positionalArgs)
          Nothing  => (Nothing, state.positionalArgs)   -- required, fail

      Argument _ =>
        case state.positionalArgs of
          (arg :: rest) => (Just arg, rest)
          []            => (Nothing, [])  -- required, fail

      Pure x => (Just x, state.positionalArgs)

      Fail => (Nothing, state.positionalArgs)

      App pf pa => case go pf state of
        (Just f, pos1) => case go pa (updatePositionals state pos1) of
          (Just x, pos2) => (Just (f x), pos2)
          (Nothing, pos2) => (Nothing, pos2)
        (Nothing, pos1) => (Nothing, pos1)

      Alt p1 p2 => case go p1 state of
        (Just x, pos1) => (Just x, pos1)
        (Nothing, _)   => go p2 state
```

**Key behaviors:**
- `Flag` — looks up in `flagValues`, defaults to `False`
- `Option` — looks up in `optionValues`, fails if required and missing
- `Argument` — consumes from `positionalArgs` queue in order
- `App` — reduces `pf` first, then `pa` with remaining positionals
- `Alt` — tries left branch, falls back to right on failure
- Positionals are threaded through the tree: `pf` consumes some, `pa` gets the rest

### Positionals Handling

Positionals are assigned in **tree-traversal order** (left-to-right, depth-first), which is the correct semantic for applicative composition:

```idris
parser = pure MkConfig
      <*> flag' ["-v"]
      <*> option ["-o"] "stdout"
      <*> manyUpTo 16 (argument "FILE")
```

With args `["-v", "file1.txt", "-o", "out.txt", "file2.txt"]`:

**Pass 1:**
```
flagValues    = [("-v", True)]
optionValues  = [("-o", Just "out.txt")]
positionalArgs = ["file1.txt", "file2.txt"]
```

**Pass 2:**
1. `Flag ["-v"]` → `True` (from flagValues), positionals remain `["file1.txt", "file2.txt"]`
2. `Option ["-o"]` → `"out.txt"` (from optionValues), positionals remain `["file1.txt", "file2.txt"]`
3. `manyUpTo 16 (argument "FILE")` → consumes `["file1.txt", "file2.txt"]` from positionals
4. Result: `MkConfig True "out.txt" ["file1.txt", "file2.txt"]` ✓

---

## State Threading for Positionals

The subtlety in Pass 2 is that positionals must be consumed in order, and the consumption state must be threaded through the tree. We use a functional state pattern (not `State` monad, to stay total and pure):

```idris
-- Instead of ParseResult, use a function that threads positionals
applyTree : Parser a -> List String -> (Maybe a, List String)
```

Where the `List String` in the result is the **remaining** positionals after this subtree has consumed what it needs.

For `App pf pa`:
```idris
App pf pa =>
  let (mf, pos1) = applyTree pf positionals in
  let (mx, pos2) = applyTree pa pos1 in
  case (mf, mx) of
    (Just f, Just x) => (Just (f x), pos2)
    _                => (Nothing, pos2)
```

This ensures positionals are consumed left-to-right in the applicative tree.

---

## Handling `Alt` with Positionals

`Alt` is the hardest case because positionals consumed by the left branch should NOT be available to the right branch if the left branch succeeds:

```idris
Alt p1 p2 =>
  case applyTree p1 positionals of
    (Just x, pos1) => (Just x, pos1)  -- Left succeeded, use its positionals
    (Nothing, _)   => applyTree p2 positionals  -- Left failed, try right with ALL positionals
```

Note: if left fails after consuming some positionals, we still try right with the **original** positionals. This is correct because `Alt` represents choice — either left matches or right matches, not both.

However, there's a subtle issue: what if left partially succeeds (consumes some positionals) then fails on a later leaf? In that case, the positionals it consumed are "lost" to the right branch. This is acceptable for CLI parsing because:
1. `Alt` branches typically represent mutually exclusive choices (subcommands, optional flags)
2. Each branch usually has its own distinct argument pattern
3. If left consumes positionals and then fails, it's a genuine parse error

For safety, we could track the "tentative" consumption and roll back, but that's overkill for typical CLI use cases.

---

## Integration with Existing Types

### New Types in `Types.idr`

```idris
||| Collected bindings from Pass 1.
public export
record ParseBindings where
  constructor MkBindings
  flags   : List (List String, Bool)
  options : List (List String, String)
  positionals : List String

||| Result of Pass 1: either bindings or a parse error.
public export
data CollectResult : Type where
  Collected : ParseBindings -> CollectResult
  CollectFailure : ParseError -> CollectResult
```

### Modified `runParser`

```idris
export
runParser : Parser a -> List String -> ParseResult a
runParser p args =
  case collectBindings p args of
    CollectFailure err => Failure err
    Collected bindings => applyBindings p bindings
```

The old `consumeArgs` / `StepResult` machinery can be **deprecated** or kept for backward compatibility, but the primary interface becomes the two-pass pipeline.

---

## Edge Cases and Fixes

### 1. Duplicate Flags

```bash
./prog -v -v
```

**Current behavior:** Flag appears twice, first match wins, second is ignored.
**Desired behavior:** For `manyUpTo`, both should be collected. For single `flag'`, last wins (or error if strict).

**Fix in Pass 1:** When collecting flags, append to a count. In Pass 2, `Flag` checks if count > 0.

### 2. Missing Option Values

```bash
./prog -o
```

**Pass 1 behavior:** Sees `-o`, looks for next arg, finds none. Returns `CollectFailure (MissingOption "Option value required")`.

**Fix:** In `collectNamed`, when matching an option, check if `rest` is non-empty. If empty, return `CollectFailure` immediately.

### 3. Positional That Looks Like a Flag

```bash
./prog -- -v
```

Here `-v` is a positional, not a flag. Standard Unix convention: `--` stops option parsing.

**Fix in Pass 1:** When scanning args, if `--` is encountered, stop named-argument collection. All remaining args go to `positionals`.

### 4. Ambiguous Short Options

```bash
./prog -abc
```

Where `-a`, `-b`, `-c` are separate flags. Standard convention: combined short options.

**Fix in Pass 1:** When arg starts with single `-` and has length > 1, split into individual flags: `-abc` → `-a`, `-b`, `-c`. Then match each against flag names. If any doesn't match a flag, treat the whole thing as a single arg (either option or positional).

### 5. Options with `=` Syntax

```bash
./prog --output=file.txt
```

**Fix in Pass 1:** Check for `=` in option-style args. Split into name and value, match name against option names.

---

## Implementation Order

### Phase 1: Core Two-Pass Infrastructure

1. **Add `ParseBindings` type** to `Types.idr`
2. **Implement `collectBindings`** in new module or `Run.idr`
   - Handle `Flag`, `Option`, `Argument`, `Pure`, `Fail`, `App`, `Alt`
   - Handle `--` separator
   - Handle missing option values
3. **Implement `applyBindings`** in `Run.idr`
   - Handle all constructors
   - Thread positionals through `App`
   - Handle `Alt` fallback correctly
4. **Update `runParser`** to use two-pass pipeline
5. **Update tests** — interleaving tests should now pass

### Phase 2: Enhanced Features

6. **Support combined short options** (`-abc` → `-a -b -c`)
7. **Support `--name=value` syntax**
8. **Handle duplicate flags** (count-based instead of boolean)
9. **Better error messages** (which option was missing, which positional was expected)

### Phase 3: Deprecation

10. **Deprecate `consumeArgs` / `StepResult`** — keep for compatibility but mark as internal
11. **Remove or simplify `matchArg`** — no longer needed for primary path
12. **Update `finalizeParser`** — may need adjustments for new flow

---

## Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|-----------|--------|------------|
| `Alt` positionals rollback | Medium | High | Document that `Alt` branches shouldn't share positional patterns |
| Combined short options break existing tests | Low | Medium | Add as Phase 2, update golden files |
| Performance regression (two passes) | Low | Low | Pass 1 is O(n) scan, Pass 2 is O(tree) walk |
| Backward compatibility | Medium | Medium | Keep old `consumeArgs` as internal, expose new `runParser` |

---

## Definition of Done

- [ ] `runParser` uses two-pass pipeline as primary path
- [ ] Interleaving test passes: `["-o", "file.txt", "-v"]` on `flag' <*> option`
- [ ] All existing 6 golden tests still pass
- [ ] New golden tests added for interleaving edge cases
- [ ] `collectBindings` handles `--` separator
- [ ] `collectBindings` handles missing option values with proper error
- [ ] Positionals are consumed in tree-traversal order
- [ ] `Alt` branches try left first, fallback to right
- [ ] Clean build with zero holes
- [ ] README updated to remove interleaving limitation

---

## Files to Modify

| File | Changes |
|------|---------|
| `Types.idr` | Add `ParseBindings`, `CollectResult` types |
| `Run.idr` | Implement `collectBindings`, `applyBindings`, update `runParser` |
| `tests/interleaved/run` | Should now produce correct output |
| `tests/interleaved/expected` | Update golden file after fix |
| `README.md` | Remove interleaving limitation, document two-pass parser |
| `docs/plan_Two-Pass_Parser.md` | Mark complete |
