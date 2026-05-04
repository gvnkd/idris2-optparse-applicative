module Main

import Options.Applicative.Types
import Options.Applicative.Builder
import Options.Applicative.Run
import Options.Applicative.Multi
import Options.Applicative.Subparser
import Options.Applicative.Help

data CmdConfig = BuildCmd Bool | CleanCmd Bool | StatusCmd

cmdName : CmdConfig -> String
cmdName (BuildCmd _) = "build"
cmdName (CleanCmd _) = "clean"
cmdName StatusCmd = "status"

record ToolConfig where
  constructor MkToolConfig
  verbose    : Bool
  output     : String
  inputFiles : List String
  cmd        : CmdConfig

subCmds : SubparserConfig CmdConfig
subCmds = mkConfig [("build", pure (BuildCmd False)), ("clean", pure (CleanCmd False)), ("status", pure StatusCmd)]

mainParser : Parser ToolConfig
mainParser = pure MkToolConfig
          <*> (flag' ["-v", "--verbose"] `mhelp` "verbose")
          <*> (option ["-o", "--output"] "stdout" `mhelp` "output")
          <*> manyUpTo 64 (argument "FILE" `mhelp` "files")
          <*> mkSubparser subCmds

printResult : ParseResult ToolConfig -> IO ()
printResult (Success cfg) = putStrLn "Success"
printResult (Failure err) = putStrLn "Failure"
printResult CompletionInvoked = putStrLn "Completion"

main : IO ()
main = printResult (runParserWith mainParser [])
