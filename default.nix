# Previously nixpkgs lib was required for import.
# This retains the same interface.
builtins.warn ''
  Importing korora through the default.nix entrypoint is deprecated.
  Instead import it through types.nix without passing any function arguments:

  korora = import inputs.korora { inherit lib; };
  ->
  korora = import "''${inputs.korora}/types.nix"
'' (_: import ./types.nix)
