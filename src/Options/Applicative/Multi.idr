||| Multi-value option support. (Stabilized for Phase 3)
module Options.Applicative.Multi

import Options.Applicative.Types
import Data.List

-- ||| Combine multiple option results using the Applicative tree structure.
export concatOptions : Parser (List a) -> Parser (List a) -> Parser (List a)
concatOptions p1 p2 = App (map (\x => \y => x ++ y) p1) p2

-- TODO: Implement many/some in Phase 3b with lazy AST nodes to avoid stack overflow in strict mode.
