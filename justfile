default:
    @just --list

[group('site')]
[doc('Run the local HTTP server')]
run:
    zola serve

[group('site')]
[doc('Build the site')]
build:
    nix build

[group('nix')]
[doc('Format all the files')]
fmt:
    nix fmt

[group('nix')]
[doc('Check the flake')]
check:
    nix flake check

[group('site')]
[doc('Validate the site')]
validate: build
    lychee ./result/**/*.html

[group('nix')]
[doc('Update the dependencies')]
update-deps:
    nix flake update --commit-lock-file
