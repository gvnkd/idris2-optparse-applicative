||| Minimal executable entry point to test the Phase 2 parser library.
module Main

import Options.Applicative.Types
import Options.Applicative.Builder
import Options.Applicative.Run

-- | A simple data structure to hold our parsed CLI configuration.
record Config where
  constructor MkConfig
  verbose    : Bool
  output     : String

-- | Construct the main CLI parser using our Applicative Builder combinators.
mainParser : Parser Config
mainParser = pure MkConfig 
          <*> flag' ["-v", "--verbose"] 
          <*> strOption ["-o", "--output"]

-- | Run the parser manually for testing purposes via REPL or build.
testParse : List String -> ParseResult Config
testParse args = runParser mainParser args
