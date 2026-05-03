-- ||| Subcommand support for CLI parsers. (Deferred to Phase 3 polish, core Alt logic is already in Builder.idr)
module Options.Applicative.Subparser

import Options.Applicative.Types

-- public export record SubparserConfig a where ...
-- export commands : List (String, Parser a) -> SubparserConfig a
-- export progDesc : String -> SubparserConfig a -> SubparserConfig a
-- export mkSubparser : SubparserConfig a -> Parser a
-- export lookupCommand : String -> SubparserConfig a -> Maybe (Parser a)
