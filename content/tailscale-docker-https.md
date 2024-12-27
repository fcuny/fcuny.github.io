+++
title = "Tailscale, Docker and HTTPS"
date = "2021-12-29"
+++

I run a number of services in my home network. For the majority of these services, I don't want to make them available on the internet, I want to only be able to access them when I'm on my home network. However, sometimes I'm not at home and I still want to access them. So far I've been using plain [wireguard](https://www.wireguard.com/) to achieve this. While the initial configuration for wireguard is pretty simple, it starts to be a bit more cumbersome as I add more hosts/containers. It's also not easy to share keys with other folks if I want to give access to some of the machines or services. For that reason I decided to give a look at [tailscale](https://tailscale.com/).

There's already a lot of articles about tailscale and how to use and configure it. Their [documentation](https://tailscale.com/kb/) is also pretty good, so I won't cover the initial setup.

As stated above, I want to access some of my services that are running as docker containers from anywhere. For web services, I want to use them through HTTPS, with a valid certificate, and without having to remember on which port the service it's listening. I also don't want to setup a PKI in my home lab for that (and I'm also not interested in configuring split DNS), and instead I prefer to use [let's encrypt](https://letsencrypt.org/) with a proper subdomain that is unique for each service.

The [tailscale documentation](https://tailscale.com/kb/1054/dns/) has two suggestions for this:

- use their magicDNS feature / split DNS
- setup a subdomain on a public domain

Since I already have a public domain that I use for my home network, I decided to go with the second option (I'm also uncertain how to achieve my goal using magicDNS without running tailscale inside the container).

The public domain I'm using is managed through [Google Cloud Domain](https://cloud.google.com/dns/docs/tutorials/create-domain-tutorial). I create a new record for the services I want to run (for example, `dash` for my instance of grafana), using the IP address from the tailscale node the service runs on (e.g. 100.83.51.12).

For routing the traffic I use [traefik](https://traefik.io/). The configuration for traefik looks like this:

```yaml
global:
  sendAnonymousUsage: false
providers:
  docker:
    exposedByDefault: false
entryPoints:
  http:
    address: ":80"
  https:
    address: ":443"
certificatesResolvers:
  dash:
    acme:
      email: franck@fcuny.net
      storage: acme.json
      dnsChallenge:
        provider: gcloud
```

The important bit here is the `certificatesResolvers` part. I'll be using the [dnsChallenge](https://doc.traefik.io/traefik/user-guides/docker-compose/acme-dns/) instead of the [httpChallenge](https://doc.traefik.io/traefik/user-guides/docker-compose/acme-http/) to obtain the certificate from let's encrypt. For this to work, I need to specify the `provider` to be [gcloud](https://go-acme.github.io/lego/dns/gcloud/). I'll also need a service account (see [this doc](https://cloud.google.com/docs/authentication/production#providing_credentials_to_your_application) to create it). I run `traefik` in a docker container, and the `systemd` unit file is below. The required bits for using the `dnsChallenge` with `gcloud` are:

- the environment variable `GCP_SERVICE_ACCOUNT_FILE`: it contains the credentials so that `traefik` can update the DNS record for the challenge
- the environment variable `GCP_PROJECT`: the name of the GCP project
- mounting the service account file inside the container (I store it on the host under `/data/containers/traefik/config/sa.json`)

```ini
[Unit]
Description=traefik proxy
Documentation=https://doc.traefik.io/traefik/
After=docker.service
Requires=docker.service

[Service]
Restart=on-failure
ExecStartPre=-/usr/bin/docker kill traefik
ExecStartPre=-/usr/bin/docker rm traefik
ExecStartPre=/usr/bin/docker pull traefik:latest

ExecStart=/usr/bin/docker run \
 -p 80:80 \
 -p 9080:8080 \
 -p 443:443 \
 --name=traefik \
 -e GCE_SERVICE_ACCOUNT_FILE=/var/run/gcp-service-account.json \
 -e GCE_PROJECT= gcp-super-project \
 --volume=/data/containers/traefik/config/acme.json:/acme.json \
 --volume=/data/containers/traefik/config/traefik.yml:/etc/traefik/traefik.yml:ro \
 --volume=/data/containers/traefik/config/sa.json:/var/run/gcp-service-account.json \
 --volume=/var/run/docker.sock:/var/run/docker.sock:ro \
 traefik:latest
ExecStop=/usr/bin/docker stop traefik

[Install]
WantedBy=multi-user.target
```

As an example, I run [grafana](https://grafana.com/) on my home network to view metrics from the various containers / hosts. Let's pretend I use `example.net` as my domain. I want to be able to access `grafana` via <https://dash.example.net>. Here's the `systemd` unit configuration I use for this:

```ini
[Unit]
Description=Grafana in a docker container
Documentation=https://grafana.com/docs/
After=docker.service
Requires=docker.service

[Service]
Restart=on-failure
RuntimeDirectory=grafana
ExecStartPre=-/usr/bin/docker kill grafana-server
ExecStartPre=-/usr/bin/docker rm grafana-server
ExecStartPre=-/usr/bin/docker pull grafana/grafana:latest

ExecStart=/usr/bin/docker run \
  -p 3000:3000 \
  -e TZ='America/Los_Angeles' \
  --name grafana-server \
  -v /data/containers/grafana/etc/grafana:/etc/grafana \
  -v /data/containers/grafana/var/lib/grafana:/var/lib/grafana \
  -v /data/containers/grafana/var/log/grafana:/var/log/grafana \
  --user=grafana \
  --label traefik.enable=true \
  --label traefik.http.middlewares.grafana-https-redirect.redirectscheme.scheme=https \
  --label traefik.http.middlewares.grafana-https-redirect.redirectscheme.permanent=true \
  --label traefik.http.routers.grafana-http.rule=Host(`dash.example.net`) \
  --label traefik.http.routers.grafana-http.entrypoints=http \
  --label traefik.http.routers.grafana-http.service=grafana-svc \
  --label traefik.http.routers.grafana-http.middlewares=grafana-https-redirect \
  --label traefik.http.routers.grafana-https.rule=Host(`dash.example.net`) \
  --label traefik.http.routers.grafana-https.entrypoints=https \
  --label traefik.http.routers.grafana-https.tls=true \
  --label traefik.http.routers.grafana-https.tls.certresolver=dash \
  --label traefik.http.routers.grafana-https.service=grafana-svc \
  --label traefik.http.services.grafana-svc.loadbalancer.server.port=3000 \
  grafana/grafana:latest

ExecStop=/usr/bin/docker stop unifi-controller

[Install]
WantedBy=multi-user.target
```

Now I can access my grafana instance via HTTPS (and <http://dash.example.net> would redirect to HTTPS) while my tailscale interface is up on the machine I'm using (e.g. my desktop or my phone).
