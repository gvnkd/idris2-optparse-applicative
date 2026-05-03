||| Bash shell completion script generation. (Phase 3)
module Options.Applicative.BashCompletion

import Options.Applicative.Types

-- ||| Check if bash completion is requested.
export isCompletionRequest : List String -> Bool
isCompletionRequest args = "--bash-completion" `elem` args

-- ||| Generate option names for completion by traversing the parser tree.
export optionNames : Parser a -> List String
optionNames p = 
    case p of
        Flag names         => names
        Option nm _        => nm
        Argument _         => []
        Pure _             => []
        App pf pa          => optionNames pf ++ optionNames pa
        Alt p1 p2          => optionNames p1 ++ optionNames p2
        Fail               => []
