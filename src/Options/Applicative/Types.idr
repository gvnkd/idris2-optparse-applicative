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
  StepSuccess : a -> List String -> StepResult a
  StepFailure : ParseError -> StepResult a
  StepMore    : Parser a -> List String -> StepResult a

||| Make Parser a Functor.
Functor Parser where
  map f p = ?rhs_map

||| Make Parser an Applicative.
Applicative Parser where
  pure = Pure
  pf <*> pa = ?rhs_ap

||| Make Parser an Alternative.
Alternative Parser where
  empty = ?rhs_empty
  p1 <|> p2 = ?rhs_alt


