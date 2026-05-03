||| Custom readers and validators.
module Options.Applicative.Validation

import Options.Applicative.Types

||| A reader that converts a string to a typed value.
public export
data OptReader : Type -> Type where
  MkOptReader : String -> OptReader a

||| Create a reader from a parsing function.
export
mkReader : (a : Type) -> String -> OptReader a
mkReader _ f = MkOptReader f

||| A reader that parses integers.
export
autoInt : OptReader Int
autoInt = MkOptReader "int"

||| A reader that parses strings (identity).
export
str : OptReader String
str = MkOptReader "str"

||| Apply a reader to create a typed option parser.
export
optionWithReader :
     (names : List String)
  -> OptReader a
  -> Parser a
optionWithReader names _reader = ?rhs_optionWithReader_impl

-- ||| Add validation to a parser. (Deferred to Phase 2 due to type inference bug)
-- export validate : (a -> Maybe String) -> Parser a -> Parser a

-- ||| Create a validator from a predicate. (Deferred due to v0.8 unification bug with exported polymorphic lambdas)
-- export checkValidator : (a -> Bool) -> String -> (a -> Maybe String)
