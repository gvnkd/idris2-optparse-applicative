module Options.Applicative.Help
import Data.List
import Data.String
import Options.Applicative.Types
-- ||| Align help text columns.
export alignColumns : List (String, String) -> String
alignColumns rows =
  unlines $ map (\(opt, desc) => opt ++ "    " ++ desc) rows

||| Collect leaf nodes from any parser subtree (used for command help generation).
export collectEntries' : List HelpEntry -> Parser _ -> List HelpEntry
collectEntries' acc (Flag names h) =
  MkHelpEntry names "" h :: acc
collectEntries' acc (Option nm mv h) =
  MkHelpEntry nm mv h :: acc
collectEntries' acc (Argument mv h) =
  MkHelpEntry ["<pos>"] mv h :: acc
collectEntries' acc (Command _ px) =
  collectEntries' acc px
collectEntries' acc (Pure _) =
  acc
collectEntries' acc (App pf px) =
  collectEntries' (collectEntries' acc pf) px
collectEntries' acc (Alt p1 p2) =
  collectEntries' (collectEntries' acc p1) p2
collectEntries' acc Fail =
  acc
-- ||| Collect help info from a parser tree, separating global options from per-command ones.
export collectHelpInfo : String -> Parser a -> HelpInfo
collectHelpInfo pname p =
  MkHelpInfo {progName = pname} {header = ""} {globalOpts = globalEntries}
    {subCmds = cmdGroups}
  where
    globalEntries : List HelpEntry
    globalEntries =
      collectGlobal [] p
      where
        collectGlobal : List HelpEntry -> Parser _ -> List HelpEntry
        collectGlobal acc (Flag names h) =
          MkHelpEntry names "" h :: acc
        collectGlobal acc (Option nm mv h) =
          MkHelpEntry nm mv h :: acc
        collectGlobal acc (Argument mv h) =
          MkHelpEntry ["<pos>"] mv h :: acc
        collectGlobal acc (Command _ _) =
          acc
        collectGlobal acc (Pure _) =
          acc
        collectGlobal acc (App pf px) =
          collectGlobal (collectGlobal acc pf) px
        collectGlobal acc (Alt p1 p2) =
          collectGlobal (collectGlobal acc p1) p2
        collectGlobal acc Fail =
          acc
    cmdGroups : List (String, List HelpEntry)
    cmdGroups =
      collectCmds [] p
      where
        collectCmds : List (String, List HelpEntry)
                        -> Parser _ -> List (String, List HelpEntry)
        collectCmds acc (Command n px) =
          (n, collectEntries' [] px) :: acc
        collectCmds acc (Alt p1 p2) =
          collectCmds (collectCmds acc p1) p2
        collectCmds acc (App pf px) =
          collectCmds (collectCmds acc pf) px
        collectCmds acc (Pure _) =
          acc
        collectCmds acc _ =
          acc
-- Collect all top-level/global options first (those outside Command branches)
-- Collect per-command entries by traversing Command nodes only
-- ||| Attach a help description to any parser node (preserves semantics).
export mhelp : Parser a -> String -> Parser a
mhelp (Flag names _) h =
  Flag names (Just h)
mhelp (Option nm mv _) h =
  Option nm mv (Just h)
mhelp (Argument mv _) h =
  Argument mv (Just h)
mhelp (Command n px) h =
  Command n (mhelp px h)
mhelp (Pure x) _ =
  Pure x
mhelp (App pf pa) h =
  App (mhelp pf h) pa
mhelp (Alt p1 p2) h =
  Alt (mhelp p1 h) (mhelp p2 h)
mhelp Fail _ =
  Fail
-- ||| Override metavar for argument-style parsers.
export metavarMod : Parser String -> String -> Parser String
metavarMod (Option nm _ h) mv' =
  Option nm mv' h
metavarMod (Argument _ h) mv' =
  Argument mv' h
metavarMod p _ =
  p
-- ||| Generate usage line: progName + arg placeholders.
export usageLine : String -> Parser a -> String
usageLine pname p =
  "Usage: " ++ pname ++ argsStr
  where
    allGlobal : HelpInfo
    allGlobal =
      collectHelpInfo pname p
    isPositional : HelpEntry -> Bool
    isPositional entry =
      ["<pos>"] `isPrefixOf` entry.optionNames
    positions : List String
    positions =
      nub (map (\e => e.metavar) (filter isPositional allGlobal.globalOpts))
    argsStr : String
    argsStr =
      if null positions
        then ""
        else " [" ++ unwords (take 3 $ map (\m => m) positions) ++ "]"
-- Collect global options first to extract positionals for usage line generation
-- Check if entry represents a positional argument placeholder
-- Extract unique positional metavariables from collected entries
-- Build bracketed arg placeholders for usage line (limit to 3 repeats max)
-- ||| Format full help text with header, global opts, and subcommand grouping.
export formatHelp : HelpInfo -> String
formatHelp info =
  headerLine ++ "\n" ++ usageLineLocal ++ "\n\nOptions:\n" ++ globalSection ++ if null
                                                                                    (map (\(_, opts) => opts)
                                                                                       info.subCmds)
                                                                                 then ""
                                                                                 else "\nSubcommands:\n" ++ cmdSection
  where
    alreadySeen : HelpEntry -> List HelpEntry -> Bool
    alreadySeen new seen =
      any (\s => s.optionNames == new.optionNames && s.metavar == new.metavar) seen
    uniqueGlobalOpts : List HelpEntry
    uniqueGlobalOpts =
      foldl dedup [] info.globalOpts
      where
        dedup : List HelpEntry -> HelpEntry -> List HelpEntry
        dedup acc entry =
          if alreadySeen entry acc then acc else entry :: acc
    isPos : HelpEntry -> Bool
    isPos entry =
      ["<pos>"] `isPrefixOf` entry.optionNames
    namesStr : HelpEntry -> String
    namesStr entry =
      unwords entry.optionNames ++ if null entry.metavar
                                     then ""
                                     else " <" ++ entry.metavar ++ ">"
    descStr : HelpEntry -> String
    descStr e =
      case e.description of
        Nothing =>
          ""
        Just d =>
          d
    formatEntry : HelpEntry -> (String, String)
    formatEntry e =
      (namesStr e, descStr e)
    usageLineLocal : String
    usageLineLocal =
      "Usage: " ++ info.progName ++ if null uniqueGlobalOpts
                                      then ""
                                      else " [" ++ unwords
                                                     (map
                                                        (\e =>
                                                           "[" ++ e.metavar ++ "]")
                                                        (filter isPos
                                                           uniqueGlobalOpts)) ++ "]"
    headerLine : String
    headerLine =
      if null info.header
        then info.progName
        else info.progName ++ ": " ++ info.header
    globalSection : String
    globalSection =
      "\n" ++ alignColumns (map formatEntry uniqueGlobalOpts)
    cmdSection : String
    cmdSection =
      concat $ intersperse "\n" $ map
                                    (\(name, opts) =>
                                       "  " ++ name ++ ":" ++ formatCmdOpts
                                                                opts ++ "\n")
                                    info.subCmds
      where
        formatCmdOpts : List HelpEntry -> String
        formatCmdOpts [] =
          ""
        formatCmdOpts (h :: t) =
          "\n" ++ concat
                    (intersperse "\n"
                       (map
                          (\e =>
                             "    " ++ namesStr e ++ case e.description of
                                                       Nothing =>
                                                         ""
                                                       Just d =>
                                                         "  --  " ++ d)
                          (h :: t)))
-- Helper: check if entry already appears in deduplicated list
-- Deduplicate entries to avoid manyUpTo expansion noise
-- Check if entry is positional vs named option/flag
-- Combine option names and metavar into left column text
-- Extract description text for right column
-- Format individual help entry into aligned column pair
-- Usage synopsis from collected parser entries
-- Header line with program name and optional description
-- Format all global entries as aligned columns using existing helper
-- Format subcommands section with their respective options listed underneath
