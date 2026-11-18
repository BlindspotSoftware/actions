# fwci for GitLab CI jobs, see templates/fwci.gitlab-ci.yml.
FROM alpine:3.22

ARG FWCI_VERSION=latest

RUN apk add --no-cache ca-certificates curl \
 && name="fwci-${FWCI_VERSION}.linux-amd64" \
 && url="https://fwci-cli.s3.eu-central-1.amazonaws.com/${FWCI_VERSION}/${name}.tar.gz" \
 && curl -fsSL --retry 3 -o /tmp/fwci.tar.gz "$url" \
 && echo "$(curl -fsSL --retry 3 "$url.sha256")  /tmp/fwci.tar.gz" | sha256sum -c - \
 && tar -xzf /tmp/fwci.tar.gz -C /tmp "$name" \
 && mv "/tmp/$name" /usr/local/bin/fwci \
 && rm /tmp/fwci.tar.gz \
 && fwci version

# GitLab replaces CMD with the job script; only a docker:// step in GitHub Actions runs it.
CMD ["sh", "-c", "echo '::error::This image is fwci for GitLab CI. In GitHub Actions, use uses: BlindspotSoftware/actions@v8.'; exit 1"]
