||| Bash shell completion script generation. (Phase 3)
module Options.Applicative.BashCompletion

import Options.Applicative.Types

-- ||| Check if bash completion is requested.
export isCompletionRequest : List String -> Bool
isCompletionRequest args = "--bash-completion" `elem` args

-- ||| Generate option names for completion by traversing the parser tree.
export optionNames : Parser a -> List String
optionNames p = ?rhs_optionNames
