||| Bash shell completion script generation.
module Options.Applicative.BashCompletion

import Options.Applicative.Types
import Data.List
import Data.String

||| Generate a bash completion script for a parser.
export
bashCompletionScript : String -> Parser a -> String
bashCompletionScript progName p = ?rhs_bashCompletionScript

||| Generate completion words for the current parser state.
export
completionWords : Parser a -> List String -> List String
completionWords p args = ?rhs_completionWords

||| Generate option names for completion.
export
optionNames : Parser a -> List String
optionNames p = ?rhs_optionNames

||| Generate subcommand names for completion.
export
subcommandNames : Parser a -> List String
subcommandNames p = ?rhs_subcommandNames

||| Check if bash completion is requested.
export
isCompletionRequest : List String -> Bool
isCompletionRequest args = ?rhs_isCompletionRequest
