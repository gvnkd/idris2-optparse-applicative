||| Modifiers for configuring parser options.
module Options.Applicative.Modifiers

import Options.Applicative.Types
import Data.List

||| Option modifier configuration.
public export
record Mod where
  constructor MkMod
  longNames    : List String
  shortNames   : List String
  helpText     : Maybe String
  metavarText  : Maybe String
  defaultValue : Maybe String

||| Default modifier configuration.
export
defaultMod : Mod
defaultMod = MkMod [] [] Nothing Nothing Nothing

||| Add a long option name (e.g., "--help").
export
long : String -> Mod -> Mod
long name m@(MkMod l s h mv dv) = MkMod (name :: l) s h mv dv

||| Add a short option name (e.g., '-h').
export
short : String -> Mod -> Mod
short name m@(MkMod l s h mv dv) = MkMod l (name :: s) h mv dv

||| Set help text for an option.
export
help : String -> Mod -> Mod
help text mod = ?rhs_help

||| Set metavariable text for an option.
export
metavar : String -> Mod -> Mod
metavar text mod = ?rhs_metavar

||| Set a default value for an option.
export
value : String -> Mod -> Mod
value val mod = ?rhs_value

||| Apply modifiers to create an option parser.
export
applyMod : Mod -> Parser String
applyMod mod = ?rhs_applyMod
