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
              buildInputs = [ zola git ];
              buildPhase = ''
                mkdir -p $out
                ${pkgs.zola}/bin/zola -o $out
              '';
              dontInstall = true;
            };
          zola = pkgs.writeShellScriptBin "zola" ''
            set -euo pipefail
            export PATH=${pkgs.lib.makeBinPath [ pkgs.zola pkgs.git ]}
            zola serve
          '';
        };

        checks = {
          pre-commit-check = pre-commit-hooks.lib.${system}.run {
            src = ./.;
            hooks = {
              nixpkgs-fmt.enable = true;
            };
          };
          formatting = treefmtEval.config.build.check self;
        };

        apps = {
          default = {
            type = "app";
            program = "${self.packages."${system}".zola}/bin/zola";
          };
        };

        devShells.default = pkgs.mkShell {
          inherit (self.checks.${system}.pre-commit-check) shellHook;
          buildInputs = with pkgs; [ zola git treefmt ];
        };
      });
}
