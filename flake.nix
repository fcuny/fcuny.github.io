{
  description = "Franck Cuny's personal website.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let pkgs = nixpkgs.legacyPackages.${system};
      in {
        defaultPackage = with pkgs;
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
        defaultApp = pkgs.writers.writeBashBin "run-hugo" ''
          set -e
          set -o pipefail
          export PATH=${pkgs.lib.makeBinPath [ pkgs.hugo pkgs.git ]}
          hugo server -D
        '';

        deploy = pkgs.writers.writeBashBin "run-deploy" ''
          set -e
          set -o pipefile
          export PATH=${
            pkgs.lib.makeBinPath [ pkgs.hugo pkgs.git pkgs.jq pkgs.flyctl ]
          }
          ./scripts/deploy.sh
        '';

        devShell =
          pkgs.mkShell { buildInputs = with pkgs; [ hugo flyctl git jq ]; };
      });
}
