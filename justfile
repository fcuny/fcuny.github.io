# Run the local HTTP server
run:
    zola serve

# Generate the content of the site under ./docs
build:
    nix build

# Format files
fmt:
    nix fmt

check:
    nix flake check

# Check that all the links are valid
check-links: build
    lychee ./result/**/*.html

# Update flake dependencies
update-deps:
    nix flake update --commit-lock-file
