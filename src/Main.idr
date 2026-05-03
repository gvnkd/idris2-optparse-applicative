||| Executable entry point for optparse-applicative demo.
module Main

import Options.Applicative.Types
import Options.Applicative.Builder
import Options.Applicative.Run
import Options.Applicative.Multi

-- ||| Configuration data structure parsed from command line.
record ToolConfig where
  constructor MkToolConfig
  verbose    : Bool
  output     : String
  inputFiles : List String

-- ||| Build the CLI parser tree using Applicative composition.
mainParser : Parser ToolConfig
mainParser = pure MkToolConfig
          <*> flag' ["-v", "--verbose"]
          <*> option ["-o", "--output"] "stdout"
          <*> manyUpTo 64 (argument "FILE")

-- ||| Test helper: parse an explicit argument list without touching system IO.
testParse : List String -> ParseResult ToolConfig
testParse args = runParserWith mainParser args

-- ||| Main entry point: fetch real CLI args, parse, and print result.
main : IO ()
main = do
  conf <- customExecParser mainParser
  putStrLn "=== Parsed config ==="
  putStrLn $ "verbose    = " ++ show (verbose conf)
  putStrLn $ "output     = " ++ output conf
  putStrLn $ "inputFiles = " ++ show (inputFiles conf)
  putStrLn "====================="
