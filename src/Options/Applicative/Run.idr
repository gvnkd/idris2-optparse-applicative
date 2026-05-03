||| Parser execution and argument processing.
module Options.Applicative.Run

import Options.Applicative.Types
import Data.List

||| Run a parser against a list of command-line arguments.
export
runParser : Parser a -> List String -> ParseResult a
runParser p args = ?rhs_runParser

||| Run a parser with default program arguments.
export
execParser : Parser a -> IO (ParseResult a)
execParser p = ?rhs_execParser

||| Run a parser and handle errors/exit.
export
customExecParser : Parser a -> IO a
customExecParser p = ?rhs_customExecParser

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
        App pf pa      => consumeApp pf pa (arg :: rest)
        Alt p1 p2      => tryLeftOrRight p1 p2 (arg :: rest)

  where
    tryLeftOrRight : Parser a -> Parser a -> List String -> StepResult a

    tryLeftOrRight _ _ []     = StepFailure (MissingOption "No arguments for alternative")
    tryLeftOrRight p1 p2 (arg :: rest) = 
          case matchArg p1 arg of
              StepSuccess updatedTree val leftover => consumeArgs updatedTree (leftover ++ rest)
              StepFailure _ => tryLeftOrRight Fail p2 (arg :: rest)
              StepMore _ leftover => consumeArgs p1 (leftover ++ rest)

    consumeApp : Parser (x -> a) -> Parser x -> List String -> StepResult a

    consumeApp pf pa = ?rhs_consume_app pf pa
