||| Help text generation for CLI parsers.
module Options.Applicative.Help

import Options.Applicative.Types
import Data.List
import Data.String

-- ||| Align help text columns.
export
alignColumns : List (String, String) -> String
alignColumns rows = unlines $ map (\(opt, desc) => opt ++ "    " ++ desc) rows

-- ||| Format a single option description line.
export
formatOption : String -> Maybe String -> Maybe String -> String
formatOption names helpText metavarText = names ++ " (" ++ showMetavar ++ ")" ++ showHelp

  where
    showMetavar : String
    showMetavar = case metavarText of
        Nothing => "<arg>"
        Just m  => m

    showHelp : String
    showHelp = case helpText of
        Nothing => ""
        Just h  => " - " ++ h

-- ||| Generate usage line for a parser. (Deferred to Phase 3 due to introspection complexity)
