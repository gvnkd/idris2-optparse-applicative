# Design: Subcommand-Aware Two-Pass Parser

## Problem Statement

The two-pass parser (`collectBindings` + `applyBindings`) treats the entire `Parser` tree as a flat namespace for flags and options. This breaks subcommand scoping:

```idris
mainParser = pure (,)
          <*> argument "COMMAND"           -- "clean", "status", etc.
          <*> subparser
                [ ("clean", cleanParser)   -- cleanParser has flag' ["-n", "--dry-run"]
                , ("status", statusParser) -- statusParser has no -n flag
                ]
```

**Current broken behavior:**
```bash
./prog -n              # -n NOT matched globally → becomes positional → no error
./prog --dry-runyy     # unknown flag → becomes positional → silent swallow
./prog clean -n        # "clean" parsed as positional, -n also positional
```

**Root cause:** `subparser` in `Builder.idr` discards command names:

```idris
subparser : List (String, Parser a) -> Parser a
subparser []            = Fail
subparser ((name, p) :: ps) = Alt p (subparser ps)  -- 'name' is LOST
```

The `Parser` GADT has no `Subcommand` constructor. `getAllFlagNames` traverses ALL `Alt` branches and collects flags from EVERY subcommand into a single flat list. `collectBindings` then checks this flat list, so `-n` IS found globally... but `applyBindings` has no idea WHICH subcommand was selected, so it can't scope correctly.

