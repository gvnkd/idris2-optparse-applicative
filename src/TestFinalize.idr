module Main

import Options.Applicative.Types
import Options.Applicative.Builder
import Options.Applicative.Run

main : IO ()
main = do
  let p = flag' ["-v"]
  printLn (finalizeParser p)
  let p2 = Alt (Option ["-o"] "ARG" Nothing) (Pure "stdout")
  printLn (finalizeParser p2)
