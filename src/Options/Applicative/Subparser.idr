||| Subcommand support for CLI parsers.
module Options.Applicative.Subparser

import Options.Applicative.Types
import Data.List

||| A map of command names to their parsers.
public export
record SubparserConfig a where
  constructor MkSubparserConfig
  commands : List (String, Parser a)
  progDesc : Maybe String

||| Create a subparser configuration.
export
commands : List (String, Parser a) -> SubparserConfig a
commands cmds = ?rhs_commands

||| Set the program description for a subparser.
export
progDesc : String -> SubparserConfig a -> SubparserConfig a
progDesc desc config = ?rhs_progDesc

||| Build a subparser from configuration.
export
mkSubparser : SubparserConfig a -> Parser a
mkSubparser config = ?rhs_mkSubparser

||| Lookup a command by name.
export
lookupCommand : String -> SubparserConfig a -> Maybe (Parser a)
lookupCommand name config = ?rhs_lookupCommand
