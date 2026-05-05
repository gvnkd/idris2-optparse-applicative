module Options.Applicative.Builder
import Data.List
import Options.Applicative.Types

||| Create a string option parser with the given names.
export strOption : (names : List String) -> Parser String
strOption names =
  Option names "ARG" Nothing

||| Create a boolean flag parser with the given names.
export flag' : (names : List String) -> Parser Bool
flag' names =
  Flag names Nothing

||| Create an argument parser with the given metavar.
export argument : (metavar : String) -> Parser String
argument metavar =
  Argument metavar Nothing

||| Create an option parser with a default value.
export option : (names : List String) -> (defaultValue : String) -> Parser
                                                                      String
option names defaultValue =
  Alt (Option names "ARG" Nothing) (Pure defaultValue)

||| Create a subcommand parser from a list of named parsers.
export subparser : List (String, Parser a) -> Parser a
subparser [] =
  Fail
subparser ((name, p) :: ps) =
  Alt p (subparser ps)

||| Helper to create a single named subcommand.
export command : String -> Parser a -> (String, Parser a)
command name p =
  (name, p)

||| Convert a parser to a program with help flag.
export info : Parser a -> String -> Parser a
info p desc =
  p
