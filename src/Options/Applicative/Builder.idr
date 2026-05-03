||| Builder DSL for constructing CLI parsers.
module Options.Applicative.Builder

import Options.Applicative.Types
import Data.List

||| Create a string option parser with the given names.
export
strOption : (names : List String) -> Parser String
strOption names = Option names ?rhs_strOption_metavar

||| Create a boolean flag parser with the given names.
export
flag' : (names : List String) -> Parser Bool
flag' names = ?rhs_flag'

||| Create an argument parser with the given metavar.
export
argument : (metavar : String) -> Parser String
argument metavar = ?rhs_argument

||| Create an option parser with a default value.
export
option : (names : List String) -> (defaultValue : String) -> Parser String
option names defaultValue = ?rhs_option

||| Create a subcommand parser from a list of named parsers.
export
subparser : List (String, Parser a) -> Parser a
subparser commands = ?rhs_subparser

||| Helper to create a single named subcommand.
export
command : String -> Parser a -> (String, Parser a)
command name p = ?rhs_command

||| Convert a parser to a program with help flag.
export
info : Parser a -> String -> Parser a
info p desc = ?rhs_info
