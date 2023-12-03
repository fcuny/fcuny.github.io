{
  projectRootFile = "flake.nix";
  programs = {
    nixfmt.enable = true; # nix
    taplo.enable = true; # toml
    yamlfmt.enable = true; # yaml
  };
}