Worse: `getAllFlagNames` DOES find `-n` (it's in the tree), so `checkFlag` returns True. But `applyBindings` applies it to the WRONG branch or fails because the `Alt` fallback picks the wrong subcommand.

## Diagnosis

The two-pass parser has **three** separate bugs that interact:

1. **Command names are discarded** — `subparser` throws away the `String` name
2. **Flag collection is globally flat** — all subcommand flags mixed together
3. **No validation of unknown flags** — anything starting with `-` that isn't matched becomes a positional silently

## Solution: Add `Command` Constructor to Parser GADT

### GADT Change

```idris
data Parser : Type -> Type where
  Flag       : List String -> Parser Bool
  Option     : List String -> String -> Parser String
  Argument   : String -> Parser String
  Pure       : a -> Parser a
  App        : Parser (a -> b) -> Parser a -> Parser b
  Alt        : Parser a -> Parser a -> Parser a
  Command    : String -> Parser a -> Parser a  -- NEW
  Fail       : Parser a
```

`Command name p` wraps a subcommand parser with its dispatch name.

### Builder Change

```idris
subparser : List (String, Parser a) -> Parser a
subparser []            = Fail
subparser ((name, p) :: ps) = Alt (Command name p) (subparser ps)
```

Command names are now preserved in the tree.

### Required Pattern Match Updates

Every `case p of` in the codebase needs a `Command` branch:

| Module | Function | New Branch |
|--------|----------|------------|
| `Types.idr` | `Functor.map` | `Command n p => Command n (map f p)` |
| `Types.idr` | `Applicative.<*>` | handled by `App` |
| `Run.idr` | `finalizeParser` | `Command _ p => finalizeParser p` |
| `Run.idr` | `getAllFlagNames` | `Command _ p => getAllFlagNames p` (or `[]` for scoped) |
| `Run.idr` | `getAllOptionNames` | `Command _ p => getAllOptionNames p` (or `[]` for scoped) |
| `Run.idr` | `consumeArgs` (legacy) | `Command n p => consumeArgs p args` |
| `BashCompletion.idr` | `optionNames` | `Command _ p => optionNames p` |
| `Help.idr` | (future) | `Command n p => ...` |

### Two-Pass Parser Redesign

#### Pass 1: Scoped Collection

`collectBindings` becomes a recursive function that tracks the **active command scope**:

```idris
collectBindings : Parser a -> List String -> CollectResult
collectBindings p args = 
  case findCommand p args of
    -- Global parser (no subcommands at top level)
    Nothing => scanGlobal p args
    -- Subcommand selected: only collect from that branch
    Just (cmdName, cmdParser, remainingArgs) => scanScoped cmdParser remainingArgs
```

**Key insight:** Subcommand dispatch happens ONCE, before flag collection. The command name is consumed from positionals, then only that command's parser participates in flag/option collection.

```idris
||| Try to find a Command match at the top level of the parser.
||| Returns Just (name, innerParser, remainingArgs) if a command is matched.
findCommand : Parser a -> List String -> Maybe (String, Parser a, List String)
findCommand p [] = Nothing
findCommand p (arg :: rest) = case p of
  Command name inner => 
    if arg == name 
    then Just (name, inner, rest)
    else findCommand inner (arg :: rest)  -- nested commands? or: Nothing
  Alt p1 p2 => case findCommand p1 (arg :: rest) of
    Just r  => Just r
    Nothing => findCommand p2 (arg :: rest)
  App pf pa => -- check if left side is a command parser
    case findCommand pf (arg :: rest) of
      Just (name, inner, rest') => 
        -- The command is the function side of App, e.g., App (Command "clean" (Pure f)) pa
        -- We need to reconstruct: App inner pa
        Just (name, App inner pa, rest')
      Nothing => Nothing  -- don't search pa; commands are always on the left in applicative chains
  _ => Nothing
```

**Assumption:** Commands are parsed on the LEFT side of `App` chains (standard applicative pattern: `pure f <*> command <*> args`).

#### Pass 1a: Global Scan (no subcommands)

```idris
scanGlobal : Parser a -> List String -> CollectResult
scanGlobal p args = 
  let globalFlags   = getGlobalFlagNames p
      globalOptions = getGlobalOptionNames p
  in go (MkParseBindings [] [] []) args
  
  where
    go bnds [] = Collected bnds
    go bnds (arg :: rest) =
      if arg `elem` globalFlags then
        go (setFlag arg bnds) rest
      else if arg `elem` globalOptions then
        case rest of
          val :: rest' => go (setOption arg val bnds) rest'
          []           => CollectFailure (MissingOption "Option value required")
      else if isFlagLike arg then
        CollectFailure (UnexpectedError ("Unknown flag: " ++ arg))
      else
        go (addPositional arg bnds) rest
```

`getGlobalFlagNames` only collects from non-`Command` branches:

```idris
getGlobalFlagNames : Parser a -> List String
getGlobalFlagNames (Flag names)    = names
getGlobalFlagNames (Command _ _)   = []  -- SCOPED: don't collect from subcommands
getGlobalFlagNames (App f x)       = getGlobalFlagNames f ++ getGlobalFlagNames x
getGlobalFlagNames (Alt p1 p2)     = getGlobalFlagNames p1 ++ getGlobalFlagNames p2
getGlobalFlagNames _               = []
```

#### Pass 1b: Scoped Scan (subcommand active)

```idris
scanScoped : Parser a -> List String -> CollectResult
scanScoped p args = 
  let scopedFlags   = getScopedFlagNames p
      scopedOptions = getScopedOptionNames p
  in go (MkParseBindings [] [] []) args

getScopedFlagNames : Parser a -> List String
getScopedFlagNames (Flag names)    = names
getScopedFlagNames (Command _ p)   = getScopedFlagNames p  -- drill into command
getScopedFlagNames (App f x)       = getScopedFlagNames f ++ getScopedFlagNames x
getScopedFlagNames (Alt p1 p2)     = getScopedFlagNames p1 ++ getScopedFlagNames p2
getScopedFlagNames _               = []
```

#### Pass 2: Scoped Application

`applyBindings` also needs to know which command is active:

```idris
applyBindings : Parser a -> ParseBindings -> ParseResult a
applyBindings p bnds = case go p bnds.positionals of
  Just (x, [])    => Success x
  Just (x, rest)  => Failure (UnexpectedError ("Extra arguments: " ++ show rest))
  Nothing         => Failure (MissingOption "Unsatisfied parser")

  where
    go : Parser x -> List String -> Maybe (x, List String)
    go (Pure x)       pos = Just (x, pos)
    go Fail           pos = Nothing
    go (Flag names)   pos = 
      case findFlag names bnds of
        Just v  => Just (v, pos)
        Nothing => Just (False, pos)
    go (Option nm _)  pos =
      case findOption nm bnds of
        Just (Just v) => Just (v, pos)
        _             => Nothing
    go (Argument _)   pos =
      case pos of
        (h :: t) => Just (h, t)
        []       => Nothing
    go (App pf px)    pos = do
      (f, pos1) <- go pf pos
      (x, pos2) <- go px pos1
      pure (f x, pos2)
    go (Alt p1 p2)    pos =
      case go p1 pos of
        Just r  => Just r
        Nothing => go p2 pos
    go (Command _ p)  pos = go p pos  -- transparent wrapper
```

### `Command` Semantics

- `Command name p` is a **transparent wrapper** during tree reduction
- It carries the dispatch name for Pass 1 routing only
- During Pass 2, it's unwrapped and treated as `p`
- It does NOT participate in `Alt` fallback — `Alt (Command "clean" p1) (Command "status" p2)` dispatches on name, not on parse success

## Alternative: No GADT Change (Heuristic Approach)

If modifying the GADT is too invasive, we can use heuristics:

1. **Assume** that `Alt` branches at certain depths represent subcommands
2. **Assume** the first `Argument` or `Pure` in each `Alt` branch is the command selector
3. Use `Builder.command` metadata to inject names as `Pure` values

But this is fragile and breaks if the applicative chain structure changes. The GADT approach is explicit and robust.

## Impact Analysis

### Files Modified

| File | Changes | Lines |
|------|---------|-------|
| `Types.idr` | Add `Command` constructor, update `Functor.map` | ~5 |
| `Builder.idr` | Update `subparser` to wrap with `Command` | ~2 |
| `Run.idr` | Add `findCommand`, update `collectBindings` for scoping, add `Command` branches | ~30 |
| `BashCompletion.idr` | Add `Command` branch to `optionNames` | ~1 |
| `tests/` | Add subcommand tests | ~20 |

### Backward Compatibility

- `command` function signature unchanged: `String -> Parser a -> (String, Parser a)`
- `subparser` signature unchanged: `List (String, Parser a) -> Parser a`
- User-facing API: no changes
- Internal: all pattern matches on `Parser` gain a `Command` branch

### Test Plan

```bash
# Global flags (no subcommand) — unchanged behavior
./prog -v                    # works

# Subcommand dispatch
./prog clean -n              # clean selected, -n consumed as flag
./prog status -n             # ERROR: -n is not a flag for status
./prog clean --dry-runyy     # ERROR: unknown flag
./prog unknown-cmd           # ERROR: unknown command
./prog clean file.txt        # clean selected, file.txt is positional
./prog -n clean              # ERROR: -n before command (or: global flag, then command)
```

## Implementation Order

1. **Add `Command` to GADT** in `Types.idr`
2. **Update `subparser`** in `Builder.idr` to wrap with `Command`
3. **Update all pattern matches** across codebase (compiler will tell you where)
4. **Implement `findCommand`** in `Run.idr`
5. **Split `collectBindings`** into `scanGlobal` and `scanScoped`
6. **Add `getGlobalFlagNames`** / `getScopedFlagNames`
7. **Add unknown-flag validation** in `scanGlobal`
8. **Update `applyBindings`** to handle `Command`
9. **Add subcommand tests**
10. **Update golden files**

## Risk: GADT Constructor Count

Adding `Command` brings the `Parser` GADT to 8 constructors. Idris2 handles this fine, but every `case` expression gains a branch. This is mechanical but tedious.

Mitigation: use `replaceAll` or sed to bulk-add `Command` branches after the first compile error.

## Definition of Done

- [ ] `Command` constructor added to `Parser` GADT
- [ ] `subparser` wraps branches with `Command`
- [ ] All pattern matches handle `Command`
- [ ] `collectBindings` dispatches on command names before flag collection
- [ ] `getGlobalFlagNames` excludes `Command` branches
- [ ] Unknown flag-like args produce `UnexpectedError`, not silent positional
- [ ] `./prog clean -n` works (command dispatch + scoped flag)
- [ ] `./prog status -n` fails (flag not in scope)
- [ ] `./prog --unknown` fails (unknown flag)
- [ ] All existing 6 golden tests still pass
- [ ] New subcommand golden tests added
- [ ] Clean build with zero holes
