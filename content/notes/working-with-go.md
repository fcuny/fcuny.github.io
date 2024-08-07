---
title: Working with Go
date: 2021-08-05
---

_This document assumes go version \>= 1.16_.

## Go Modules

[Go modules](https://blog.golang.org/using-go-modules) have been added
in 2019 with Go 1.11. A number of changes were introduced with [Go
1.16](https://blog.golang.org/go116-module-changes). This document is a
reference for me so that I can find answers to things I keep forgetting.

### Creating a new module

To create a new module, run `go mod init golang.fcuny.net/m`. This will
create two files: `go.mod` and `go.sum`.

In the `go.mod` file you'll find:

- the module import path (prefixed with `module`)
- the list of dependencies (within `require`)
- the version of go to use for the module

### Versioning

To bump the version of a module:

```bash
$ git tag v1.2.3
$ git push --tags
```

Then as a user:

```bash
$ go get -d golang.fcuny.net/m@v1.2.3
```

### Updating dependencies

To update the dependencies, run `go mod tidy`

### Editing a module

If you need to modify a module, you can check out the module in your
workspace (`git clone <module URL>`).

Edit the `go.mod` file to add

```go
replace <module URL> => <path of the local checkout>
```

Then modify the code of the module and the next time you compile the
project, the cloned module will be used.

This is particularly useful when trying to debug an issue with an
external module.

### Vendor-ing modules

It's still possible to vendor modules by running `go mod vendor`. This
can be useful in the case of a CI setup that does not have access to
internet.

### Proxy

As of version 1.13, the variable `GOPROXY` defaults to
`https://proxy.golang.org,direct` (see
[here](https://github.com/golang/go/blob/c95464f0ea3f87232b1f3937d1b37da6f335f336/src/cmd/go/internal/cfg/cfg.go#L269)).
As a result, when running something like
`go get golang.org/x/tools/gopls@latest`, the request goes through the
proxy.

There's a number of ways to control the behavior, they are documented
[here](https://golang.org/ref/mod#private-modules).

There's a few interesting things that can be done when using the proxy.
There's a few special URLs (better documentation
[here](https://golang.org/ref/mod#goproxy-protocol)):

| path                  | description                                                                              |
| --------------------- | ---------------------------------------------------------------------------------------- |
| $mod/@v/list          | Returns the list of known versions - there's one version per line and it's in plain text |
| $mod/@v/$version.info | Returns metadata about a version in JSON format                                          |
| $mod/@v/$version.mod  | Returns the `go.mod` file for that version                                               |

For example, looking at the most recent versions for `gopls`:

```bash
; curl -s -L https://proxy.golang.org/golang.org/x/tools/gopls/@v/list|sort -r|head
v0.7.1-pre.2
v0.7.1-pre.1
v0.7.1
v0.7.0-pre.3
v0.7.0-pre.2
v0.7.0-pre.1
v0.7.0
v0.6.9-pre.1
v0.6.9
v0.6.8-pre.1
```

Let's check the details for the most recent version

```bash
; curl -s -L https://proxy.golang.org/golang.org/x/tools/gopls/@v/list|sort -r|head
v0.7.1-pre.2
v0.7.1-pre.1
v0.7.1
v0.7.0-pre.3
v0.7.0-pre.2
v0.7.0-pre.1
v0.7.0
v0.6.9-pre.1
v0.6.9
v0.6.8-pre.1
```

And let's look at the content of the `go.mod` for that version too:

```bash
; curl -s -L https://proxy.golang.org/golang.org/x/tools/gopls/@v/v0.7.1-pre.2.mod
module golang.org/x/tools/gopls

go 1.17

require (
        github.com/BurntSushi/toml v0.3.1 // indirect
        github.com/google/go-cmp v0.5.5
        github.com/google/safehtml v0.0.2 // indirect
        github.com/jba/templatecheck v0.6.0
        github.com/sanity-io/litter v1.5.0
        github.com/sergi/go-diff v1.1.0
        golang.org/x/mod v0.4.2
        golang.org/x/sync v0.0.0-20210220032951-036812b2e83c // indirect
        golang.org/x/sys v0.0.0-20210510120138-977fb7262007
        golang.org/x/text v0.3.6 // indirect
        golang.org/x/tools v0.1.6-0.20210802203754-9b21a8868e16
        golang.org/x/xerrors v0.0.0-20200804184101-5ec99f83aff1 // indirect
        honnef.co/go/tools v0.2.0
        mvdan.cc/gofumpt v0.1.1
        mvdan.cc/xurls/v2 v2.2.0
)
```

# Tooling

### LSP

`gopls` is the default implementation of the language server protocol
maintained by the Go team. To install the latest version, run
`go install golang.org/x/tools/gopls@latest`

### `staticcheck`

[`staticcheck`](https://staticcheck.io/) is a great tool to run against
your code to find issues. To install the latest version, run
`go install honnef.co/go/tools/cmd/staticcheck@latest`.

## Emacs integration

### `go-mode`

[This is the mode](https://github.com/dominikh/go-mode.el) to install to
get syntax highlighting (mostly).

### Integration with LSP

Emacs has a pretty good integration with LSP, and ["Eglot for better
programming experience in
Emacs"](https://whatacold.io/blog/2022-01-22-emacs-eglot-lsp/) is a good
starting point.

#### eglot

[This is the main mode to install](https://github.com/joaotavora/eglot).

The configuration is straightforward, this is what I use:

```lisp
;; for go's LSP I want to use staticcheck and placeholders for completion
(customize-set-variable 'eglot-workspace-configuration
                        '((:gopls .
                                  ((staticcheck     . t)
                                   (matcher         . "CaseSensitive")
                                   (usePlaceholders . t)))))

;; ensure we load eglot for some specific modes
(dolist (hook '(go-mode-hook nix-mode-hook))
  (add-hook hook 'eglot-ensure))
```

`eglot` integrates well with existing modes for Emacs, mainly xref,
flymake, eldoc.

## Profiling

### pprof

[pprof](https://github.com/google/pprof) is a tool to visualize
performance data. Let's start with the following test:

```go
package main

import (
    "strings"
    "testing"
)

func BenchmarkStringJoin(b *testing.B) {
    input := []string{"a", "b"}
    for i := 0; i <= b.N; i++ {
        r := strings.Join(input, " ")
        if r != "a b" {
            b.Errorf("want a b got %s", r)
        }
    }
}
```

Let's run a benchmark with
`go test . -bench=. -cpuprofile cpu_profile.out`:

```go
goos: linux
goarch: amd64
pkg: golang.fcuny.net/m
cpu: Intel(R) Core(TM) i3-1005G1 CPU @ 1.20GHz
BenchmarkStringJoin-4           41833486                26.85 ns/op            3 B/op          1 allocs/op
PASS
ok      golang.fcuny.net/m      1.327s
```

And let's take a look at the profile with
`go tool pprof cpu_profile.out`

```bash
File: m.test
Type: cpu
Time: Aug 15, 2021 at 3:01pm (PDT)
Duration: 1.31s, Total samples = 1.17s (89.61%)
Entering interactive mode (type "help" for commands, "o" for options)
(pprof) top
Showing nodes accounting for 1100ms, 94.02% of 1170ms total
Showing top 10 nodes out of 41
      flat  flat%   sum%        cum   cum%
     240ms 20.51% 20.51%      240ms 20.51%  runtime.memmove
     220ms 18.80% 39.32%      320ms 27.35%  runtime.mallocgc
     130ms 11.11% 50.43%      450ms 38.46%  runtime.makeslice
     110ms  9.40% 59.83%     1150ms 98.29%  golang.fcuny.net/m.BenchmarkStringJoin
     110ms  9.40% 69.23%      580ms 49.57%  strings.(*Builder).grow (inline)
     110ms  9.40% 78.63%     1040ms 88.89%  strings.Join
      70ms  5.98% 84.62%      300ms 25.64%  strings.(*Builder).WriteString
      50ms  4.27% 88.89%      630ms 53.85%  strings.(*Builder).Grow (inline)
      40ms  3.42% 92.31%       40ms  3.42%  runtime.nextFreeFast (inline)
      20ms  1.71% 94.02%       20ms  1.71%  runtime.getMCache (inline)
```

We can get a breakdown of the data for our module:

```bash
(pprof) list golang.fcuny.net
Total: 1.17s
ROUTINE ======================== golang.fcuny.net/m.BenchmarkStringJoin in /home/fcuny/workspace/gobench/app_test.go
     110ms      1.15s (flat, cum) 98.29% of Total
         .          .      5:   "testing"
         .          .      6:)
         .          .      7:
         .          .      8:func BenchmarkStringJoin(b *testing.B) {
         .          .      9:   b.ReportAllocs()
      10ms       10ms     10:   input := []string{"a", "b"}
         .          .     11:   for i := 0; i <= b.N; i++ {
      20ms      1.06s     12:           r := strings.Join(input, " ")
      80ms       80ms     13:           if r != "a b" {
         .          .     14:                   b.Errorf("want a b got %s", r)
         .          .     15:           }
         .          .     16:   }
         .          .     17:}
```
