#!/usr/bin/env bash
set -euo pipefail

# args: source dir, output dir, root PEM, upstream ref, builder commit, GH run ID, digest file
src="$(realpath "${1:?source tree missing}")"
out="$(realpath "${2:?output directory missing}")"
pem="$(realpath "${3:?CA PEM missing}")"
upstream_ref="${4:?upstream ref missing}"
builder_commit="${5:?builder commit missing}"
run_id="${6:?run ID missing}"
ca_hash_file="$(realpath "${7:?CA SHA256 file missing}")"

jdk_path_file="$out/jdk-image-path.txt"
[[ -f "$jdk_path_file" ]] || { echo 'No JDK build output location' >&2; exit 1; }
jdk_relative="$(cat "$jdk_path_file")"
[[ -n "$jdk_relative" && "$jdk_relative" != /* ]] || {
  echo "Invalid source-relative JDK image path: $jdk_relative" >&2
  exit 1
}
jdk="$(realpath -m "$src/$jdk_relative")"
[[ "$jdk" == "$src/"* ]] || {
  echo "JDK image path escapes source tree: $jdk_relative" >&2
  exit 1
}
[[ -d "$jdk/jre" && -x "$jdk/bin/keytool" && -x "$jdk/jre/bin/java" ]] || {
  echo "Incomplete JDK build output at $jdk: missing JRE, keytool or java executable" >&2
  exit 1
}

jre_name=legacy-openjdk7u351-linux-x64-jre
jdk_name=legacy-openjdk7u351-linux-x64-jdk
security_smoke_classes="$out/security-smoke-classes"
mkdir -p "$security_smoke_classes"
"$jdk/bin/javac" -source 7 -target 7 -d "$security_smoke_classes" tests/SecuritySmokeTest.java

stage="$out/stage"
rm -rf "$stage"
mkdir -p "$stage/$jre_name" "$stage/$jdk_name"
cp -a "$jdk/jre/." "$stage/$jre_name/"
cp -a "$jdk/." "$stage/$jdk_name/"

# Update both archives independently. The source image is left unmodified.
for name in "$jre_name" "$jdk_name"; do
  root="$stage/$name"
  if [[ "$name" == "$jre_name" ]]; then
    keytool="$root/bin/keytool"
    # A JRE image may include keytool but source JDK's tool is guaranteed.
    [[ -x "$keytool" ]] || keytool="$jdk/bin/keytool"
    keystore="$root/lib/security/cacerts"
  else
    keytool="$root/bin/keytool"
    keystore="$root/jre/lib/security/cacerts"
  fi

  python3 scripts/cacerts.py --bundle "$pem" --keytool "$keytool" \
    --keystore "$keystore" --metadata "$root/CA-METADATA.json"

  "$root/bin/java" -version
  "$root/bin/java" -cp "$security_smoke_classes" SecuritySmokeTest

  cp "$src/LICENSE" "$root/OPENJDK-SOURCE-LICENSE.txt"
  [[ ! -f "$src/THIRD_PARTY_README" ]] || cp "$src/THIRD_PARTY_README" "$root/OPENJDK-THIRD-PARTY-README.txt"
  cat > "$root/BUILD-METADATA.txt" <<META
Upstream: https://github.com/openjdk/jdk7u
Upstream ref: $upstream_ref
Upstream commit: $(cat work/upstream-commit.txt)
Builder commit: $builder_commit
GitHub Actions run: $run_id
CA bundle source: https://curl.se/ca/cacert.pem
CA bundle SHA-256: $(cut -d ' ' -f 1 "$ca_hash_file")
Backports applied:
$(cat work/applied-patches.txt)
Known status: Experimental. Not fully security-patched.
META

  (cd "$stage" && zip --symlinks -q -r -9 "$out/$name.zip" "$name")
  (cd "$out" && sha256sum "$name.zip" > "$name.zip.sha256")
done

[[ -s "$out/$jre_name.zip" && -s "$out/$jdk_name.zip" ]]
