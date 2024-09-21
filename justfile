run:
	zola serve

build:
	zola build

fmt:
	treefmt

check-links: build
	lychee ./docs/**/*.html

update-deps:
	nix flake update --commit-lock-file

publish: build
	rsync -a docs/ fcuny@fcuny.net:/srv/www/fcuny.net
