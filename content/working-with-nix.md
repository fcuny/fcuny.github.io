+++
title = "working with nix"
date = 2022-05-10
[taxonomies]
tags = ["nix"]
+++

## the `nix develop` command

The `nix develop` command is for working on a repository. If our
repository contains a `Makefile`, it will be used by the various
sub-commands.

`nix develop` supports multiple
[phases](https://nixos.org/manual/nixpkgs/stable/#sec-stdenv-phases) and
they map as follow:

| phase          | default to     | command                   | note |
| -------------- | -------------- | ------------------------- | ---- |
| configurePhase | `./configure`  | `nix develop --configure` |      |
| buildPhase     | `make`         | `nix develop --build`     |      |
| checkPhase     | `make check`   | `nix develop --check`     |      |
| installPhase   | `make install` | `nix develop --install`   |      |

In the repository, running `nix develop --build` will build the binary
**using the Makefile**. This is different from running `nix build`.

## the `nix build` and `nix run` commands

### for Go

For Go, there's the `buildGoModule`. Looking at the
[source](https://github.com/NixOS/nixpkgs/blob/fb7287e6d2d2684520f756639846ee07f6287caa/pkgs/development/go-modules/generic/default.nix)
we can see there's a definition of what will be done for each phases. As
a result, we don't have to define them ourselves.

If we run `nix build` in the repository, it will run the default [build
phase](https://github.com/NixOS/nixpkgs/blob/fb7287e6d2d2684520f756639846ee07f6287caa/pkgs/development/go-modules/generic/default.nix#L171).

## `buildInputs` or `nativeBuildInputs`

- `nativeBuildInputs` is intended for architecture-dependent
  build-time-only dependencies
- `buildInputs` is intended for architecture-independent
  build-time-only dependencies
