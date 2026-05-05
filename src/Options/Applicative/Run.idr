module Options.Applicative.Run
import Data.List
import Data.Maybe
import Options.Applicative.Error
import Options.Applicative.Types
import System

mutual
  finalizeApp : Parser (x -> a) -> Parser x -> Maybe a
  finalizeParser : Parser a -> Maybe a
  finalizeParser p =
    case p of
      Pure x =>
        Just x
      Flag _ _ =>
        Just False
      Fail =>
        Nothing
      Option _ _ _ =>
        Nothing
      Argument _ _ =>
        Nothing
      Command _ px =>
        finalizeParser px
      App pf pa =>
        finalizeApp pf pa
      Alt p1 p2 =>
        finalizeParser p1 <|> finalizeParser p2
  finalizeApp pf pa =
    case finalizeParser pf of
      Just f =>
        case finalizeParser pa of
          Just x =>
            Just (f x)
          _ =>
            Nothing
      _ =>
        Nothing
-- Default to false if flag not seen
-- Required value missing
-- Required argument missing
-- transparent wrapper
||| Helper: match a single argument against a parser.
matchArg : Parser a -> String -> StepResult a
matchArg p arg =
  case p of
    Flag names _ =>
      if arg `elem` names
        then StepSuccess (Pure True) True []
        else StepFailure (UnexpectedError arg)
    Option nm _ _ =>
      if arg `elem` nm
        then StepSuccess (Pure arg) arg []
        else StepFailure (UnexpectedError arg)
    Argument _ _ =>
      StepSuccess (Pure arg) arg []
    Command _ px =>
      matchArg px arg
    Pure x =>
      StepSuccess (Pure x) x []
    App pf pa =>
      StepMore (App pf pa) [arg]
    Alt p1 p2 =>
      StepMore (Alt p1 p2) [arg]
    Fail =>
      StepFailure (UnexpectedError arg)

||| Helper: consume remaining arguments.
consumeArgs : Parser a -> List String -> StepResult a
consumeArgs p [] =
  case finalizeParser p of
    Just val =>
      StepSuccess (Pure val) val []
    Nothing =>
      StepFailure (MissingOption "Unsatisfied parser")
