+++
title = "Container Security Summit 2020"
date = 2020-02-12
[taxonomies]
tags = ["conference", "containers"]
+++

This is the second time I go to this event, organized by Google in their Seattle office (the one in Fremont).

As for last year, the content was pretty unequal. The first talk by Kelsey was interesting: one of the main concern that we have is around supply chain: where are our dependencies coming from ? We pull random libraries from all over the place, and no one read the code or try to see if there's vulnerabilities. Same is true with the firmware, bios, etc that we have in the hardware, by the way.

The second talk completely went over my head, it was really not interesting. I'm going to guess that Sky (the company that was presenting) is a big Google Cloud customer and they were asked to do that presentation.

We had a few more small talks, but nothing really great. One of the presentation was by an Australian bank (Up) and they were showing how they get slack notification when someone logs in a container. I hate this trend of sending everything to slack.

After lunch there was a few more talks, again, nothing really interesting. There's a bunch of people in this community that have a lot of hype, but are not that great presenters or don't really have anything really interesting to present.

The "un-conference" part was more interesting. There was two sessions that interested me: supply chain and PSPs. I went to the PSP one, and again, a couple of people suck all the air in the room and it's a dialogue, not a group conversation. The goal was to talk about PSP vs. OPA, but really we talked more about the challenges of PSPs and of moving out of them. The current consensus is to says that we need 3 PSPs: default, restrictive, permissive. Then all implementations (PSPs, OPA, etc) should support them, and they should offer more or less the same security level. Another thing considered is to let the CD pipeline take care of that. EKS / GKE have a challenge with a possible migration: how to move their customers, and to what.

Overall, I think we are doing the right things in term of security: we have PSPs, we have our some controllers to ensure policies, etc. We are also looking at automatically upgrade containers using workflows (having a robust CI/CD pipeline is key here).

<a id="org4ab3e9d"></a>

# Some notes to followup / read

- twitcher / host network / follow up on that
- <https://github.com/cruise-automation/k-rail>
- better error message for failures
- it's not a replacement to PSPs ?
- <https://cloud.google.com/binary-authorization>
- [falco](https://github.com/falcosecurity/falco)

conversation about isolation:

- <https://katacontainers.io/>
  - could kata be a use case for collocation of storage ?
- <https://github.com/google/gvisor>

talk about beyondprod (brandon baker)

- <https://cloud.google.com/security/beyondprod/>
- binary authorization for borg
- security infra design white paper
- questions:
  - latency for requests ? kerberos is not optimized, alts is
  - <https://cloud.google.com/security/encryption-in-transit/application-layer-transport-security>

panels:

- small adoption of OPAh

kubernetes audit logging:

- <https://kubernetes.io/docs/tasks/debug-application-cluster/audit/>
- <https://github.com/google/docker-explorer>
- <https://github.com/google/turbinia>
- <https://github.com/google/timesketch>
- plaso (?)
- <https://github.com/google/grr>
