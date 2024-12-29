[My personal site](https://fcuny.net).

## Run

Running `just run` will start the `zola` server.

## Build

Running `just build` will build the site, and the content will be available under `result/`.

## Deploy

The site is deployed by a [GHA](.github/workflows/page.yml).

## Maintenance

Running `just validate` will run some validations (checking the links for example).

A few GHA are taking care of checking the validity of the flake, and will report if the [flake.lock](flake.lock) is out of date.

Another GHA will run periodically to bump the [flake.lock](flake.lock).
