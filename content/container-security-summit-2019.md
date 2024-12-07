+++
title = "Container Security Summit 2019"
date = 2019-02-20
[taxonomies]
tags = ["conference", "containers"]
+++

This was the 4th edition of the summit.

- [Program](https://cloudplatformonline.com/2019-NA-Container-Security-Summit-Agenda.html)
- [slides](https://cloudplatformonline.com/2019-NA-Container-Security-Summit-Agenda.html)
- [another summary](https://cloud.google.com/blog/products/containers-kubernetes/exploring-container-security-four-takeaways-from-container-community-summit-2019)

There was a number of talks and panels. Santhosh and Chris P. were there too, and they might have a different perspective.

- There was some conversation about Root-less containers
  - Running root-less containers is not there yet (it’s possible to do it, but it’s not a great experience).
  - Challenge is to have the runc daemon to not run as root
    - If you can escape the container it's game over
    - But it seems to be a goal for this year
    - Once you start mocking around with /proc you’re going to cry
  - Root-less Build for containers, however, is here, and is a good thing.
    - We talked a little bit about reproducible build.
    - Debian and some other distros / groups are putting a lot of efforts here
- Someone shared some recommendations when setting a k8s cluster
  - Don’t let Pods access node’s IAM role in metadata endpoint
    - This can be done via `networkPolicy`
  - Disable auto-mount for SA tokens
  - Prevent creation of privileged pods
  - Prevent kubelets from accessing secrets for pods on other nodes
- `ebpf` is the buzzword of the year
  - Stop using `iptables` and only use `ebpf`
- GKE on prem is clearly not for us (we knew it)
  - We talked with a Google engineer working on the product
  - You need to run vsphere, which increases the cost
    - This is likely a temporary solution
  - We would still have to deal with hardware
- During one session we talked about isolating workloads
  - We will want various clusters for various environment (dev / staging / prod)
    - This will make our life easier for upgrading them
  - Someone from Amazon (bob wise, previously head of SIG scalability) recommended namespace per service
    - They act as quota boundaries
- Google is working on tooling to manage namespaces across clusters
  - Unclear about timeline
- Google is also working on tooling to manage clusters
  - But unclear (to me) if it's for GKE, on prem, or both
- Talked about CIS benchmark for Docker and kubernetes
  - The interesting part here (IMO) was the template they use to make recommendation. This is something we should look at for our RFC process when it comes to operational work.
  - I’ll try to find that somewhere (hopefully we will get the slides)
- Auditing is a challenge because very little recommendation for hosted kubernetes
  - There’s a benchmark for Docker and k8s
  - A robust CD pipeline is required
  - That’s where organizations should invest
  - Stop patching just rebuild and deploy
  - You want to get it done fast
- Average life for a container is less than 2 weeks
- Conversations about managing security issues
  - They shared the postmortem for first high profile CVE for kubernetes
  - Someone from red hat talked about the one for runc
  - There's desire to uniformize the way to handle these type of issues
    - The guy from RH thinks the way they managed the runc one was not great (it leaked too early)
  - There's a list for vendors to communicate and share these issues
- Talked about runc issue
  - Containers are hard
  - Means different things to different people
  - We make a lot of assumptions and this break a lot of stuff
- Kubernetes secrets are not great (but no details why)
  - Concerning: no one was running kubernetes on prem, just someone with a POC and his comment was “it sucks”
- Some projects mentioned
  - In toto
  - Buildkit
  - Umoci
  - Sysdig
- Some talk about service mesh (mostly istio)
  - Getting mtls right is hard, use service mesh to get it right
- API endpoint from vm can be accessed from container
  - Google looking at ways to make this go away
  - Too much of a risk (someone showed how to exploit this on aws)
- There was a panel with a few auditing companies, I did not register anything from it
  - Container security is hard and very few people understand it
  - I don’t remember what was the context, but someone mentioned this bug as an example why containers / isolation is hard
- There’s apparently some conversations about introducing a new Tenant object
  - I have not been able to find this in tickets / mailing lists so far, would need to reach out to Google for this ?
