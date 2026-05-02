||| Environment variable fallback support.
module Options.Applicative.Env

import Options.Applicative.Types
import System

||| Create a parser that falls back to an environment variable.
export
envOption : (names : List String) -> (envVar : String) -> Parser String
envOption names envVar = ?rhs_envOption

||| Create a parser with environment fallback and default.
export
envOptionWithDefault :
     (names : List String)
  -> (envVar : String)
  -> (defaultValue : String)
  -> Parser String
envOptionWithDefault names envVar defaultValue = ?rhs_envOptionWithDefault

||| Read an environment variable safely.
export
readEnv : String -> IO (Maybe String)
readEnv var = ?rhs_readEnv
