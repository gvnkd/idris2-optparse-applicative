module Tests.TestRunParser

import Options.Applicative.Run

cliParser : Parser (List String)
cliParser = argument "FILE" <|> pure []

main : IO ()
main = do
  let result = runParser cliParser ["foo.idr"]
  printLn result