consumeArgs p (arg :: rest) =
  case p of
    Flag names _ =>
      if arg `elem` names
        then consumeArgs (Pure True) rest
        else consumeArgs p rest
    Option nm _ _ =>
      if arg `elem` nm
        then case rest of
               (val :: rest') =>
                 consumeArgs (Pure val) rest'
               [] =>
                 StepFailure (MissingOption "Option value required")
        else consumeArgs p rest
    Argument _ _ =>
      consumeArgs (Pure arg) rest
    Command _ px =>
      consumeArgs px (arg :: rest)
    Pure x =>
      StepSuccess (Pure x) x (arg :: rest)
    Fail =>
      StepFailure (UnexpectedError "Failed to parse")
    App pf pa =>
      reduceApp pf pa (arg :: rest)
    Alt p1 p2 =>
      tryLeftOrRight p1 p2 (arg :: rest)
  where
    reducePf : Parser (x -> a) -> x -> List String -> StepResult a
    reducePf pf' val args =
      case consumeArgs pf' args of
        StepSuccess _ f leftover =>
          StepSuccess (Pure (f val)) (f val) leftover
        StepFailure err =>
          StepFailure err
        StepMore p'' rest =>
          reducePf p'' val rest
    reduceApp : Parser (x -> a) -> Parser x -> List String -> StepResult a
    reduceApp pf pa args =
      case consumeArgs pa args of
        StepSuccess _ x leftover =>
          reducePf pf x leftover
        StepFailure err =>
          StepFailure err
        StepMore p' rest =>
          reduceApp pf p' rest
    tryLeftOrRight : Parser a -> Parser a -> List String -> StepResult a
    tryLeftOrRight _ _ [] =
      StepFailure (MissingOption "No arguments for alternative")
    tryLeftOrRight p1 p2 (arg :: rest) =
      case matchArg p1 arg of
        StepSuccess updatedTree val leftover =>
          consumeArgs updatedTree (leftover ++ rest)
        StepFailure _ =>
          consumeArgs p2 (arg :: rest)
        otherResult =>
          otherResult

||| Run a parser against a list of command-line arguments. 
export runParser : Parser a -> List String -> ParseResult a

runParser p args =
  case consumeArgs p args of
    StepSuccess _ val [] => Success val
    StepSuccess _ val leftover => Failure (UnexpectedError "Extra arguments provided")
    StepFailure err => Failure err
    StepMore updatedTree rest =>
      if not (null rest) then runParser updatedTree rest else case finalizeParser updatedTree of Just val => Success val Nothing => runParser updatedTree rest

mutual
  getAllFlagNames : Parser a -> List String
  getAllFlagNames (Flag names _) =
    names
  getAllFlagNames (Option _ _ _) =
    []
  getAllFlagNames (Argument _ _) =
    []
  getAllFlagNames (Command _ _) =
    []
  getAllFlagNames (Pure _) =
    []
  getAllFlagNames (App f x) =
    getAllFlagNames f ++ getAllFlagNames x
  getAllFlagNames (Alt p1 p2) =
    getAllFlagNames p1 ++ getAllFlagNames p2
  getAllFlagNames Fail =
    []
  getAllOptionNames : Parser a -> List String
  getAllOptionNames (Flag _ _) =
    []
  getAllOptionNames (Option nm _ _) =
    nm
  getAllOptionNames (Argument _ _) =
    []
  getAllOptionNames (Command _ _) =
    []
  getAllOptionNames (Pure _) =
    []
  getAllOptionNames (App f x) =
    getAllOptionNames f ++ getAllOptionNames x
  getAllOptionNames (Alt p1 p2) =
    getAllOptionNames p1 ++ getAllOptionNames p2
  getAllOptionNames Fail =
    []
  checkFlag : Parser a -> String -> Bool
  checkFlag p arg =
    arg `elem` getAllFlagNames p
  checkOpt : Parser a -> String -> Bool
  checkOpt p arg =
    arg `elem` getAllOptionNames p
-- ----------------------------------------------------------------------
-- Two-Pass Parser Implementation (Phase 2)
-- ----------------------------------------------------------------------
||| Pass 1: Scan args once, collect flag/option hits and positionals.
export collectBindings : Parser a -> List String -> CollectResult
collectBindings p args =
  scanBnds False MkParseEmptyBinds args
  where
    MkParseEmptyBinds : ParseBindings
    MkParseEmptyBinds =
      MkParseBindings [] [] []
    ||| Find actual flag names from parser tree for a matched argument.
    findFlagNames : Parser _ -> String -> Maybe (List String)
    findFlagNames (Flag names _) arg =
      if arg `elem` names then Just names else Nothing
    findFlagNames (App f x) arg =
      case findFlagNames f arg of
        Just n =>
          Just n
        Nothing =>
          findFlagNames x arg
    findFlagNames (Alt p1 p2) arg =
      case findFlagNames p1 arg of
        Just n =>
          Just n
        Nothing =>
          findFlagNames p2 arg
    findFlagNames (Command _ _) _ =
      Nothing
    findFlagNames _ _ =
      Nothing
    ||| Find actual option names from parser tree for a matched argument.
    findOptionNames : Parser _ -> String -> Maybe (List String)
    findOptionNames (Option nm _ _) arg =
      if arg `elem` nm then Just nm else Nothing
    findOptionNames (App f x) arg =
      case findOptionNames f arg of
        Just n =>
          Just n
        Nothing =>
          findOptionNames x arg
    findOptionNames (Alt p1 p2) arg =
      case findOptionNames p1 arg of
        Just n =>
          Just n
        Nothing =>
          findOptionNames p2 arg
    findOptionNames (Command _ _) _ =
      Nothing
    findOptionNames _ _ =
      Nothing
    scanBnds : Bool -> ParseBindings -> List String -> CollectResult
    scanBnds _ bnds [] =
      Collected bnds
    scanBnds afterCmd (MkParseBindings fls opts pos) (arg :: rest) =
      if afterCmd
        then scanBnds True (MkParseBindings fls opts (pos ++ [arg])) rest
        else
          if isCmdName arg
            then scanBnds True (MkParseBindings fls opts (pos ++ [arg])) rest
            else
              if checkFlag p arg
                then let names = fromMaybe [arg]
                                   (findFlagNames p arg) in scanBnds False
                                                              (MkParseBindings
                                                                 ((names, True) :: fls)
                                                                 opts
                                                                 pos)
                                                              rest
                else
                  if checkOpt p arg
                    then let names = fromMaybe [arg]
                                       (findOptionNames
                                          p
                                          arg) in case rest of
                                                              val :: rest' =>
                                                                scanBnds False
                                                                  (MkParseBindings fls
                                                                     ((names, Just val)
                                                                      ::
                                                                        opts)
                                                                     pos)
                                                                  rest'
                                                              [] =>
                                                                CollectFailure
                                                                  (MissingOption
                                                                     "Option value required")
                    else
                      if isFlagLike arg && not (checkFlag p arg) && not (checkOpt p arg)
                        then CollectFailure (UnexpectedError ("Unknown argument: " ++ arg))
                        else scanBnds False (MkParseBindings fls opts (pos ++ [arg])) rest
      where
        getAllCommandNames : Parser _ -> List String
        getAllCommandNames (Command n _) =
          [n]
        getAllCommandNames (App f x) =
          getAllCommandNames f ++ getAllCommandNames x
        getAllCommandNames (Alt p1 p2) =
          getAllCommandNames p1 ++ getAllCommandNames p2
        getAllCommandNames _ =
          []
        isCmdName : String -> Bool
        isCmdName s =
          any (\n => n == s) (getAllCommandNames p)
        isFlagLike : String -> Bool
        isFlagLike s =
          case unpack s of
            '-' :: '-' :: _ =>
              True
            '-' :: _ =>
              True
            _ =>
              False
-- double dash: --foo / --foo=bar
-- single dash: -v / -vvv
||| Pass 2: Apply collected bindings back onto the parser tree.
||| Threads positional arguments through the tree left-to-right.
||| Propagates parse errors explicitly. Returns Nothing for soft failures
||| (missing option/argument, command mismatch) so Alt backtracking works.
export applyBindings : Parser a -> ParseBindings -> ParseResult a
applyBindings p bnds =
  case goApp bnds.positionals of
    Just (Right (x, [])) =>
      Success x
    Just (Right (x, rest)) =>
      Failure (UnexpectedError ("Extra arguments provided: " ++ show rest))
    Just (Left err) =>
      Failure err
    Nothing =>
      Failure (MissingOption "Unsatisfied parser")
  where
    eqNames : List String -> List String -> Bool
    eqNames xs ys =
      any (`elem` ys) xs
    goApp : List String -> Maybe (Either ParseError (a, List String))
    goApp pos =
      go p pos
      where
        go : Parser x -> List String -> Maybe (Either ParseError (x, List String))
        go (Pure x) pos =
          Just (Right (x, pos))
        go Fail pos =
          Nothing
        go (Flag names _) pos =
          case find (\(ns, v) => eqNames ns names) bnds.flags of
            Just (_, v) =>
              Just (Right (v, pos))
            Nothing =>
              Just (Right (False, pos))
        go (Option nm _ _) pos =
          case find (\(ns, mv) => eqNames ns nm) bnds.options of
            Just (_, Just v) =>
              Just (Right (v, pos))
            _ =>
              Nothing
        go (Argument _ _) pos =
          case pos of
            [] =>
              Nothing
            (s :: t) =>
              if isCmdName s then Nothing else Just (Right (s, t))
          where
            ||| Collect all Command names from parser tree.
            getAllCommandNames : Parser _ -> List String
            getAllCommandNames (Command n _) =
              [n]
            getAllCommandNames (App f x) =
              getAllCommandNames f ++ getAllCommandNames x
            getAllCommandNames (Alt p1 p2) =
              getAllCommandNames p1 ++ getAllCommandNames p2
            getAllCommandNames _ =
              []
            ||| Check if string matches any registered command name.
            isCmdName : String -> Bool
            isCmdName s =
              any (\n => n == s) (getAllCommandNames p)
        go (Command n px) pos =
          case pos of
            [] =>
              case finalizeParser px of
                Just x =>
                  Just (Right (x, pos))
                Nothing =>
                  Nothing
            (s :: t) =>
              case s == n of
                True =>
                  let subRes = case collectBindings
                                      px
                                      t of
                                 Collected bnds' =>
                                   applyBindings px
                                     bnds'
                                 CollectFailure err =>
                                   Failure err in case subRes of
                                                            Success x =>
                                                              Just (Right (x, []))
                                                            Failure err =>
                                                              Just (Left err)
                                                            CompletionInvoked =>
                                                              Just
                                                                (Left
                                                                   (UnexpectedError
                                                                      "Completion invoked"))
                False =>
                  Nothing
        go (App pf px) pos =
          case go pf pos of
            Nothing =>
              Nothing
            Just (Left err) =>
              Just (Left err)
            Just (Right (f, pos1)) =>
              case go px pos1 of
                Nothing =>
                  Nothing
                Just (Left err) =>
                  Just (Left err)
                Just (Right (x, pos2)) =>
                  Just (Right (f x, pos2))
        go (Alt p1 p2) pos =
          case go p1 pos of
            Just (Right r) =>
              Just (Right r)
            Just (Left err) =>
              Just (Left err)
            Nothing =>
              go p2 pos

||| Filter out internal runtime arguments (paths, library refs).
isUserArg : String -> Bool
isUserArg x =
  case unpack x of
    '/' :: _ =>
      False
    '-' :: 'l' :: _ =>
      False
    '-' :: 'L' :: _ =>
      False
    _ =>
      True

||| Run a parser with explicit argument list (primary interface).
||| Uses the two-pass parser: collect bindings globally, then apply to tree.
export runParserWith : Parser a -> List String -> ParseResult a
runParserWith p args =
  case collectBindings p args of
    Collected bnds =>
      applyBindings p bnds
    CollectFailure err =>
      Failure err

||| Run a parser by fetching arguments from the environment.
export execParser : {auto _ : HasIO io} -> Parser a -> io (ParseResult a)
execParser p = do
  rawArgs <-
    getArgs
  let cleanArgs = filter isUserArg rawArgs
  pure $ runParserWith p cleanArgs

||| Run a parser and handle errors/exit. Dies on parse failure after rendering error text.
export customExecParser : {auto _ : HasIO io} -> Parser a -> io a
customExecParser p = do
  result <-
    execParser p
  case result of
    Success val =>
      pure val
    Failure err =>
      putStrLn (renderError err) >> die "parse failure"
    CompletionInvoked =>
      putStrLn "Completion invoked" >> die "completion invoked"
