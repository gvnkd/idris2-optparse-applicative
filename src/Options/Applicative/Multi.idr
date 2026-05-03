||| Multi-value option support. (Beta - bounded only)
module Options.Applicative.Multi

import Options.Applicative.Types
import Data.List

-- ||| Combine multiple option results using the Applicative tree structure.
export concatOptions : Parser (List a) -> Parser (List a) -> Parser (List a)
concatOptions p1 p2 = App (map (\x => \y => x ++ y) p1) p2

-- ||| Helper: build (x :: xs) applicatively from two parsers.
consApp : Parser a -> Parser (List a) -> Parser (List a)
consApp pa pl = App (map (::) pa) pl

-- ||| Parse zero to n occurrences of the given parser.
--     Fix Bug 2a: try matching first, fallback to empty list.
export manyUpTo : Nat -> Parser a -> Parser (List a)
manyUpTo Z _     = Pure []
manyUpTo (S k) p = Alt (consApp p (manyUpTo k p)) (Pure [])

-- ||| Parse one to n occurrences of the given parser.
export someUpTo : Nat -> Parser a -> Parser (List a)
someUpTo Z _     = Pure []
someUpTo (S k) p = consApp p (manyUpTo k p)

-- NOTE: unbounded many/some removed due to infinite AST expansion at construction time.
--       Use manyUpTo n / someUpTo n with explicit depth bounds instead.
