||| Help text generation for CLI parsers.
module Options.Applicative.Help

import Options.Applicative.Types
import Data.List
import Data.String

-- ||| Generate usage line for a parser. (Deferred to Phase 2 due to v0.8 unification bug)
-- export usage : Parser a -> String

-- ||| Generate full help text for a parser. (Deferred to Phase 2 due to v0.8 unification bug)
-- export helpText : Parser a -> String

-- ||| Generate a brief description of available options. (Deferred to Phase 2)
-- export optionsDescription : Parser a -> String

-- ||| Align help text columns. (Deferred to Phase 2)
-- export alignColumns : List (String, String) -> String

-- ||| Format a single option description line. (Deferred to Phase 2)
-- export formatOption : String -> Maybe String -> Maybe String -> String
