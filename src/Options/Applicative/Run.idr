||| Parser execution and argument processing.
module Options.Applicative.Run

import Options.Applicative.Types
import Options.Applicative.Error
import System
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

mutual
  getAllFlagNames : Parser a -> List String
  getAllFlagNames (Flag names) = names
  getAllFlagNames (Option _ _) = []
  getAllFlagNames (Argument _) = []
  getAllFlagNames (Pure _)     = []
  getAllFlagNames (App f x)    = getAllFlagNames f ++ getAllFlagNames x
  getAllFlagNames (Alt p1 p2)  = getAllFlagNames p1 ++ getAllFlagNames p2
  getAllFlagNames Fail         = []

  getAllOptionNames : Parser a -> List String
  getAllOptionNames (Flag _)     = []
  getAllOptionNames (Option nm _) = nm
  getAllOptionNames (Argument _) = []
  getAllOptionNames (Pure _)     = []
  getAllOptionNames (App f x)    = getAllOptionNames f ++ getAllOptionNames x
  getAllOptionNames (Alt p1 p2)  = getAllOptionNames p1 ++ getAllOptionNames p2
  getAllOptionNames Fail         = []

  checkFlag : Parser a -> String -> Bool
  checkFlag p arg = arg `elem` getAllFlagNames p

  checkOpt : Parser a -> String -> Bool
  checkOpt p arg = arg `elem` getAllOptionNames p

------------------------------------------------------------------------
-- Two-Pass Parser Implementation (Phase 2)
------------------------------------------------------------------------

||| Pass 1: Scan args once, collect flag/option hits and positionals.
export
collectBindings : Parser a -> List String -> CollectResult
collectBindings p args = scanBnds MkParseEmptyBinds args
  where
    MkParseEmptyBinds : ParseBindings
    MkParseEmptyBinds = MkParseBindings [] [] []

    scanBnds : ParseBindings -> List String -> CollectResult
    scanBnds bnds []            = Collected bnds
    scanBnds (MkParseBindings fls opts pos) (arg :: rest) =
      if checkFlag p arg then
        scanBnds (MkParseBindings ((getAllFlagNames $ Flag [arg], True) :: fls) opts pos) rest
      else if checkOpt p arg then
        case rest of
          val :: rest' => scanBnds (MkParseBindings fls (opts ++ [([arg], Just val)]) pos) rest'
          []           => CollectFailure (MissingOption "Option value required")
      else
        scanBnds (MkParseBindings fls opts (pos ++ [arg])) rest


||| Pass 2: Apply collected bindings back onto the parser tree.
||| Threads positional arguments through the tree left-to-right.
export
applyBindings : Parser a -> ParseBindings -> ParseResult a
applyBindings p bnds = case goApp bnds.positionals of
    Just (x, [])    => Success x
    Just (x, rest)  => Failure (UnexpectedError ("Extra arguments provided: " ++ show rest))
    Nothing         => Failure (MissingOption "Unsatisfied parser")

  where
    eqNames : List String -> List String -> Bool
    eqNames xs ys = any (`elem` ys) xs

    goApp : List String -> Maybe (a, List String)
    goApp pos = go p pos

      where
        go : Parser x -> List String -> Maybe (x, List String)
        go (Pure x)       pos = Just (x, pos)
        go Fail           pos = Nothing
        go (Flag names)   pos =
          case find (\(ns, v) => eqNames ns names) bnds.flags of
            Just (_, v) => Just (v, pos)
            Nothing     => Just (False, pos)
        go (Option nm _)  pos =
          case find (\(ns, mv) => eqNames ns nm) bnds.options of
            Just (_, Just v) => Just (v, pos)
            _                => Nothing
        go (Argument _)   pos =
          case pos of
            (h :: t) => Just (h, t)
            []       => Nothing
        go (App pf px)    pos = do
          (f, pos1) <- go pf pos
          (x, pos2) <- go px pos1
          pure (f x, pos2)
        go (Alt p1 p2)    pos =
          case go p1 pos of
            Just (x, pos1) => Just (x, pos1)
            Nothing        => go p2 pos

||| Filter out internal runtime arguments (paths, library refs).
isUserArg : String -> Bool
isUserArg x = case unpack x of
    '/' :: _ => False
    '-' :: 'l' :: _ => False
    '-' :: 'L' :: _ => False
    _ => True

||| Run a parser with explicit argument list (primary interface).
||| Uses the two-pass parser: collect bindings globally, then apply to tree.
export
runParserWith : Parser a -> List String -> ParseResult a
runParserWith p args =
  case collectBindings p args of
    Collected bnds     => applyBindings p bnds
    CollectFailure err => Failure err

||| Run a parser by fetching arguments from the environment.
export
execParser : {auto _ : HasIO io} -> Parser a -> io (ParseResult a)
execParser p = do
  rawArgs <- getArgs
  let cleanArgs := filter isUserArg rawArgs
  pure $ runParserWith p cleanArgs

||| Run a parser and handle errors/exit. Dies on parse failure after rendering error text.
export
customExecParser : {auto _ : HasIO io} -> Parser a -> io a
customExecParser p = do
  result <- execParser p
  case result of
    Success val         => pure val
    Failure err         => putStrLn (renderError err) >> die "parse failure"
    CompletionInvoked   => putStrLn "Completion invoked" >> die "completion invoked"

