{
  description = "Decrypt CIA and 3DS roms in UNIX environments";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages = {
          default = pkgs.callPackage ./default.nix { };
          cia-unix = pkgs.callPackage ./default.nix { };
        };

        apps = {
          default = {
            type = "app";
            program = "${self.packages.${system}.default}/bin/cia-unix";
          };
        };

        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            crystal
            unzip
          ];
        };
      }
    );
}
