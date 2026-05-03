||| Multi-value option support.
module Options.Applicative.Multi

import Options.Applicative.Types
import Data.List

||| Parse multiple occurrences of an option into a list.
export
many : Parser a -> Parser (List a)
many p = ?rhs_many

||| Parse at least one occurrence of an option.
export
some : Parser a -> Parser (List a)
some p = ?rhs_some

||| Parse exactly N occurrences of an option.
export
exactly : (n : Nat) -> Parser a -> Parser (List a)
exactly n p = ?rhs_exactly

||| Combine multiple option results.
export
concatOptions : Parser (List a) -> Parser (List a) -> Parser (List a)
concatOptions p1 p2 = App (map (\x => \y => x ++ y) p1) p2
