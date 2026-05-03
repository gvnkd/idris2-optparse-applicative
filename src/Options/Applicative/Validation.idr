||| Custom readers and validators. (Phase 3)
module Options.Applicative.Validation

import Options.Applicative.Types

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

-- TODO: Implement optionWithReader and validate in Phase 3b to bypass v0.8 polymorphic unification bugs.
-- export optionWithReader : List String -> OptReader a -> Parser a
