module Options.Applicative.Types
import Data.List

||| A CLI parser represented as a free applicative functor.
||| This GADT can be interpreted for parsing or introspected for help generation.
public export
data Parser : Type -> Type where
  Flag : (names : List String) -> (helpText : Maybe String) -> Parser Bool
  Option : (names : List String)
             -> (metavar : String) -> (helpText : Maybe String) -> Parser String
  Argument : (metavar : String) -> (helpText : Maybe String) -> Parser String
  Command : (name : String) -> Parser a -> Parser a
  Pure : a -> Parser a
  App : Parser (a -> b) -> Parser a -> Parser b
  Alt : Parser a -> Parser a -> Parser a
  Fail : Parser a
-- Primitive parsers with optional help metadata
-- Subcommand scoping: tags a parser with its command name for dispatch routing
-- Combinators
||| Errors that can occur during parsing.
public export
data ParseError : Type where
  MissingOption : String -> ParseError
  InvalidOption : String -> String -> ParseError
  UnexpectedError : String -> ParseError

||| Result of parsing command-line arguments.
public export
data ParseResult : Type -> Type where
  Success : a -> ParseResult a
  Failure : ParseError -> ParseResult a
  CompletionInvoked : ParseResult a

||| The result of running a single parser step.
public export
data StepResult : Type -> Type where
  StepSuccess : Parser a -> a -> List String -> StepResult a
  StepFailure : ParseError -> StepResult a
  StepMore : Parser a -> List String -> StepResult a

public export
implementation Functor Parser where
  map f p =
    case p of
      Flag names h =>
        App (Pure f) (Flag names h)
      Option nm mv h =>
        App (Pure f) (Option nm mv h)
      Argument mv h =>
        App (Pure f) (Argument mv h)
      Command n px =>
        Command n (map f px)
      Pure x =>
        Pure (f x)
      App pf pa =>
        App (map (\gs => \x => f (gs x)) pf) pa
      Alt p1 p2 =>
        Alt (map f p1) (map f p2)
      Fail =>
        Fail

public export
implementation Applicative Parser where
  pure =
    Pure
  pf <*> pa =
    App pf pa

public export
implementation Alternative Parser where
  empty =
    Fail
  p1 <|> p2 =
    Alt p1 (force p2)
-- ||| Two-Pass Parsing Infrastructure (Phase 1)
||| Collected bindings from Pass 1 (global argument scan).
public export
record ParseBindings where
  constructor MkParseBindings
  flags : List (List String, Bool)
  options : List (List String, Maybe String)
  positionals : List String
-- Flag names and whether they were present
-- Option names and their values
-- Unmatched arguments in order
||| Result of Pass 1: either successful bindings or a collection error.
public export
data CollectResult : Type where
  Collected : ParseBindings -> CollectResult
  CollectFailure : ParseError -> CollectResult

||| Information about a single help entry extracted from a parser tree.
public export
record HelpEntry where
  constructor MkHelpEntry
  optionNames : List String
  metavar : String
  description : Maybe String
-- e.g. ["--output", "-o"]
-- e.g. "FILE", "ARG"
-- optional help text
||| Result of help text generation for a parser tree.
public export
record HelpInfo where
  constructor MkHelpInfo
  progName : String
  header : String
  globalOpts : List HelpEntry
  subCmds : List (String, List HelpEntry)
-- program name from usage line
-- short description
-- top-level/global options and flags
-- grouped per subcommand
