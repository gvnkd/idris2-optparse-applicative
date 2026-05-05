module Options.Applicative.BashCompletion
import Data.List
import Data.String
import Options.Applicative.Types
-- ||| Check if bash completion is requested.
export isCompletionRequest : List String -> Bool
isCompletionRequest args =
  "--bash-completion" `elem` args
-- ||| Generate option names for completion by traversing the parser tree.
export optionNames : Parser a -> List String
optionNames p =
  case p of
    Flag names _ =>
      names
    Option nm _ _ =>
      nm
    Argument _ _ =>
      []
    Command _ px =>
      optionNames px
    Pure _ =>
      []
    App pf pa =>
      optionNames pf ++ optionNames pa
    Alt p1 p2 =>
      optionNames p1 ++ optionNames p2
    Fail =>
      []
-- ||| Generate a bash completion script for a parser.
export bashCompletionScript : String -> Parser a -> String
bashCompletionScript progName p =
  let opts = optionNames p in "#!/bin/bash\ncomplete -W \""
                              ++
                                unwords opts ++ "\" " ++ progName
