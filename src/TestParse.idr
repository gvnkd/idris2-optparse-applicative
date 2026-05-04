||| Quick parser sanity tests for beta release.
module TestParse

import Options.Applicative.Types
import Options.Applicative.Builder
import Options.Applicative.Run
import Options.Applicative.Multi

record ToolConfig where
  constructor MkToolConfig
  verbose    : Bool
  output     : String
  inputFiles : List String

mainParser : Parser ToolConfig
mainParser = pure MkToolConfig
          <*> flag' ["-v", "--verbose"]
          <*> option ["-o", "--output"] "stdout"  -- Use option with default for robustness
          <*> manyUpTo 16 (argument "FILE") -- already bounded, safe!

-- Test cases: empty args, flags only, option with value, positionals only
export testEmpty : ParseResult ToolConfig
testEmpty = runParserWith mainParser []

export testVerboseOnly : ParseResult ToolConfig  
testVerboseOnly = runParserWith mainParser ["-v"]

export testOptionValue : ParseResult ToolConfig
testOptionValue = runParserWith mainParser ["--output", "results.json"]

export testFilesOnly : ParseResult ToolConfig
testFilesOnly = runParserWith mainParser ["src/Main.idr", "src/Types.idr"]

export testFullCombo : ParseResult ToolConfig
testFullCombo = runParserWith mainParser ["-v", "-o", "out.txt", "file1.txt", "file2.txt"]
