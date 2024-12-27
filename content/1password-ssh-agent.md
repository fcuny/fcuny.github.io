+++
title = "1password's ssh agent and nix"
date = 2023-12-02
+++

[A while ago](https://blog.1password.com/1password-ssh-agent/), 1password introduced an SSH agent, and I've been using it for a while now. The following describe how I've configured it with `nix`. All my ssh keys are in 1password, and it's the only ssh agent I'm using at this point.

## Personal configuration

I have a personal 1password account, and I've created a new SSH key in it that I use for both authenticating to github and to sign commits. I use [nix-darwin](http://daiderd.com/nix-darwin/) and [home-manager](https://github.com/nix-community/home-manager) to configure my personal machine.

This is how I configure ssh:

```nix
programs.ssh = {
  enable = true;
  forwardAgent = true;
  serverAliveInterval = 60;
  controlMaster = "auto";
  controlPersist = "30m";
  extraConfig = ''
    IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
  '';
  matchBlocks = {
    "github.com" = {
      hostname = "github.com";
      user = "git";
      forwardAgent = false;
      extraOptions = { preferredAuthentications = "publickey"; };
    };
  };
};
```

The configuration for git:

```nix
{ lib, pkgs, config, ... }:
let
  sshPub = builtins.fromTOML (
    builtins.readFile ../../configs/ssh-pubkeys.toml
  );
in
{
  home.file.".ssh/allowed_signers".text = lib.concatMapStrings (x: "franck@fcuny.net ${x}\n") (with sshPub; [ ykey-laptop ykey-backup op ]);

  programs.git = {
    enable = true;
    userName = "Franck Cuny";
    userEmail = "franck@fcuny.net";

    signing = {
      key = "key::${sshPub.op}";
      signByDefault = true;
    };

    extraConfig = {
      gpg.format = "ssh";
      gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signers";
      gpg.ssh.program = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";
  };
}
```

In the repository with my nix configuration, I've a file `ssh-pubkeys.toml` that contains all the public ssh keys I keep track of (mine and a few other developers). Keys from that file are used to create the file `~/.ssh/allowed_signers` that is then used by `git` (for example `git log --show-signature`) when I want to ensure commits are signed with a valid key.

`ssh-pubkeys.toml` looks like this:

```toml
# yubikey key connected to the laptop
ykey-laptop="ssh-ed25519 ..."
# backup yubikey key
ykey-backup="ssh-ed25519 ..."
# 1password key
op="ssh-ed25519 ..."
```

And the following is for `zsh` so that I can use the agent for other commands that I run in the shell:

```nix
programs.zsh.envExtra = ''
  # use 1password ssh agent
  # see https://developer.1password.com/docs/ssh/get-started#step-4-configure-your-ssh-or-git-client
  export SSH_AUTH_SOCK=~/Library/Group\ Containers/2BUA8C4S2C.com.1password/t/agent.sock
'';
```

And that's it, this is enough to get use the agent for all my personal use cases.

## Work configuration

The work configuration is slightly different. Here I want to use both my work and personal keys so that I can clone some of my personal repositories on the work machine (for example my emacs configuration). We also use both github.com and a github enterprise instance and I need to authenticate against both.

I've imported my existing keys into 1password, and I keep the public keys on the disk: `$HOME/.ssh/work_gh.pub` and `$HOME/.ssh/personal_gh.pub`. I've removed the private keys from the disk.

This is the configuration I use for work:

```nix
programs.ssh = {
  enable = true;
  forwardAgent = true;
  serverAliveInterval = 60;
  controlMaster = "auto";
  controlPersist = "30m";
  extraConfig = ''
    IdentityAgent "~/Library/Group Containers/2BUA8C4S2C.com.1password/t/agent.sock"
  '';
  matchBlocks = {
    "personal" = {
      hostname = "github.com";
      user = "git";
      forwardAgent = false;
      identifyFile = "~/.ssh/personal_gh.pub";
      identitiesOnly = true;
      extraOptions = { preferredAuthentications = "publickey"; };
    };
    "work" = {
      hostname = "github.com";
      user = "git";
      forwardAgent = false;
      identifyFile = "~/.ssh/work_gh.pub";
      identitiesOnly = true;
      extraOptions = { preferredAuthentications = "publickey"; };
    };
    "github.enterprise" = {
      hostname = "github.enterprise";
      user = "git";
      forwardAgent = false;
      identifyFile = "~/.ssh/work_gh.pub";
      identitiesOnly = true;
      extraOptions = { preferredAuthentications = "publickey"; };
    };
  };
};
```

I also create a configuration file for the 1password agent, to make sure I can use the keys from all the accounts:

```nix
 # Generate ssh agent config for 1Password - I want both my personal and work keys
 home.file.".config/1Password/ssh/agent.toml".text = ''
   [[ssh-keys]]
   account = "my.1password.com"
   [[ssh-keys]]
   account = "$work.1password.com"
 '';
```

Then the ssh configuration:

```nix
{ config, lib, pkgs, ... }:
let
 sshPub = builtins.fromTOML (
   builtins.readFile ../etc/ssh-pubkeys.toml
 );
in
{
 home.file.".ssh/allowed_signers".text = lib.concatMapStrings (x: "franck@fcuny.net ${x}\n") (with sshPub; [ work_laptop op ]);

 programs.git = {
   enable = true;

   signing = {
     key = "key::${sshPub.op}";
     signByDefault = true;
   };

   extraConfig = {
     gpg.format = "ssh";
     gpg.ssh.allowedSignersFile = "~/.ssh/allowed_signers";
     gpg.ssh.program = "/Applications/1Password.app/Contents/MacOS/op-ssh-sign";

     url = {
       "ssh://git@github.enterprise/" = {
         insteadOf = "https://github.enterprise/";
       };
     };
   };
 };
}
```

Now, when I clone a repository, instead of doing `git clone git@github.com/$WORK/repo` I do `git clone work:/$WORK/repo`.

## Conclusion

I've used yubikey to sign my commits for a while, but I find the 1password ssh agent a bit more convenient. The initial setup for yubikey was not as straightforward (granted, it's a one time thing per key).

On my personal machine, my `$HOME/.ssh` looks as follow:

```sh
➜  ~ ls -l ~/.ssh                                                                                                                           ~
total 16
lrwxr-xr-x@ 1 fcuny  staff    83 Nov  6 17:03 allowed_signers -> /nix/store/v9qhbr2vb7w6bd24ypbjjz59xis3g8y2-home-manager-files/.ssh/allowed_signers
lrwxr-xr-x@ 1 fcuny  staff    74 Nov  6 17:03 config -> /nix/store/v9qhbr2vb7w6bd24ypbjjz59xis3g8y2-home-manager-files/.ssh/config
-rw-------@ 1 fcuny  staff   828 Nov 13 17:53 known_hosts
```

When I create a new commit, 1password ask me to authorize git to use the agent and sign the commit. Same when I want to ssh to a host.

When I'm working on the macbook, I use touch ID to confirm, and when the laptop is connected to a dock, I need to type my 1password's password to unlock it and authorize the command.

There's a cache in the agent so I'm not prompted too often. I find this convenient, I will never have to copy my ssh key when I get a new laptop, since it's already in 1password.

The agent has worked flawlessly so far, and I'm happy with this setup.
