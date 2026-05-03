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
      Flag names         => if arg `elem` names then StepSuccess True [] else StepFailure (UnexpectedError arg)
      Option nm mv       => ?rhs_match_option nm mv
      Argument _         => StepSuccess arg []
      Pure x             => ?rhs_match_pure x
      App pf pa          => ?rhs_match_app pf pa
      Alt p1 p2          => ?rhs_match_alt p1 p2
      Fail               => ?rhs_match_fail

||| Helper: consume remaining arguments.
consumeArgs : Parser a -> List String -> StepResult a
consumeArgs p args = ?rhs_consumeArgs
