||| Parser execution and argument processing.
module Options.Applicative.Run

import Options.Applicative.Types
import Options.Applicative.Error
import Data.List

mutual
  finalizeApp : Parser (x -> a) -> Parser x -> Maybe a
  finalizeParser : Parser a -> Maybe a
  finalizeParser p = 
    case p of
        Pure x             => Just x
        Flag names         => Just False -- Default to false if flag not seen
        Fail               => Nothing
        Option _ _         => Nothing -- Required value missing
        Argument _         => Nothing -- Required argument missing
        App pf pa          => finalizeApp pf pa
        Alt p1 p2          => finalizeParser p1 <|> finalizeParser p2

  finalizeApp pf pa = 
    case finalizeParser pf of
        Just f => case finalizeParser pa of
            Just x => Just (f x)
            _      => Nothing
        _      => Nothing

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
    case finalizeParser p of
        Just val  => StepSuccess (Pure val) val []
        Nothing   => StepFailure (MissingOption "Unsatisfied parser")

consumeArgs p (arg :: rest) =
    case p of
         Flag names     => if arg `elem` names then consumeArgs (Pure True) rest else consumeArgs p rest
         Option nm _    => if arg `elem` nm
                then case rest of
                    (val :: rest') => consumeArgs (Pure val) rest'
                    []             => StepFailure (MissingOption "Option value required")
                else consumeArgs p rest
         Argument _     => consumeArgs (Pure arg) rest
         Pure x         => StepSuccess (Pure x) x (arg :: rest)
         Fail           => StepFailure (UnexpectedError "Failed to parse")
         App pf pa      => reduceApp pf pa (arg :: rest)
         Alt p1 p2      => tryLeftOrRight p1 p2 (arg :: rest)

  where
    reducePf : Parser (x -> a) -> x -> List String -> StepResult a
    reducePf pf' val args = 
        case consumeArgs pf' args of
            StepSuccess _ f leftover => StepSuccess (Pure (f val)) (f val) leftover
            StepFailure err          => StepFailure err
            StepMore p'' rest       => reducePf p'' val rest

    reduceApp : Parser (x -> a) -> Parser x -> List String -> StepResult a
    reduceApp pf pa args = 
        case consumeArgs pa args of
            StepSuccess _ x leftover => reducePf pf x leftover
            StepFailure err          => StepFailure err
            StepMore p' rest        => reduceApp pf p' rest

    tryLeftOrRight : Parser a -> Parser a -> List String -> StepResult a
    tryLeftOrRight _ _ []     = StepFailure (MissingOption "No arguments for alternative")
    tryLeftOrRight p1 p2 (arg :: rest) = 
        case matchArg p1 arg of
            StepSuccess updatedTree val leftover => consumeArgs updatedTree (leftover ++ rest)
            StepFailure _ => consumeArgs p2 (arg :: rest)
            otherResult => otherResult

||| Run a parser against a list of command-line arguments.
export
runParser : Parser a -> List String -> ParseResult a
runParser p args = 
    case consumeArgs p args of
        StepSuccess _ val []         => Success val
        StepSuccess _ val leftover   => Failure (UnexpectedError "Extra arguments provided")
        StepFailure err              => Failure err
        StepMore updatedTree rest    => runParser updatedTree rest

||| Run a parser with explicit argument list (primary interface).
-- ||| Note: System.getArgs requires FFI imports unavailable in base Idris 2.
-- |||     Usage: runParser myParser args from Main or via execParserWith.
export
runParserWith : Parser a -> List String -> ParseResult a
runParserWith p = runParser p

||| Stub: Run with empty args (deferred system integration to post-beta).
-- TODO(beta2): integrate System.Environment.getArgs when available.
export
execParser : Parser a -> IO (ParseResult a)
execParser p = pure $ runParserWith p []
