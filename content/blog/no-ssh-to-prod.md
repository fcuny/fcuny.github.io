+++
title = "No SSH to production"
date = 2022-11-28
[taxonomies]
tags = ["practices"]
+++

It's not uncommon to hear talk about preventing engineers to SSH to production machines. While I think it's a noble goal, I think most organizations are not ready for it in the short or even medium term.

Why do we usually need to get a shell on a machine ? The most common reason is to investigate a system that is behaving in an unexpected way, and we need to collect information, maybe using `strace`, `tcpdump`, `perf` or one of the BCC tools. Another reason might be to validate that a change deployed to a single machine is applied correctly, before rolling it out to a large portion of the fleet.

If you end up writing a postmortem after the investigation session, one of the reviewer might ask why did we need to get a shell on the machine in the first place. Usually it's because we're lacking the capabilities to collect that kind of information remotely. Someone will write an action item to improve this, it will be labeled 'long-term-action-item', and it will disappear in the bottomless backlog of a random team (how many organizations have a clear ownership for managing access to machines ?).

In most cases, I think we would be better off by breaking down the problems in smaller chunk, and focus on iterative improvements. "No one gets to SSH to machines in production" is a poorly framed problem.

What I think is better is to ask the following questions

- who has access to the machines
- who actually SSH to the machines
- why do they need to SSH to the machines
- was the state of the machine altered after someone logged to the machine

For the first question, I'd recommend that we don't create user accounts and don't distribute engineers' SSH public keys on the machines. I'd create an 'infra' user account, and use signed SSH certificates (for example with [vault](https://www.hashicorp.com/products/vault/ssh-with-vault)). Only engineers who _have_ to have access should be able to sign their SSH key. That way you've limited the risks to a few engineers, and you have an audit trail of who requested access. You can build reports from these audit logs, to see how frequently engineer request access. For the 'infra' user, I'd limit it's privileges, and make sure it can only run commands required for debugging/troubleshooting.

Using linux' audit logs, you can also generate reports on which commands are run. You can learn why the engineers needed to get on the host, and it can be used by the SRE organization to build services and tools that will enable new capabilities (for example, a service to collect traces, or do network capture remotely).

Using the same audit logs, look for commands that are modifying the filesystems (for example `apt`, `yum`, `mkdir`): if the hosts are stateless, send them through the provisioning pipeline.

At that point you've hardened the system, and you get visibility into what engineers are doing on these machines. Having engineers being able to get a shell on a production machine is a high risk: even if your disks are encrypted at rest, when the host is running an engineer can see data they are not supposed to look at, etc. But I think knowing who/when/why is more important than completely blocking SSH access: there's always going to be that one incident where there's nothing you can do without a shell on that one host.
