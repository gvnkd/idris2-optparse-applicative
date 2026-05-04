||| Help text generation for CLI parsers.
module Options.Applicative.Help

import Options.Applicative.Types
import Data.List
import Data.String

-- ||| Align help text columns.
export
alignColumns : List (String, String) -> String
alignColumns rows = unlines $ map (\(opt, desc) => opt ++ "    " ++ desc) rows

||| Collect leaf nodes from any parser subtree (used for command help generation).
export
collectEntries' : List HelpEntry -> Parser _ -> List HelpEntry
collectEntries' acc (Flag names h)      = MkHelpEntry names "" h :: acc
collectEntries' acc (Option nm mv h)    = MkHelpEntry nm mv h :: acc
collectEntries' acc (Argument mv h)     = MkHelpEntry ["<pos>"] mv h :: acc
collectEntries' acc (Command _ px)      = collectEntries' acc px
collectEntries' acc (Pure _)            = acc
collectEntries' acc (App pf px)         = collectEntries' (collectEntries' acc pf) px
collectEntries' acc (Alt p1 p2)         = collectEntries' (collectEntries' acc p1) p2
collectEntries' acc Fail                = acc

-- ||| Collect help info from a parser tree, separating global options from per-command ones.
export collectHelpInfo : String -> Parser a -> HelpInfo
collectHelpInfo pname p = MkHelpInfo { progName = pname, header = "", globalOpts = globalEntries, subCmds = cmdGroups }

  where
    -- Collect all top-level/global options first (those outside Command branches)
    globalEntries : List HelpEntry
    globalEntries = collectGlobal [] p

      where
        collectGlobal : List HelpEntry -> Parser _ -> List HelpEntry
        collectGlobal acc (Flag names h)   = MkHelpEntry names "" h :: acc
        collectGlobal acc (Option nm mv h) = MkHelpEntry nm mv h :: acc
        collectGlobal acc (Argument mv h)  = MkHelpEntry ["<pos>"] mv h :: acc
        collectGlobal acc (Command _ _)    = acc
        collectGlobal acc (Pure _)         = acc
        collectGlobal acc (App pf px)      = collectGlobal (collectGlobal acc pf) px
        collectGlobal acc (Alt p1 p2)      = collectGlobal (collectGlobal acc p1) p2
        collectGlobal acc Fail             = acc

    -- Collect per-command entries by traversing Command nodes only
    cmdGroups : List (String, List HelpEntry)
    cmdGroups = collectCmds [] p

      where
        collectCmds : List (String, List HelpEntry) -> Parser _ -> List (String, List HelpEntry)
        collectCmds acc (Command n px) = (n, collectEntries' [] px) :: acc
        collectCmds acc (Alt p1 p2)    = collectCmds (collectCmds acc p1) p2
        collectCmds acc (App pf px)    = collectCmds (collectCmds acc pf) px
        collectCmds acc (Pure _)       = acc
        collectCmds acc _              = acc

-- ||| Attach a help description to any parser node (preserves semantics).
export mhelp : Parser a -> String -> Parser a
mhelp (Flag names _) h         = Flag names (Just h)
mhelp (Option nm mv _) h       = Option nm mv (Just h)
mhelp (Argument mv _) h        = Argument mv (Just h)
mhelp (Command n px) h         = Command n (mhelp px h)
mhelp (Pure x) _               = Pure x
mhelp (App pf pa) h            = App (mhelp pf h) pa
mhelp (Alt p1 p2) h            = Alt (mhelp p1 h) (mhelp p2 h)
mhelp Fail _                   = Fail

-- ||| Override metavar for argument-style parsers.  
export metavarMod : Parser String -> String -> Parser String
metavarMod (Option nm _ h) mv' = Option nm mv' h
metavarMod (Argument _ h) mv'  = Argument mv' h
metavarMod p _               = p

-- ||| Generate usage line: progName + arg placeholders.
export usageLine : String -> Parser a -> String
usageLine pname p = "Usage: " ++ pname ++ argsStr

  where
    -- Collect global options first to extract positionals for usage line generation
    allGlobal : HelpInfo
    allGlobal = collectHelpInfo pname p

    -- Check if entry represents a positional argument placeholder
    isPositional : HelpEntry -> Bool
    isPositional entry = ["<pos>"] `isPrefixOf` entry.optionNames

    -- Extract unique positional metavariables from collected entries
    positions : List String
    positions = nub (map (\e => e.metavar) (filter isPositional allGlobal.globalOpts))

    -- Build bracketed arg placeholders for usage line (limit to 3 repeats max)
    argsStr : String
    argsStr = if null positions then "" else " [" ++ unwords (take 3 $ map (\m => m) positions) ++ "]"

-- ||| Format full help text with header, global opts, and subcommand grouping.  
export formatHelp : HelpInfo -> String
formatHelp info = headerLine ++ "\n" ++ usageLineLocal ++ "\n\nOptions:\n" ++ globalSection ++ if null (map (\(_,opts) => opts) info.subCmds) then "" else "\nSubcommands:\n" ++ cmdSection

  where
    -- Helper: check if entry already appears in deduplicated list  
    alreadySeen : HelpEntry -> List HelpEntry -> Bool
    alreadySeen new seen = any (\s => s.optionNames == new.optionNames && s.metavar == new.metavar) seen

    -- Deduplicate entries to avoid manyUpTo expansion noise  
    uniqueGlobalOpts : List HelpEntry
    uniqueGlobalOpts = foldl dedup [] info.globalOpts
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

    -- Usage synopsis from collected parser entries  
    usageLineLocal : String
    usageLineLocal = "Usage: " ++ info.progName ++ if null uniqueGlobalOpts then "" else " [" ++ unwords (map (\e => "[" ++ e.metavar ++ "]") (filter isPos uniqueGlobalOpts)) ++ "]"

    -- Header line with program name and optional description
    headerLine : String
    headerLine = if null info.header then info.progName else info.progName ++ ": " ++ info.header

    -- Format all global entries as aligned columns using existing helper  
    globalSection : String
    globalSection = "\n" ++ alignColumns (map formatEntry uniqueGlobalOpts)

    -- Format subcommands section with their respective options listed underneath
    cmdSection : String
    cmdSection = concat $ intersperse "\n" $ map (\(name, opts) => "  " ++ name ++ ":" ++ formatCmdOpts opts ++ "\n") info.subCmds

      where
        formatCmdOpts : List HelpEntry -> String
        formatCmdOpts [] = ""
        formatCmdOpts (h :: t) = "\n" ++ concat (intersperse "\n" (map (\e => "    " ++ namesStr e ++ case e.description of Nothing => ""; Just d => "  --  " ++ d) (h :: t)))
