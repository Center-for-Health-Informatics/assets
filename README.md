# assets
repository of common web assets

1. set `HTTP_PORT` and `BIND_ADDRESS` in a `.env` file (see **Network exposure**)
```dotenv
HTTP_PORT=1234
BIND_ADDRESS=192.168.80.1
```

2. start container:
```shell
docker compose up --detach
```

## Network exposure

The published port must be reachable only by chi-hermes. Published on `0.0.0.0` — the
Compose default — it is reachable from all of `10.0.0.0/8` on the UC network, and every
control applied at chi-hermes (SSO gating, address allow-lists, rate limits, security
headers) is skipped by connecting to it directly (issue
[#1](https://github.com/Center-for-Health-Informatics/assets/issues/1); same root cause as
[daedalus#73](https://github.com/Center-for-Health-Informatics/daedalus/issues/73)).

So `BIND_ADDRESS` is the deployment host's private address — on chi-cetus,
`192.168.80.1`, the private VM network. `compose.yaml` gives it no default, so an unset
value aborts the deploy rather than quietly listening on every interface.

Set it in `.env`, which is also where Compose reads `${...}` from:

```dotenv
BIND_ADDRESS=192.168.80.1
HTTP_PORT=<port published on the host>
```

A firewall rule is not a substitute: `docker-proxy` holds the port, so the container
never sees the true client address, and a ruleset can be flushed. Binding cannot.
