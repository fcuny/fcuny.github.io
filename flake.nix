{
  description = "Franck Cuny's personal website.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/master";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        packages = {
          site = with pkgs;
            stdenv.mkDerivation {
              pname = "fcuny.net";
              version = self.lastModifiedDate;
              src = ./.;
              buildInputs = [ hugo git ];
              buildPhase = ''
                mkdir -p $out
                ${pkgs.hugo}/bin/hugo --minify --destination $out
              '';
              dontInstall = true;
            };
          hugo = pkgs.writeShellScriptBin "hugo" ''
            set -euo pipefail
            export PATH=${pkgs.lib.makeBinPath [ pkgs.hugo pkgs.git ]}
            hugo server -D
          '';
        };

        apps = {
          deploy = {
            type = "app";
            program = "${self.packages."${system}".deploy}/bin/deploy";
          };
          default = {
            type = "app";
            program = "${self.packages."${system}".hugo}/bin/hugo";
          };
        };

        defaultPackage = self.packages."${system}".container;

        devShell =
          pkgs.mkShell { buildInputs = with pkgs; [ hugo git ]; };
      });
}
