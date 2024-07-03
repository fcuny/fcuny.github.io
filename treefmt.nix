{
  projectRootFile = "flake.nix";
  programs = {
    nixpkgs-fmt.enable = true; # nix
    taplo.enable = true; # toml
    yamlfmt.enable = true; # yaml
    prettier.enable = true; # css
  };
  settings.formatter = {
    prettier = {
      includes = [ "*.css" "*.md" ];
      excludes = [ "*.html" ];
      options = [ "-w" ];
    };
  };
}
