{
  description = "Franck Cuny's personal website.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/master";
    flake-utils.url = "github:numtide/flake-utils";
    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
  };

  outputs =
    { self
    , nixpkgs
    , flake-utils
    , pre-commit-hooks
    ,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
      in
      {
        apps = {
          default = {
            type = "app";
            program = "${self.packages."${system}".zola}/bin/zola";
          };
        };

        packages = {
          default =
            with pkgs;
            stdenv.mkDerivation {
              pname = "fcuny.net";
              version = self.lastModifiedDate;
              src = ./.;
              buildInputs = [
                zola
                git
              ];
              buildPhase = ''
                mkdir -p $out
                ${pkgs.zola}/bin/zola build -o $out -f
              '';
              dontInstall = true;
            };
          zola = pkgs.writeShellScriptBin "zola" ''
            set -euo pipefail
            export PATH=${
              pkgs.lib.makeBinPath [
                pkgs.zola
                pkgs.git
              ]
            }
            zola serve
          '';
        };

        checks = {
          pre-commit-check = pre-commit-hooks.lib.${system}.run {
            src = ./.;
            hooks = {
              nixpkgs-fmt.enable = true;
              check-toml.enable = true;
              check-yaml.enable = true;
              check-merge-conflicts.enable = true;
              end-of-file-fixer.enable = true;
              actionlint.enable = true;
            };
          };
        };

        devShells.default = pkgs.mkShell {
          inherit (self.checks.${system}.pre-commit-check) shellHook;
          buildInputs = with pkgs; [
            zola
            git
            treefmt
            lychee
            just
            taplo
            nodePackages.prettier
            awscli
            imagemagick
            exiftool
          ];
        };
      }
    );
}
