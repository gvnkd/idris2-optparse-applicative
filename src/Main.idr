||| Executable entry point for optparse-applicative demo.
module Main

import Options.Applicative.Types
import Options.Applicative.Builder  
import Options.Applicative.Run
import Options.Applicative.Multi
import Options.Applicative.Error
import Options.Applicative.Help
import Options.Applicative.Modifiers
import System

||| Command enumeration for subcommand routing.
data Cmd = Build | Init | Clean | Status

||| Configuration data structure parsed from command line.
record ToolConfig where
  constructor MkToolConfig
  verbose    : Bool
  output     : String  
  inputFiles : List String
  cmd        : Cmd

||| Convert Cmd enum to human-readable name.
cmdName : Cmd -> String  
cmdName Build  = "build"
cmdName Init   = "init"
cmdName Clean  = "clean"
cmdName Status = "status"

||| Print parsed configuration to stdout.
printCfg : ToolConfig -> IO ()
printCfg cfg = do
  putStrLn "=== Parsed config ==="  
  putStrLn $ "verbose    = " ++ show (verbose cfg)
  putStrLn $ "output     = " ++ output cfg
  putStrLn $ "inputFiles = " ++ show (inputFiles cfg)
  putStrLn $ "cmd        = " ++ cmdName cfg.cmd
  putStrLn "====================="

||| Subcommand parser using Alt branching for routing.
commandParser : Parser Cmd
commandParser = cmdBuild <|> cmdInit <|> cmdClean <|> cmdStatus

  where
    cmdBuild : Parser Cmd
    cmdBuild = pure Build `mhelp` "Build the project"

    cmdInit : Parser Cmd  
    cmdInit = pure Init `mhelp` "Initialize a new project"

    cmdClean : Parser Cmd
    cmdClean = pure Clean `mhelp` "Clean build artifacts"

    cmdStatus : Parser Cmd
    cmdStatus = pure Status `mhelp` "Show project status (default)"

||| Build the CLI parser tree using Applicative composition with modifiers.
mainParser : Parser ToolConfig
mainParser = pure MkToolConfig
          <*> (flag' ["-v", "--verbose"] `mhelp` "Enable verbose mode")
          <*> (option ["-o", "--output"] "stdout" `mhelp` "Specify output file")  
          <*> manyUpTo 64 (argument "FILE" `metavarMod` "Input files to process")
          <*> commandParser

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
appHelp = MkHelpInfo 
  { progName   = "optparse-test"
  , header     = "Demo CLI parser showcasing optparse-applicative features"  
  , entries    = collectEntries mainParser
  }

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

