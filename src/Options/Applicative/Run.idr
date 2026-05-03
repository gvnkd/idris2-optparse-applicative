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
consumeArgs _ [] = StepFailure (MissingOption "Expected argument")

consumeArgs p (arg :: rest) =
    case matchArg p arg of
        StepSuccess updatedTree val leftover => consumeArgs updatedTree (leftover ++ rest)
        StepFailure err         => StepFailure err
        StepMore p' leftover    => consumeArgs p' (leftover ++ rest)
