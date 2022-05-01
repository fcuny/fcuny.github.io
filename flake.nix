{
  description = "Franck Cuny's personal website.";

  inputs = { nixpkgs.url = "github:nixos/nixpkgs"; };

  outputs = { self, nixpkgs }:
    let pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in {
      defaultApp.x86_64-linux = self.apps.server;
      apps.server = pkgs.writers.writeBashBin "server" ''
        set -e
        set -o pipefail
        PATH=${pkgs.lib.makeBinPath [ pkgs.hugo pkgs.git ]}
        hugo server
      '';
      devShell.x86_64-linux =
        pkgs.mkShell { buildInputs = with pkgs; [ hugo flyctl git ]; };
    };
}
