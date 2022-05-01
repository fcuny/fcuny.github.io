#!/usr/bin/env bash

git diff --exit-code
git diff --staged --exit-code

VERSION=$(flyctl info -j |jq -r '.App | "fcuny.net/v\(.Version)"')

git tag -a --message ${VERSION} ${VERSION}
git push origin --all
git push origin --tags
