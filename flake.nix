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
        defaultApp = pkgs.writers.writeBashBin "run-hugo" ''
          set -e
          set -o pipefail
          export PATH=${pkgs.lib.makeBinPath [ pkgs.hugo pkgs.git ]}
          hugo server -D
        '';

        devShell =
          pkgs.mkShell { buildInputs = with pkgs; [ hugo flyctl git ]; };
      });
}
