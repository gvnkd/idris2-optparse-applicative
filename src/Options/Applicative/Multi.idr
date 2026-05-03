||| Multi-value option support. (Stabilized for Phase 3)
module Options.Applicative.Multi

import Options.Applicative.Types
import Data.List

-- ||| Combine multiple option results using the Applicative tree structure.
export concatOptions : Parser (List a) -> Parser (List a) -> Parser (List a)
concatOptions p1 p2 = App (map (\x => \y => x ++ y) p1) p2

-- ||| Helper: build (x :: xs) applicatively from two parsers.
consApp : Parser a -> Parser (List a) -> Parser (List a)
consApp pa pl = App (map (::) pa) pl

-- ||| Parse zero or more occurrences of the given parser.
export many : Parser a -> Parser (List a)
many p = Alt (Pure []) (consApp p (many p))

-- ||| Parse zero to n occurrences of the given parser.
export manyUpTo : Nat -> Parser a -> Parser (List a)
manyUpTo Z _     = Pure []
manyUpTo (S k) p = Alt (Pure []) (consApp p (manyUpTo k p))

-- ||| Parse one or more occurrences of the given parser.
export some : Parser a -> Parser (List a)
some p = consApp p (many p)

-- ||| Parse one to n occurrences of the given parser.
export someUpTo : Nat -> Parser a -> Parser (List a)
someUpTo Z _     = Pure []
someUpTo (S k) p = consApp p (manyUpTo k p)
