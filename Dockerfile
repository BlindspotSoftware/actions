# fwci and fwci-ci for GitLab CI jobs and Jenkins Pipelines, see templates/fwci.gitlab-ci.yml and the
# README.
FROM alpine:3.22

ARG FWCI_VERSION=latest

# git, as a Jenkins checkout in a docker agent runs in the container.
RUN apk add --no-cache ca-certificates curl git \
 && name="fwci-${FWCI_VERSION}.linux-amd64" \
 && url="https://fwci-cli.s3.eu-central-1.amazonaws.com/${FWCI_VERSION}/${name}.tar.gz" \
 && curl -fsSL --retry 3 -o /tmp/fwci.tar.gz "$url" \
 && echo "$(curl -fsSL --retry 3 "$url.sha256")  /tmp/fwci.tar.gz" | sha256sum -c - \
 && tar -xzf /tmp/fwci.tar.gz -C /tmp "$name" \
 && mv "/tmp/$name" /usr/local/bin/fwci \
 && rm /tmp/fwci.tar.gz \
 && fwci version

COPY fwci-ci /usr/local/bin/

# GitLab and Jenkins replace CMD; only a docker:// step in GitHub Actions runs it.
CMD ["sh", "-c", "echo '::error::This image is fwci for GitLab CI and Jenkins. In GitHub Actions, use uses: BlindspotSoftware/actions@v8.'; exit 1"]
