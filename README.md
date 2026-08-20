# assets
repository of common web assets

Shipped as an OCI image: nginx, its config, and `htdocs/` baked together. Downstream
apps reach it at `ASSETS_URL` (default `https://chi-tools.uc.edu/assets/`) and rely on
the wildcard `Access-Control-Allow-Origin` header in `nginx.conf` to load the fonts and
stylesheets cross-origin.

## Local preview

No compose file needed — mount the working tree over the image's content for a
live-editing loop:

```shell
podman run --rm -p 8080:80 \
  -v ./htdocs:/usr/share/nginx/html:ro \
  -v ./nginx.conf:/etc/nginx/conf.d/default.conf:ro \
  nginx:1.30-alpine
```

## Building and releasing

`VERSION` at the repository root is the single source of truth for the version — one
line, nothing else. Bump it before tagging; `build.sh` reads it to tag the built image
(`<version>`, `<version>-g<sha>`, `latest`). Releases are git-tagged `vX.Y.Z` to match.

```shell
./build.sh              # build only, nothing leaves this machine
PUSH=1 ./build.sh       # build and push all three tags to chi-tools.uc.edu
```

Pushing requires a one-time `podman login chi-tools.uc.edu`. Podman is required: the
multi-arch build uses `podman build --manifest`, not docker buildx. A dirty working tree
appends `-dirty` to the revision and refuses to push without `FORCE=1`.

### Testing a build before releasing it

`PRERELEASE=1 PUSH=1 ./build.sh` pushes **only** the `<version>-g<sha>` tag, leaving
`<version>` and `latest` where they are. Pin a test deployment's *compose.yaml* at that
exact tag to exercise a build on real infrastructure; nothing that means "this is the
release" moves until you re-run without `PRERELEASE` and tag `vX.Y.Z`. `build.sh` lists
the registry's tags afterwards so a push that claimed the wrong ones is visible
immediately.

## Deployment

The image is self-contained. The deployment host needs neither git nor a clone.

1. On the development machine: bump `VERSION`, commit, `git tag vX.Y.Z`.
2. `PUSH=1 ./build.sh`.
3. On the server, in the deployment folder: copy *etc/compose.yaml*, and
   *etc/example.containers.env* → *.env*.
4. Edit *.env* with local values (see **Network exposure**), then
   `docker compose up --detach`.
5. Subsequent releases: `docker compose up --detach --force-recreate` — `pull_policy:
   always` fetches the new `latest`. As everywhere else in this tree, `docker compose
   restart` is not a substitute.

`HTTP_PORT` is not a free choice: chi-hermes' `location /assets/` hard-codes it in its
`proxy_pass`, so changing it here means changing it there in the same deploy.
*etc/example.containers.env* carries the real value.

### Post-deploy checks

Two of these exercise couplings that are invisible from inside this repository:

- `curl -sI https://chi-tools.uc.edu/assets/uc.css` — 200, and
  `Access-Control-Allow-Origin: *` still present.
- `curl -sI https://chi-tools.uc.edu/assets/fonts` — the no-trailing-slash 301 must land
  on `https://chi-tools.uc.edu/assets/fonts/`, **not** on `:27738`. See **Do not tidy
  nginx.conf** below.
- Load chi_auth's sign-in page and confirm the fonts and `login-background.css` still
  render — that is the real cross-origin path.

### Do not tidy `nginx.conf`

chi-hermes deliberately leaves `Host` as `$proxy_host` for this backend, so that
`proxy_redirect` can rewrite the 301 nginx builds for a directory requested without a
trailing slash back onto the `/assets/` prefix. That rewrite only works while the
`Location` this server emits still matches chi-hermes' `proxy_pass` — i.e. while it names
`cetus-priv:27738`.

Adding a `server_name`, an `absolute_redirect off;`, a `port_in_redirect` change, or a
redirect-affecting `rewrite` would break `/assets/fonts` for every consumer. Baking the
config into an image is exactly the moment someone is tempted to tidy it. Don't.

`expires` is `1h`, not a long cache: nothing here is fingerprinted, so it is also the
worst-case staleness of a corrected logo or an edited stylesheet after a release. This is
a handful of internal apps, so the bandwidth an hour of caching gives up is negligible.

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
