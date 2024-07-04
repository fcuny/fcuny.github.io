---
title: emacs' git-link and sourcegraph
date: 2021-08-24
---

I use [sourcegraph](https://sourcegraph.com/) for searching code, and I sometimes need to share a link to the source code I'm looking at in a buffer. For this, the package [`git-link`](https://github.com/sshaw/git-link) is great.

To integrate sourcegraph and `git-link`, the [documentation](https://github.com/sshaw/git-link#sourcegraph) recommends adding a remote entry named `sourcegraph` in the repository, like this:

```bash
git remote add sourcegraph https://sourcegraph.com/github.com/sshaw/copy-as-format
```

The next time you run `M-x git-link` in a buffer, it will use the URL associated with that remote. That's works great, except that now you need to add this for every repository. Instead, for my usage, I came up with the following solution:

```lisp
(use-package git-link
  :ensure t
  :after magit
  :bind (("C-c g l" . git-link)
         ("C-c g a" . git-link-commit))
  :config
  (defun fcuny/get-sg-remote-from-hostname (hostname)
    (format "sourcegraph.<$domain>.<$tld>/%s" hostname))

  (defun fcuny/git-link-work-sourcegraph (hostname dirname filename _branch commit start end)
    ;;; For a given repository, build the proper link for sourcegraph.
    ;;; Use the default branch of the repository instead of the
    ;;; current one (we might be on a feature branch that is not
    ;;; available on the remote).
    (require 'magit-branch)
    (let ((sg-base-url (fcuny/get-sg-remote-from-hostname hostname))
          (main-branch (magit-main-branch)))
      (git-link-sourcegraph sg-base-url dirname filename main-branch commit start end)))

  (defun fcuny/git-link-commit-work-sourcegraph (hostname dirname commit)
    (let ((sg-base-url (fcuny/get-sg-remote-from-hostname hostname)))
      (git-link-commit-sourcegraph sg-base-url dirname commit)))

  (add-to-list 'git-link-remote-alist '("twitter" fcuny/git-link-work-sourcegraph))
  (add-to-list 'git-link-commit-remote-alist '("twitter" fcuny/git-link-commit-work-sourcegraph))

  (setq git-link-open-in-browser 't))
```

We use different domains to host various git repositories at work (e.g. `git.$work`, `gitfoo.$work`, etc). Each of them map to a different URI for sourcegraph (e.g. `sourcegraph.$work/gitfoo`).

`git-link-commit-remote-alist` is an [association list](https://www.gnu.org/software/emacs/manual/html_node/elisp/Association-Lists.html) that takes a regular expression and a function. The custom function receives the hostname for the remote repository, which is then used to generate the URI for our sourcegraph instance. I then call `git-link-sourcegraph` replacing the hostname with the URI for sourcegraph.

Now I can run `M-x git-link` in any repository where the host for the origin git repository matches `twitter` without having to setup the custom remote first.
