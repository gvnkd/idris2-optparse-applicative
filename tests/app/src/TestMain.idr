||| Test fixture CLI for library golden tests.
||| Exercises all library features: flags, options, positionals, subcommands.
module TestMain

import Options.Applicative.Types
import Options.Applicative.Builder
import Options.Applicative.Run
import Options.Applicative.Multi
import Options.Applicative.Error
import Options.Applicative.Help
import Options.Applicative.Modifiers
import Options.Applicative.Subparser
import System

||| Configuration for each subcommand.
data CmdConfig : Type where
  BuildCmd  : (optimize : Bool) -> CmdConfig
  InitCmd   : (template : String) -> CmdConfig
  CleanCmd  : (dryRun : Bool) -> CmdConfig
  StatusCmd : CmdConfig

||| Top-level configuration parsed from command line.
record ToolConfig where
  constructor MkToolConfig
  verbose    : Bool
  output     : String
  inputFiles : List String
  cmd        : CmdConfig

cmdName : CmdConfig -> String
cmdName (BuildCmd _) = "build"
cmdName (InitCmd _)  = "init"
cmdName (CleanCmd _) = "clean"
cmdName StatusCmd {} = "status"

printSubCmdDetails : CmdConfig -> IO ()
printSubCmdDetails (BuildCmd opt) = putStrLn $ "  --optimize   = " ++ show opt
printSubCmdDetails (InitCmd tpl)  = putStrLn $ "  --template   = " ++ tpl
printSubCmdDetails (CleanCmd dry) = putStrLn $ "  -n/--dry-run  = " ++ show dry
printSubCmdDetails StatusCmd {}   = pure ()

printCfg : ToolConfig -> IO ()
printCfg cfg = do
  putStrLn "=== Parsed config ==="
  putStrLn $ "verbose    = " ++ show (verbose cfg)
  putStrLn $ "output     = " ++ output cfg
  putStrLn $ "inputFiles = " ++ show (inputFiles cfg)
  putStrLn $ "cmd        = " ++ cmdName cfg.cmd
  printSubCmdDetails cfg.cmd
  putStrLn "====================="

subCmds : SubparserConfig CmdConfig
subCmds = mkConfig
  [ ("build",  pure BuildCmd  <*> (flag' ["-O", "--optimize"] `mhelp` "Enable optimization"))
  , ("init",   pure InitCmd   <*> (strOption ["--template"] `mhelp` "Template to use"))
  , ("clean",  pure CleanCmd  <*> (flag' ["-n", "--dry-run"] `mhelp` "Do not delete files"))
  , ("status", pure StatusCmd)
  ]

mainParser : Parser ToolConfig
mainParser = pure MkToolConfig
          <*> (flag' ["-v", "--verbose"] `mhelp` "Enable verbose mode")
          <*> (option ["-o", "--output"] "stdout" `mhelp` "Specify output file")
          <*> manyUpTo 64 (argument "FILE" `mhelp` "Input files to process")
          <*> mkSubparser subCmds

isUserArg : String -> Bool
isUserArg s = case unpack s of
    '/' :: _ => False
    '-' :: 'l' :: _ => False
    '-' :: 'L' :: _ => False
    _ => True

runProgram : List String -> IO ()
runProgram rawArgs =
  let cleaned = filter isUserArg rawArgs
   in if elem "--help" cleaned || elem "-h" cleaned
        then putStrLn (formatHelp appHelp)
        else parseAndPrint cleaned

  where
    appHelp : HelpInfo
    appHelp = let info = collectHelpInfo "optparse-test" mainParser in
              { header := "Test fixture for optparse-applicative" } info

    parseAndPrint : List String -> IO ()
    parseAndPrint cleaned = do
      res <- pure $ runParserWith mainParser cleaned
      case res of
        Success cfg => printCfg cfg
        Failure err => putStrLn $ "Error: " ++ renderError err
        CompletionInvoked => putStrLn "Completion invoked"

main : IO ()
main = getArgs >>= runProgram
