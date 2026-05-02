||| Help text generation for CLI parsers.
module Options.Applicative.Help

import Options.Applicative.Types
import Data.List
import Data.String

||| Generate usage line for a parser.
export
usage : Parser a -> String
usage p = ?rhs_usage

||| Generate full help text for a parser.
export
helpText : Parser a -> String
helpText p = ?rhs_helpText

||| Generate a brief description of available options.
export
optionsDescription : Parser a -> String
optionsDescription p = ?rhs_optionsDescription

||| Align help text columns.
export
alignColumns : List (String, String) -> String
alignColumns rows = ?rhs_alignColumns

||| Format a single option description line.
export
formatOption : String -> Maybe String -> Maybe String -> String
formatOption names helpText metavarText = ?rhs_formatOption
