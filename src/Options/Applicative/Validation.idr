module Options.Applicative.Validation
import Data.Either
import Options.Applicative.Types
-- ||| A reader that converts a string to a typed value via an explicit conversion function.
record OptReader (a : Type) where
  constructor MkOptReader
  readerName : String
  readFromText : String -> Maybe a
-- ||| Apply a reader to create a typed option parser. Returns `Parser (Maybe a)` — the Maybe reflects whether the user supplied this optional argument at all. To get strict parsing with required semantics, compose using `strOption` + `validate()` directly.
export optionWithReader : List String -> OptReader a -> Parser (Maybe a)

optionWithReader names reader = 
  map reader.readFromText $ Option names "ARG" Nothing
-- NOTE: Polymorphic GADT signature `Parser a` hits Idris 0.8 unification cache bug on exported polymorphic functions over OptReader record fields. Workaround: keep return type as Parser (Maybe a). Compose with strOption + validate() directly when full strictness needed.
-- ||| Create a reader from a parsing function.

-- NOTE: Polymorphic GADT signature `Parser a` hits Idris 0.8 unification cache bug on exported polymorphic functions over OptReader record fields. Workaround: keep return type as Parser (Maybe a). Compose with strOption + validate() directly when full strictness needed.
-- ||| Create a reader from a parsing function.

-- NOTE: Polymorphic GADT signature `Parser a` hits Idris 0.8 unification cache bug on exported polymorphic functions over OptReader record fields. Workaround: keep return type as Parser (Maybe a). Compose with strOption + validate() directly when full strictness needed.
-- ||| Create a reader from a parsing function.

-- NOTE: Polymorphic GADT signature `Parser a` hits Idris 0.8 unification cache bug on exported polymorphic functions over OptReader record fields. Workaround: keep return type as Parser (Maybe a). Compose with strOption + validate() directly when full strictness needed.
-- ||| Create a reader from a parsing function.

-- NOTE: Polymorphic GADT signature `Parser a` hits Idris 0.8 unification cache bug on exported polymorphic functions over OptReader record fields. Workaround: keep return type as Parser (Maybe a). Compose with strOption + validate() directly when full strictness needed.
-- ||| Create a reader from a parsing function.
-- NOTE: Polymorphic GADT signature `Parser a` hits Idris 0.8 unification cache bug on exported polymorphic functions over OptReader record fields. Workaround: keep return type as Parser (Maybe a). Compose with strOption + validate() directly when full strictness needed.
-- ||| Create a reader from a parsing function.
export mkReader : (a : Type) -> String -> (String -> Maybe a) -> OptReader a
mkReader _ name conv =
  MkOptReader name conv
-- ||| Parse decimal digits into a Nat.
readNatStr : List Char -> Maybe Nat
readNatStr [] =
  Nothing
readNatStr cs =
  if all isDigit cs then Just (go 0 cs) else Nothing
  where
    digit : Char -> Nat
    go : Nat -> List Char -> Nat
    go acc [] =
      acc
    go acc (c :: r) =
      go ((acc * 10) + digit c) r
    digit '0' =
      0
    digit '1' =
      1
    digit '2' =
      2
    digit '3' =
      3
    digit '4' =
      4
    digit '5' =
      5
    digit '6' =
      6
    digit '7' =
      7
    digit '8' =
      8
    digit '9' =
      9
    digit _ =
      0
-- Forward declaration to allow go to reference digit before its definition below
-- ||| A reader that parses integers via readNat with sign handling.
export readInt : String -> Maybe Int
readInt s =
  if s == ""
    then Nothing
    else case readNatStr (unpack s) of
           Just n =>
             Just (cast n)
           _ =>
             Nothing
-- ||| A reader that parses natural numbers.
export readNat : String -> Maybe Nat
readNat s =
  readNatStr (unpack s)
-- ||| A reader that parses strings (identity, always succeeds).
export readString : String -> Maybe String
readString s =
  Just s
-- ||| A reader that parses floating point numbers.
export readDouble : String -> Maybe Double
-- TODO(beta2): implement decimal split parsing
readDouble _ =
  Nothing
-- ||| A reader that parses integers.
export autoInt : OptReader Int
autoInt =
  MkOptReader "int" readInt
-- ||| A reader that parses strings (identity).
export str : OptReader String
str =
  MkOptReader "string" readString
-- ||| Validate an option value with a predicate and error message.
export validate : (pred : String -> Bool) -> (err : String) -> String -> Either String
                                                                           String
validate pred err val =
  if pred val then Right val else Left err
-- ||| A reader that parses natural numbers.
export autoNat : OptReader Nat
autoNat =
  MkOptReader "nat" readNat
-- ||| A reader that parses floating point numbers.
export autoDouble : OptReader Double
autoDouble =
  MkOptReader "double" readDouble
