{
  description = "Franck Cuny's personal website.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        caddyfile = ./Caddyfile;
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
                hugo --minify --destination $out
              '';
              dontInstall = true;
            };
          container = pkgs.dockerTools.buildLayeredImage {
            name = self.packages."${system}".site.pname;
            tag = self.packages."${system}".site.version;
            config = {
              Cmd = [ "${pkgs.caddy}/bin/caddy" "run" "--adapter" "caddyfile" "--config" "${caddyfile}" ];
              Env = [
                "SITE_ROOT=${self.packages."${system}".site}"
              ];
            };
          };
          deploy = pkgs.writeShellScriptBin "deploy" ''
            set -euxo pipefail
            export PATH="${pkgs.lib.makeBinPath [(pkgs.docker.override { clientOnly = true; }) pkgs.flyctl]}:$PATH"
            archive=${self.packages.x86_64-linux.container}
            # load archive, drop all output except last line case of warnings), print image name
            image=$(docker load < $archive | tail -n1 | awk '{ print $3; }')
            flyctl deploy --image $image --local-only
          '';
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
          pkgs.mkShell { buildInputs = with pkgs; [ hugo flyctl git ]; };
      });
}
