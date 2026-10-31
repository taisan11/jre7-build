# Local build (Linux with Docker)

```bash
bash scripts/fetch-source.sh jdk7u351-ga
bash scripts/apply-patches.sh work/openjdk
mkdir -p out
curl -fsSL https://curl.se/ca/cacert.pem -o work/cacert.pem
sha256sum work/cacert.pem > work/cacert.sha256
python3 scripts/cacerts.py --bundle work/cacert.pem --check-only
docker build -t legacy-jdk7-build:local docker
docker run --rm -v "$PWD/work/openjdk:/work/openjdk" \
  -v "$PWD/tests:/work/tests:ro" -v "$PWD/out:/work/out" \
  legacy-jdk7-build:local bash /opt/build-jdk.sh
bash scripts/package.sh work/openjdk out work/cacert.pem \
  jdk7u351-ga local local work/cacert.sha256
```

Local Docker builds reuse Docker's layer cache. In GitHub Actions, the Linux
build uses the GitHub Actions cache for the toolchain image layers and loads
the image into Docker before running it. Changes to the Dockerfile, its build
context, or the pulled base image can invalidate cached layers. The OpenJDK
build itself is not cached.

This is a best-effort legacy toolchain recipe; do not assume it builds
successfully without running it. Avoid running the EOL build container as root
with additional host privileges or binding sensitive directories.
