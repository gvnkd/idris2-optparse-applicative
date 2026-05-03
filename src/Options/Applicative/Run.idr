||| Parser execution and argument processing.
module Options.Applicative.Run

import Options.Applicative.Types
import Data.List

||| Helper: match a single argument against a parser.
matchArg : Parser a -> String -> StepResult a
matchArg p arg =
    case p of
      Flag names         => if arg `elem` names then StepSuccess (Pure True) True [] else StepFailure (UnexpectedError arg)
      Option nm _        => if arg `elem` nm then StepSuccess (Pure arg) arg [] else StepFailure (UnexpectedError arg)
      Argument _         => StepSuccess (Pure arg) arg []
      Pure x             => StepSuccess (Pure x) x []
      App pf pa          => StepMore (App pf pa) [arg]
      Alt p1 p2          => StepMore (Alt p1 p2) [arg]
      Fail               => StepFailure (UnexpectedError arg)

||| Helper: consume remaining arguments.
consumeArgs : Parser a -> List String -> StepResult a
consumeArgs p [] = 
    case p of
        Pure x     => StepSuccess (Pure x) x []
        _          => StepFailure (MissingOption "Unsatisfied parser")

consumeArgs p (arg :: rest) =
    case p of
         Flag names     => if arg `elem` names then consumeArgs (Pure True) rest else consumeArgs p rest
         Option nm _    => if arg `elem` nm then consumeArgs (Pure arg) rest else consumeArgs p rest
         Argument _     => consumeArgs (Pure arg) rest
         Pure x         => StepSuccess (Pure x) x (arg :: rest)
         Fail           => StepFailure (UnexpectedError "Failed to parse")
         App pf pa      => reduceApp pf pa (arg :: rest)
         Alt p1 p2      => tryLeftOrRight p1 p2 (arg :: rest)

  where
    reduceApp : Parser (x -> a) -> Parser x -> List String -> StepResult a

    reduceApp pf pa args = 
        case consumeArgs pa args of
            StepSuccess _ x leftover => case consumeArgs pf leftover of
                StepSuccess _ f leftover2   => StepSuccess (Pure (f x)) (f x) leftover2
                StepFailure err              => StepFailure err
                StepMore p'' rest        => case consumeArgs p'' rest of
                    StepSuccess _ f leftover2   => StepSuccess (Pure (f x)) (f x) leftover2
                    StepFailure err                 => StepFailure err
                    StepMore p''' rest2      => case consumeArgs p''' rest2 of
                        StepSuccess _ f leftover3   => StepSuccess (Pure (f x)) (f x) leftover3
                        StepFailure err                => StepFailure err
                        StepMore p'''' rest3    => ?rhs_app_pf_partial_recurse pf p'''' rest3
            StepFailure err          => StepFailure err
            StepMore p' rest         => case consumeArgs p' rest of
                StepSuccess _ x2 leftover2   => ?rhs_app_second_part pf p' x2 leftover2
                StepFailure err              => StepFailure err
                StepMore p'' rest2      => reduceApp pf p'' (rest2 ++ rest)

    tryLeftOrRight : Parser a -> Parser a -> List String -> StepResult a

    tryLeftOrRight _ _ []     = StepFailure (MissingOption "No arguments for alternative")
    tryLeftOrRight p1 p2 (arg :: rest) = 
          case matchArg p1 arg of
              StepSuccess updatedTree val leftover => consumeArgs updatedTree (leftover ++ rest)
              StepFailure _ => consumeArgs p2 (arg :: rest) -- Fix 1: Fallback immediately if left fails strictly
              otherResult => otherResult -- Fix 2: If matchArg is stuck (StepMore), just pass it up to caller

||| Run a parser against a list of command-line arguments.
export
runParser : Parser a -> List String -> ParseResult a
runParser p args = 
    case consumeArgs p args of
        StepSuccess _ val []         => Success val
        StepSuccess _ val leftover   => Failure (UnexpectedError "Extra arguments provided")
        StepFailure err              => Failure err
        StepMore updatedTree rest    => runParser updatedTree rest

||| Run a parser with default program arguments.
export
execParser : Parser a -> IO (ParseResult a)
execParser p = pure $ runParser p [] -- Note: actual argument fetching requires system IO imports

||| Run a parser and handle errors/exit.
export
customExecParser : Parser a -> IO a
customExecParser p = do
  result <- execParser p
  case result of
    Success val => pure val
    _           => ?rhs_custom_exec_fail_result
