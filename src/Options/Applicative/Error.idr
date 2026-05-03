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
missingOptionError opt = ?rhs_missingOptionError

||| Format an invalid option error.
export
invalidOptionError : String -> String -> String
invalidOptionError opt val = ?rhs_invalidOptionError

||| Format an unexpected argument error.
export
unexpectedError : String -> String
unexpectedError arg = ?rhs_unexpectedError

||| Exit with an error message.
export
exitWithError : ParseError -> IO ()
exitWithError err = ?rhs_exitWithError
