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
mkConfig : List (String, Parser a) -> SubparserConfig a
mkConfig cmds = MkSubparserConfig cmds Nothing
