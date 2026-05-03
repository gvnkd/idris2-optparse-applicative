||| Parser execution and argument processing.
module Options.Applicative.Run

import Options.Applicative.Types
import Options.Applicative.Error
import System
import Data.List

mutual  
  finalizeApp : Parser (x -> a) -> Parser x -> Maybe a
  finalizeParser : Parser a -> Maybe a
  
  reduceApp : Parser (x -> a) -> Parser x -> List String -> StepResult a
  goReduction : (x -> a) -> Parser x -> List String -> StepResult a
  tryLeftOrRight : Parser a -> Parser a -> List String -> StepResult a
  
  matchArg : Parser a -> String -> StepResult a
  consumeArgs : Parser a -> List String -> StepResult a

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

  -- Fix Bug 3: return StepMore for Options to force two-arg consumption through consumeArgs
  matchArg p arg =
    case p of
      Flag names         => if arg `elem` names then StepSuccess (Pure True) True [] else StepFailure (UnexpectedError arg)
      Option nm _        => if arg `elem` nm then StepMore p [arg] else StepFailure (UnexpectedError arg)
      Argument _         => StepSuccess (Pure arg) arg []
      Pure x             => StepSuccess (Pure x) x []
      App pf pa          => StepMore (App pf pa) [arg]
      Alt p1 p2          => StepMore (Alt p1 p2) [arg]
      Fail               => StepFailure (UnexpectedError arg)

  -- Fix Bug 1: process pf before pa to prevent argument starvation
  reduceApp pf pa args = 
    case consumeArgs pf args of
        StepSuccess _ f leftover => goReduction f pa leftover
        StepFailure err          => StepFailure err
        StepMore p' rest        => reduceApp p' pa rest

  -- Helper: apply function value to argument parser result  
  goReduction f pa args = 
    case consumeArgs pa args of
        StepSuccess _ x leftover => StepSuccess (Pure (f x)) (f x) leftover
        StepFailure err          => StepFailure err
        StepMore p' rest        => goReduction f p' rest

  -- Fix Bug 2b: handle StepMore from matchArg for Alt backtracking  
  tryLeftOrRight _ _ []     = StepFailure (MissingOption "No arguments for alternative")
  tryLeftOrRight p1 p2 (arg :: rest) = 
    case matchArg p1 arg of
        StepSuccess updatedTree val leftover => consumeArgs updatedTree (leftover ++ rest)
        StepFailure _ => consumeArgs p2 (arg :: rest)
        StepMore p' leftover => 
            case consumeArgs p' (leftover ++ rest) of
                StepSuccess updatedTree val leftover2 => StepSuccess updatedTree val leftover2
                StepFailure _ => consumeArgs p2 (arg :: rest)
                StepMore _ _ => consumeArgs p2 (arg :: rest)

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
export
runParserWith : Parser a -> List String -> ParseResult a
runParserWith p args = runParser p args

||| Run a parser by fetching arguments from the environment.
export
execParser : {auto _ : HasIO io} -> Parser a -> io (ParseResult a)
execParser p = do
  args <- getArgs
  pure $ runParserWith p args

||| Run a parser and handle errors/exit. Dies on parse failure after rendering error text.
export
customExecParser : {auto _ : HasIO io} -> Parser a -> io a
customExecParser p = do
  result <- execParser p
  case result of
    Success val         => pure val
    Failure err         => putStrLn (renderError err) >> die "parse failure"
    CompletionInvoked   => putStrLn "Completion invoked" >> die "completion invoked"
