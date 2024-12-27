{
  description = "Franck Cuny's personal website.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
    flake-utils.url = "github:numtide/flake-utils";
    pre-commit-hooks.url = "github:cachix/pre-commit-hooks.nix";
    devshell.url = "github:numtide/devshell";
    treefmt-nix.url = "github:numtide/treefmt-nix";
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      pre-commit-hooks,
      devshell,
      treefmt-nix,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [
            devshell.overlays.default
          ];
        };

        treefmt = (
          treefmt-nix.lib.mkWrapper pkgs {
            projectRootFile = "flake.nix";
            programs = {
              actionlint.enable = true;
              deadnix.enable = true;
              jsonfmt.enable = true;
              just.enable = true;
              nixfmt.enable = true;
              prettier.enable = true;
              taplo.enable = true;
              typos.enable = true;
            };
            settings.formatter.typos.excludes = [
              "*.jpeg"
              "*.jpg"
            ];
          }
        );
      in
      {
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
        };

        formatter = treefmt;

        checks = {
          pre-commit-check = pre-commit-hooks.lib.${system}.run {
            src = ./.;
            hooks = {
              treefmt = {
                enable = true;
                excludes = [ ".*" ];
              };
              check-merge-conflicts.enable = true;
              end-of-file-fixer.enable = true;
            };
          };
        };

        devShells.default = pkgs.devshell.mkShell {
          name = "zola";
          packages = with pkgs; [
            zola
            git
            treefmt
            lychee
            just
          ];
          devshell.startup.pre-commit.text = self.checks.${system}.pre-commit-check.shellHook;
          env = [
            {
              name = "DEVSHELL_NO_MOTD";
              value = "1";
            }
          ];
        };
      }
    );
}
