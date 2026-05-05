module Main
import Options.Applicative.Builder
import Options.Applicative.Help
import Options.Applicative.Multi
import Options.Applicative.Run
import Options.Applicative.Subparser
import Options.Applicative.Types

data CmdConfig : Type where
  BuildCmd : Bool -> CmdConfig
  CleanCmd : Bool -> CmdConfig
  StatusCmd : CmdConfig

cmdName : CmdConfig -> String
cmdName (BuildCmd _) =
  "build"
cmdName (CleanCmd _) =
  "clean"
cmdName StatusCmd =
  "status"

record ToolConfig where
  constructor MkToolConfig
  verbose : Bool
  output : String
  inputFiles : List String
  cmd : CmdConfig

subCmds : SubparserConfig CmdConfig
subCmds =
  mkConfig
    [ ("build", pure (BuildCmd False))
    , ("clean", pure (CleanCmd False))
    , ("status", pure StatusCmd)
    ]

mainParser : Parser ToolConfig
mainParser =
  pure MkToolConfig
  <*>
    (flag' ["-v", "--verbose"] `mhelp` "verbose")
    <*>
      (option ["-o", "--output"] "stdout" `mhelp` "output")
      <*>
        manyUpTo 64 (argument "FILE" `mhelp` "files") <*> mkSubparser subCmds

printResult : ParseResult ToolConfig -> IO ()
printResult (Success cfg) =
  putStrLn "Success"
printResult (Failure err) =
  putStrLn "Failure"
printResult CompletionInvoked =
  putStrLn "Completion"

main : IO ()
main =
  printResult (runParserWith mainParser [])
