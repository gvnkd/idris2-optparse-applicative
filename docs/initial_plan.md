# Initial Plan: Idris2 optparse-applicative

## Project Structure

### Phase 1: Core Types and Free Applicative (Week 1)

#### Modules
- `Options.Applicative.Types` - Core GADT and result types
- `Options.Applicative.Builder` - DSL combinators  
- `Options.Applicative.Run` - Parser execution
- `Options.Applicative.Help` - Basic help generation

#### Key Types
```idris
data Parser : Type -> Type where
  -- Primitives
  Flag      : (names : List String) -> Parser Bool
  Option    : (names : List String) -> (metavar : String) -> Parser String
  Argument  : (metavar : String) -> Parser String
  -- Combinators
  Pure      : a -> Parser a
  App       : Parser (a -> b) -> Parser a -> Parser b
  Alt       : Parser a -> Parser a -> Parser a

data ParseResult a
  = Success a
  | Failure ParseError
  | CompletionInvoked

data ParseError
  = MissingOption String
  | InvalidOption String String
  | UnexpectedError String
```

### Phase 2: Essential Features (Week 2)

#### Modules
- `Options.Applicative.Modifiers` - Option modifiers (long, short, help, metavar, value)
- `Options.Applicative.Subparser` - Subcommand support
- `Options.Applicative.Error` - Rich error messages

#### Key Features
- Subcommands via `Alternative` branching
- Modifier system for option configuration
- Help rendering with alignment
- Error messages: "Missing required option", "Invalid argument"

### Phase 3: Polish (Weeks 3-4)

#### Modules
- `Options.Applicative.Multi` - Multi-value options
- `Options.Applicative.Env` - Environment variable fallback
- `Options.Applicative.Validation` - Custom validators
- `Options.Applicative.BashCompletion` - Shell completion scripts

#### Key Features
- `--file a --file b` -> `["a", "b"]`
- `MYAPP_HOST` as default for `--host`
- Custom validators, `eitherReader`
- Bash/zsh completion script generation

### Phase 4: Advanced (Optional)

#### Features
- Dependent-type guarantees for required/optional options
- Config file integration
- Man page generation from parser introspection

## Module Dependency Graph

```
Types
  ^
  |
Builder ----> Run ----> Help
  |           |
  v           v
Modifiers  Subparser
  |
  v
Error
```

## File Layout

```
src/
  Options/
    Applicative/
      Types.idr
      Builder.idr
      Modifiers.idr
      Run.idr
      Help.idr
      Subparser.idr
      Error.idr
      Multi.idr
      Env.idr
      Validation.idr
      BashCompletion.idr
```
