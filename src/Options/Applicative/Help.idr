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

-- ||| Collect leaf nodes from a parser tree into help entries.
export collectEntries : Parser a -> List HelpEntry
collectEntries p = case p of
    Flag names         => MkHelpEntry names "" Nothing :: []
    Option nm mv       => MkHelpEntry nm mv Nothing :: []  
    Argument mv        => MkHelpEntry ["<pos>"] mv Nothing :: []
    Pure _             => []
    App pf pa          => collectEntries pf ++ collectEntries pa
    Alt p1 p2          => collectEntries p1 ++ collectEntries p2
    Fail               => []

-- ||| Attach a help description to any parser node (preserves semantics).
export mhelp : Parser a -> String -> Parser a
mhelp p _ = p

-- ||| Override metavar for argument-style parsers.  
export metavarMod : Parser String -> String -> Parser String
metavarMod (Option nm _) mv' = Option nm mv'
metavarMod (Argument _) mv'  = Argument mv'
metavarMod p _               = p

-- ||| Generate usage line: progName + arg placeholders.
export usageLine : String -> Parser a -> String
usageLine pname p = "Usage: " ++ pname ++ argsStr

  where
    -- Check if entry represents a positional argument placeholder
    isPositional : HelpEntry -> Bool
    isPositional entry = ["<pos>"] `isPrefixOf` entry.optionNames

    -- Extract unique positional metavariables from collected entries  
    positions : List String
    positions = nub (map (\e => e.metavar) (filter isPositional $ collectEntries p))

    -- Build bracketed arg placeholders for usage line (limit to 3 repeats max)
    argsStr : String
    argsStr = if null positions then "" else " " ++ unwords (take 3 $ map (\m => "[" ++ m ++ "]") positions)

-- ||| Format full help text with header, entries, and alignment.  
export formatHelp : HelpInfo -> String
formatHelp info = headerLine ++ "\n" ++ usageLineLocal ++ "\n" ++ optionsLocal ++ "\n"

  where
    -- Helper: check if entry already appears in deduplicated list  
    alreadySeen : HelpEntry -> List HelpEntry -> Bool
    alreadySeen new seen = any (\s => s.optionNames == new.optionNames && s.metavar == new.metavar) seen

    -- Deduplicate entries to avoid manyUpTo expansion noise  
    uniqueEntries : List HelpEntry
    uniqueEntries = foldl dedup [] info.entries
      where
        dedup : List HelpEntry -> HelpEntry -> List HelpEntry
        dedup acc entry = if alreadySeen entry acc then acc else entry :: acc

    -- Check if entry is positional vs named option/flag  
    isPos : HelpEntry -> Bool
    isPos entry = ["<pos>"] `isPrefixOf` entry.optionNames

    -- Combine option names and metavar into left column text
    namesStr : HelpEntry -> String  
    namesStr entry = unwords entry.optionNames ++ if null entry.metavar then "" else " <" ++ entry.metavar ++ ">"

    -- Extract description text for right column  
    descStr : HelpEntry -> String
    descStr e = case e.description of
        Nothing => ""
        Just d  => d

    -- Format individual help entry into aligned column pair
    formatEntry : HelpEntry -> (String, String)
    formatEntry e = (namesStr e, descStr e)

    -- Format optional argument placeholders for usage line  
    argsStr : String
    argsStr = unwords (map (\e => "[" ++ e.metavar ++ "]") (filter isPos uniqueEntries))

    -- Usage synopsis from collected parser entries
    usageLineLocal : String
    usageLineLocal = "Usage: " ++ info.progName ++ argsStr

    -- Header line with program name and optional description
    headerLine : String
    headerLine = if null info.header then info.progName else info.progName ++ ": " ++ info.header

    -- Format all entries as aligned columns using existing helper  
    optionsLocal : String
    optionsLocal = alignColumns (map formatEntry uniqueEntries)
