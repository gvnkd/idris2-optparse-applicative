||| Error handling and reporting.
module Options.Applicative.Error

import Options.Applicative.Types
import Data.String

||| Render a parse error as a human-readable string.
export
renderError : ParseError -> String
renderError err = 
    case err of
        MissingOption opt      => "error: Missing option " ++ opt
        InvalidOption o val    => "error: Invalid value for " ++ o ++ ": " ++ val
        UnexpectedError arg     => "error: Unexpected argument: " ++ arg

||| Format a missing option error.
export
missingOptionError : String -> String
missingOptionError opt = "Missing required option: " ++ opt

||| Format an invalid option error.
export
invalidOptionError : String -> String -> String
invalidOptionError opt val = "Invalid value for option " ++ opt ++ ": " ++ val

||| Format an unexpected argument error.
export
unexpectedError : String -> String
unexpectedError arg = "Unexpected argument: " ++ arg

||| Exit with an error message.
export
exitWithError : ParseError -> IO ()
exitWithError err = putStrLn $ renderError err
