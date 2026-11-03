#!/usr/bin/env sh

# Set strict error checking
set -eou pipefail
LC_CTYPE=C

apk add --update --no-cache \
	bash \
	curl \
	dpkg \
	git \
	git-cliff \
	jq \
	make \
	tar \
	xz \
	zip
