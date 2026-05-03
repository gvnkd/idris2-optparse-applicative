||| Multi-value option support.
module Options.Applicative.Multi

import Options.Applicative.Types
import Data.List

-- ||| Multi-value option support. (Deferred to Phase 3 polish due to requiring interpreter-level tree accumulation)
-- export many : Parser a -> Parser (List a)
-- export some : Parser a -> Parser (List a)
-- export exactly : (n : Nat) -> Parser a -> Parser (List a)

||| Combine multiple option results.
export
concatOptions : Parser (List a) -> Parser (List a) -> Parser (List a)
concatOptions p1 p2 = App (map (\x => \y => x ++ y) p1) p2
