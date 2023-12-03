{
  description = "Franck Cuny's personal website.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/master";
    flake-utils.url = "github:numtide/flake-utils";
    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs = { self, nixpkgs, flake-utils, pre-commit-hooks, treefmt-nix, }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        treefmtEval = treefmt-nix.lib.evalModule pkgs ./treefmt.nix;
      in
      {
        formatter = treefmtEval.config.build.wrapper;

        packages = {
          default = with pkgs;
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

        checks = {
          pre-commit-check = pre-commit-hooks.lib.${system}.run {
            src = ./.;
            hooks = {
              hugo = {
                enable = true;
                entry = "${pkgs.hugo}/bin/hugo --panicOnWarning";
                pass_filenames = false;
              };
            };
          };
          formatting = treefmtEval.config.build.check self;
        };

        apps = {
          default = {
            type = "app";
            program = "${self.packages."${system}".hugo}/bin/hugo";
          };
        };

        devShells.default = pkgs.mkShell {
          inherit (self.checks.${system}.pre-commit-check) shellHook;
          buildInputs = with pkgs; [ hugo git treefmt ];
        };
      });
}
