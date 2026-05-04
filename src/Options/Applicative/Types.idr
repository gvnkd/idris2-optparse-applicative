||| Core types for optparse-applicative.
module Options.Applicative.Types

import Data.List

||| A CLI parser represented as a free applicative functor.
||| This GADT can be interpreted for parsing or introspected for help generation.
public export
data Parser : Type -> Type where
  -- Primitive parsers
  Flag      : (names : List String) -> Parser Bool
  Option    : (names : List String) -> (metavar : String) -> Parser String
  Argument  : (metavar : String) -> Parser String
  -- Combinators
  Pure      : a -> Parser a
  App       : Parser (a -> b) -> Parser a -> Parser b
  Alt       : Parser a -> Parser a -> Parser a
  Fail      : Parser a

||| Errors that can occur during parsing.
public export
data ParseError : Type where
  MissingOption   : String -> ParseError
  InvalidOption   : String -> String -> ParseError
  UnexpectedError : String -> ParseError

||| Result of parsing command-line arguments.
public export
data ParseResult : Type -> Type where
  Success           : a -> ParseResult a
  Failure           : ParseError -> ParseResult a
  CompletionInvoked : ParseResult a

||| The result of running a single parser step.
public export
data StepResult : Type -> Type where
  StepSuccess : Parser a -> a -> List String -> StepResult a
  StepFailure : ParseError -> StepResult a
  StepMore    : Parser a -> List String -> StepResult a

||| Make Parser a Functor.
public export
Functor Parser where
  map f p =
    case p of
      Flag names         => App (Pure f) (Flag names)
      Option nm mv       => App (Pure f) (Option nm mv)
      Argument mv        => App (Pure f) (Argument mv)
      Pure x             => Pure (f x)
      App pf pa          => App (map (\gs, x => f (gs x)) pf) pa
      Alt p1 p2          => Alt (map f p1) (map f p2)
      Fail               => Fail

||| Make Parser an Applicative.
public export
Applicative Parser where
  pure = Pure
  pf <*> pa = App pf pa

||| Make Parser an Alternative.
public export
Alternative Parser where
  empty = Fail
  p1 <|> p2 = Alt p1 (force p2)

-- ||| Two-Pass Parsing Infrastructure (Phase 1)

||| Collected bindings from Pass 1 (global argument scan).
public export
record ParseBindings where
  constructor MkParseBindings
  flags       : List (List String, Bool)       -- Flag names and whether they were present
  options     : List (List String, Maybe String) -- Option names and their values  
  positionals : List String                    -- Unmatched arguments in order

||| Result of Pass 1: either successful bindings or a collection error.
public export
data CollectResult : Type where
  Collected      : ParseBindings -> CollectResult
  CollectFailure : ParseError -> CollectResult

||| Information about a single help entry extracted from a parser tree.
public export
record HelpEntry where
  constructor MkHelpEntry
  optionNames  : List String        -- e.g. ["--output", "-o"]
  metavar      : String             -- e.g. "FILE", "ARG"  
  description  : Maybe String       -- optional help text

||| Result of help text generation for a parser tree.
public export
record HelpInfo where
  constructor MkHelpInfo
  progName     : String            -- program name from usage line
  header       : String            -- short description
  entries      : List HelpEntry    -- all leaf options/flags/arguments

