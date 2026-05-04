||| Subcommand support for CLI parsers.
module Options.Applicative.Subparser

import Options.Applicative.Types
import Options.Applicative.Builder
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

||| Set the program description for a subparser.
export
progDesc : String -> SubparserConfig a -> SubparserConfig a
progDesc desc (MkSubparserConfig cmds _) = MkSubparserConfig cmds (Just desc)

||| Build a subparser from configuration.
export
mkSubparser : SubparserConfig a -> Parser a
mkSubparser (MkSubparserConfig cmds _) = cmdList cmds

  where
    cmdList : List (String, Parser a) -> Parser a
    cmdList []          = Fail
    cmdList ((n, p)::r) = Alt (Command n p) (cmdList r)

||| Lookup a command by name.
export
lookupCommand : String -> SubparserConfig a -> Maybe (Parser a)
lookupCommand name (MkSubparserConfig cmds _) = findCmd name cmds

  where
    findCmd : String -> List (String, Parser a) -> Maybe (Parser a)
    findCmd _ []               = Nothing
    findCmd n ((n', p) :: ps) = case n == n' of
        True  => Just p
        False => findCmd n ps
