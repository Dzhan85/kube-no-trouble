#!/usr/bin/env sh

# Package a kubent binary into the native installer format for its OS:
#   linux   -> .deb  (requires dpkg-deb)
#   windows -> .zip  (requires zip)
#   darwin  -> .pkg  (requires pkgbuild/productbuild, i.e. macOS)
#
# Usage: scripts/package.sh <os> <arch> <binary> <version> [output-dir]

# Set strict error checking
set -eu
LC_CTYPE=C

if [ $# -lt 4 ]; then
	echo "Usage: $0 <os> <arch> <binary> <version> [output-dir]" >&2
	exit 1
fi

OS="$1"
ARCH="$2"
BINARY="$3"
VERSION="$4"
OUT_DIR="${5:-release-artifacts}"
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

mkdir -p "${OUT_DIR}"
OUT_DIR="$(cd "${OUT_DIR}" && pwd)"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

# Package managers need a version that starts with a digit:
# "0.8.0" -> "0.8.0", "nightly-0.7.3-43-g2366d92" -> "0.7.3+43+g2366d92", "dev" -> "0.0.0~dev"
NUMERIC_VERSION="$(echo "${VERSION}" | sed -e 's/^nightly-//' -e 's/^v//' -e 's/-/+/g')"
case "${NUMERIC_VERSION}" in
	[0-9]*) ;;
	*) NUMERIC_VERSION="0.0.0~${NUMERIC_VERSION}" ;;
esac

case "${OS}" in
linux)
	PKG_ROOT="${WORK_DIR}/root"
	install -Dm0755 "${BINARY}" "${PKG_ROOT}/usr/bin/kubent"
	install -Dm0644 "${REPO_ROOT}/LICENSE" "${PKG_ROOT}/usr/share/doc/kubent/copyright"
	mkdir -p "${PKG_ROOT}/DEBIAN"
	cat >"${PKG_ROOT}/DEBIAN/control" <<EOF
Package: kubent
Version: ${NUMERIC_VERSION}
Section: admin
Priority: optional
Architecture: ${ARCH}
Maintainer: kube-no-trouble maintainers <noreply@github.com>
Homepage: https://github.com/doitintl/kube-no-trouble
Description: Kube No Trouble - find deprecated Kubernetes APIs
 kubent scans a Kubernetes cluster, Helm releases and local manifests
 for usage of deprecated and removed Kubernetes APIs.
EOF
	dpkg-deb --root-owner-group -Zxz --build "${PKG_ROOT}" \
		"${OUT_DIR}/kubent_${NUMERIC_VERSION}_${ARCH}.deb" >/dev/null
	echo "${OUT_DIR}/kubent_${NUMERIC_VERSION}_${ARCH}.deb"
	;;
windows)
	cp "${BINARY}" "${WORK_DIR}/kubent.exe"
	cp "${REPO_ROOT}/LICENSE" "${WORK_DIR}/LICENSE.txt"
	(cd "${WORK_DIR}" && zip -q -9 "${OUT_DIR}/kubent-${VERSION}-windows-${ARCH}.zip" kubent.exe LICENSE.txt)
	echo "${OUT_DIR}/kubent-${VERSION}-windows-${ARCH}.zip"
	;;
darwin)
	case "${ARCH}" in
	arm64) HOST_ARCH="arm64" ;;
	amd64) HOST_ARCH="x86_64" ;;
	*) echo "Unsupported darwin architecture: ${ARCH}" >&2 && exit 1 ;;
	esac
	# pkg versions must be dot-separated numbers
	PKG_VERSION="$(echo "${NUMERIC_VERSION}" | sed 's/[^0-9.].*//')"
	mkdir -p "${WORK_DIR}/root"
	cp "${BINARY}" "${WORK_DIR}/root/kubent"
	chmod 0755 "${WORK_DIR}/root/kubent"
	codesign -s - -f --identifier com.doitintl.kubent "${WORK_DIR}/root/kubent"
	pkgbuild --quiet --root "${WORK_DIR}/root" --identifier com.doitintl.kubent \
		--version "${PKG_VERSION}" --install-location /usr/local/bin "${WORK_DIR}/kubent-component.pkg"
	cat >"${WORK_DIR}/distribution.xml" <<EOF
<?xml version="1.0" encoding="utf-8"?>
<installer-gui-script minSpecVersion="2">
    <title>kubent ${VERSION} (Kube No Trouble)</title>
    <options customize="never" require-scripts="false" hostArchitectures="${HOST_ARCH}"/>
    <volume-check>
        <allowed-os-versions>
            <os-version min="13.0"/>
        </allowed-os-versions>
    </volume-check>
    <domains enable_localSystem="true"/>
    <choices-outline>
        <line choice="default"/>
    </choices-outline>
    <choice id="default" title="kubent">
        <pkg-ref id="com.doitintl.kubent"/>
    </choice>
    <pkg-ref id="com.doitintl.kubent" version="${PKG_VERSION}" onConclusion="none">kubent-component.pkg</pkg-ref>
</installer-gui-script>
EOF
	productbuild --quiet --distribution "${WORK_DIR}/distribution.xml" --package-path "${WORK_DIR}" \
		"${OUT_DIR}/kubent-${VERSION}-macos-${ARCH}.pkg"
	echo "${OUT_DIR}/kubent-${VERSION}-macos-${ARCH}.pkg"
	;;
*)
	echo "Unsupported OS: ${OS}" >&2
	exit 1
	;;
esac
