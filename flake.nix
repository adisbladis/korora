{
  description = "A simple & fast Nix type system implemented in Nix";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }: (
    let
      inherit (nixpkgs) lib;
    in
    {
      libTests = import ./tests.nix { inherit lib; };
      lib = let
        types = import ./default.nix { inherit lib; };
      in types // {
        inherit types;
      };
    }
    //
    flake-utils.lib.eachDefaultSystem
    (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        devShells.default = pkgs.callPackage ./shell.nix { };
      }
    )
  );
}
