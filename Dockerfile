FROM nginx:1.30-alpine

# Default Container Environment — override with --env <key>=<value>
ENV TZ=America/New_York

# Populated by build.sh; used only for the OCI labels below.
ARG VERSION=unknown
ARG REVISION=unknown
ARG CREATED=unknown

LABEL org.opencontainers.image.title="assets" \
      org.opencontainers.image.version="${VERSION}" \
      org.opencontainers.image.revision="${REVISION}" \
      org.opencontainers.image.created="${CREATED}" \
      org.opencontainers.image.source="https://github.com/Center-for-Health-Informatics/assets"

# nginx *is* the application here, so its config is baked in rather than mounted: the
# image is self-contained, and the CORS header cannot drift from the content it applies
# to. See README — this config's redirect behaviour is coupled to chi-hermes.
COPY nginx.conf /etc/nginx/conf.d/default.conf

# The base image ships its own index.html and 50x.html here, and COPY overlays the
# directory rather than replacing it. Under the old bind-mount deploy those were hidden;
# left in place they would now be served — /assets/50x.html answering 200 with a stock
# nginx error page. Clear the root so the image serves htdocs/ and nothing else, whatever
# the base happens to ship.
RUN rm -rf /usr/share/nginx/html/*
COPY htdocs/ /usr/share/nginx/html/

EXPOSE 80
