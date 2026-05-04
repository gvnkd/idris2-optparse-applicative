||| Executable entry point for optparse-applicative demo.
module Main

import Options.Applicative.Types
import Options.Applicative.Builder
import Options.Applicative.Run
import Options.Applicative.Multi
import Options.Applicative.Error
import Options.Applicative.Help
import System

||| Configuration data structure parsed from command line.
record ToolConfig where
  constructor MkToolConfig
  verbose    : Bool
  output     : String  
  inputFiles : List String

||| Build the CLI parser tree using Applicative composition.
mainParser : Parser ToolConfig
mainParser = pure MkToolConfig
          <*> flag' ["-v", "--verbose"]
          <*> option ["-o", "--output"] "stdout"
          <*> manyUpTo 64 (argument "FILE")

||| Test helper: parse an explicit argument list without touching system IO.
testParse : List String -> ParseResult ToolConfig
testParse args = runParserWith mainParser args

||| Print parsed configuration.
printConfig : ToolConfig -> IO ()
printConfig cfg = do
  putStrLn "=== Parsed config ==="  
  putStrLn $ "verbose    = " ++ show (verbose cfg)
  putStrLn $ "output     = " ++ output cfg
  putStrLn $ "inputFiles = " ++ show (inputFiles cfg)
  putStrLn "====================="

||| Handle parser result by printing success/failure messages.
processResult : ParseResult ToolConfig -> IO ()
processResult (Success cfg) = printConfig cfg
processResult (Failure err) = putStrLn $ "Error: " ++ renderError err  
processResult CompletionInvoked = putStrLn "Completion invoked"

||| Filter out internal runtime arguments from raw CLI input.
isUserArg : String -> Bool
isUserArg s = case unpack s of
    '/' :: _ => False
    '-' :: 'l' :: _ => False
    '-' :: 'L' :: _ => False  
    _ => True

||| Build help info for main parser.
appHelp : HelpInfo
appHelp = MkHelpInfo { progName = "optparse-test", header = "Demo CLI parser", entries = collectEntries mainParser }

||| Parse args and dispatch result to appropriate handler.
runProgram : List String -> IO ()
runProgram rawArgs = do
  res <- pure $ runParserWith mainParser (filter isUserArg rawArgs)
  case res of
    Success cfg => printConfig cfg  
    Failure err => putStrLn $ "Error: " ++ renderError err
    CompletionInvoked => putStrLn "Completion invoked"

||| Main entry point: parse CLI args and print config.
main : IO ()
main = getArgs >>= runProgram







