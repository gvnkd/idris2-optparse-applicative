module TestTwoPass

import Options.Applicative.Types
import Options.Applicative.Run

main : IO ()
main = do
  let flagP := Flag ["-v", "--verbose"]
      colRes := collectBindings flagP ["-v", "file.txt"]
   in putStrLn $ showCollectResult colRes

showCollectResult : CollectResult -> String
showCollectResult (Collected b) = "flags=" ++ show b.flags ++ ", opts=" ++ show b.options ++ ", pos=" ++ show b.positionals
showCollectResult (CollectFailure e) = "Error: " ++ show e
