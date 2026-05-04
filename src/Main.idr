||| Executable entry point for optparse-applicative demo.
module Main

import Options.Applicative.Types
import Options.Applicative.Builder
import Options.Applicative.Run
import Options.Applicative.Multi
import Options.Applicative.Error

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

||| Main entry point: parse CLI args and print config.
main : IO ()
main = do
  cfg <- customExecParser mainParser
  printConfig cfg
