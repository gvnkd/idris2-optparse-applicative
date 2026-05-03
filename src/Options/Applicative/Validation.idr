||| Custom readers and validators. (Phase 3)
module Options.Applicative.Validation

import Options.Applicative.Types
import Data.Either

-- ||| A reader that converts a string to a typed value.
export data OptReader : Type -> Type where MkOptReader : String -> OptReader a

-- ||| Create a reader from a parsing function.
export mkReader : (a : Type) -> String -> OptReader a
mkReader _ f = MkOptReader f

-- ||| A reader that parses integers.
export autoInt : OptReader Int
autoInt = MkOptReader "int"

-- ||| A reader that parses strings (identity).
export str : OptReader String
str = MkOptReader "str"

-- ||| Validate an option value with a predicate and error message.
export validate : (pred : String -> Bool) -> (err : String) -> String -> Either String String
validate pred err val = if pred val then Right val else Left err

-- ||| A reader that parses natural numbers.
export autoNat : OptReader Nat
autoNat = MkOptReader "nat"

-- ||| A reader that parses floating point numbers.
export autoDouble : OptReader Double
autoDouble = MkOptReader "double"

-- NOTE: optionWithReader is deferred to post-alpha due to Idris 0.8 polymorphic GADT unification bugs.
-- Usage pattern: use strOption from Builder directly, then validate() on the result string.
