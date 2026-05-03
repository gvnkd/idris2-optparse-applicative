||| Environment variable fallback support. (Phase 3)
module Options.Applicative.Env

import Options.Applicative.Types

-- ||| Create a parser that falls back to an environment variable.
export envOption : List String -> String -> Parser String
envOption names envVar = Alt (Option names "ENV_VAR") (Pure ("<$" ++ envVar ++ ">"))

-- ||| Create a parser with environment fallback and default.
export envOptionWithDefault : List String -> String -> String -> Parser String
envOptionWithDefault names envVar defaultValue = Alt (Option names "ENV_VAR") (Pure defaultValue)
