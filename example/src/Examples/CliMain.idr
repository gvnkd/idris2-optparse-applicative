||| Executable entry point for optparse-applicative demo.
module Examples.CliMain

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

||| Convert CmdConfig to human-readable name.
cmdName : CmdConfig -> String
cmdName (BuildCmd _) = "build"
cmdName (InitCmd _)  = "init"
cmdName (CleanCmd _) = "clean"
cmdName (StatusCmd {}) = "status"

||| Print parsed configuration to stdout.
printCfg : ToolConfig -> IO ()
printCfg cfg = do
  putStrLn "=== Parsed config ==="
  putStrLn $ "verbose    = " ++ show (verbose cfg)
  putStrLn $ "output     = " ++ output cfg
  putStrLn $ "inputFiles = " ++ show (inputFiles cfg)
  putStrLn $ "cmd        = " ++ cmdName cfg.cmd
  putStrLn "====================="

||| Build subparser with four distinct commands.
subCmds : SubparserConfig CmdConfig
subCmds = progDesc "Available subcommands:"
         $ mkConfig [ ("build", buildSub),
                      ("init", initSub),
                      ("clean", cleanSub),
                      ("status", statusSub) ]

  where
    buildSub : Parser CmdConfig
    buildSub = pure BuildCmd
              <*> (flag' ["-O", "--optimize"] `mhelp` "Enable optimization")

    initSub : Parser CmdConfig
    initSub = pure InitCmd
            <*> (strOption ["--template"] `mhelp` "Template to use")

    cleanSub : Parser CmdConfig
    cleanSub = pure CleanCmd
             <*> (flag' ["-n", "--dry-run"] `mhelp` "Do not delete files")

    statusSub : Parser CmdConfig
    statusSub = pure StatusCmd {}

||| Build the CLI parser tree using Applicative composition with modifiers.
mainParser : Parser ToolConfig
mainParser = pure MkToolConfig
          <*> (flag' ["-v", "--verbose"] `mhelp` "Enable verbose mode")
          <*> (option ["-o", "--output"] "stdout" `mhelp` "Specify output file")
          <*> manyUpTo 64 (argument "FILE" `mhelp` "Input files to process")
          <*> mkSubparser subCmds

||| Test helper: parse an explicit argument list without touching system IO.
testParse : List String -> ParseResult ToolConfig
testParse args = runParserWith mainParser args

||| Filter out internal runtime arguments from raw CLI input.
isUserArg : String -> Bool
isUserArg s = case unpack s of
    '/' :: _ => False
    '-' :: 'l' :: _ => False
    '-' :: 'L' :: _ => False
    _ => True

||| Build help info for the main parser with rich description.
appHelp : HelpInfo
appHelp = let info = collectHelpInfo "optparse-test" mainParser in
          { header := "Demo CLI parser showcasing optparse-applicative features" } info

||| Parse args and dispatch result to appropriate handler.
runProgram : List String -> IO ()
runProgram rawArgs = if isHelpFlag rawArgs then showHelp else parseAndPrint (filter isUserArg rawArgs)

  where
    isHelpFlag : List String -> Bool
    isHelpFlag args = elem "--help" args || elem "-h" args

    showHelp : IO ()
    showHelp = putStrLn (formatHelp appHelp)

    parseAndPrint : List String -> IO ()
    parseAndPrint cleaned = do
      res <- pure $ runParserWith mainParser cleaned
      case res of
        Success cfg => printCfg cfg
        Failure err => putStrLn $ "Error: " ++ renderError err
        CompletionInvoked => putStrLn "Completion invoked"

||| Main entry point: parse CLI args and print config.
main : IO ()
main = getArgs >>= runProgram

