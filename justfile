default:
    @just --list

[doc('Run the local HTTP server')]
[group('site')]
run:
    zola serve

[doc('Build the site')]
[group('site')]
build:
    nix build

[doc('Format all the files')]
[group('nix')]
fmt:
    nix fmt

[doc('Check the flake')]
[group('nix')]
check:
    nix flake check

[doc('Validate the site')]
[group('site')]
validate: build
    lychee ./result/**/*.html

[doc('Update the dependencies')]
[group('nix')]
update-deps:
    nix flake update --commit-lock-file
