#!/usr/bin/env nix-shell
#!nix-shell -p coreutils curl.out nix jq gnused -i bash

set -eou pipefail

cd "$(dirname "${BASH_SOURCE[0]}")"
tmpfile="$(mktemp --suffix=.nix)"

info() { echo "[INFO] $*"; }

echo_file() { echo "$@" >> "$tmpfile"; }

verlte() {
    [  "$1" = "$(echo -e "$1\n$2" | sort -V | head -n1)" ]
}

readonly nixpkgs=../../../../..

readonly current_version="$(nix-instantiate "$nixpkgs" --eval --strict -A graalvm11-ce.version | tr -d \")"

if [[ -z "${1:-}" ]]; then
  readonly gh_version="$(curl \
      ${GITHUB_TOKEN:+"-u \":$GITHUB_TOKEN\""} \
      -s https://api.github.com/repos/graalvm/graalvm-ce-builds/releases/latest | \
      jq --raw-output .tag_name)"
  readonly new_version="${gh_version//vm-/}"
else
  readonly new_version="$1"
fi

info "Current version: $current_version"
info "New version: $new_version"
if verlte "$new_version" "$current_version"; then
  info "graalvm-ce $current_version is up-to-date."
  [[ -z "${FORCE:-}" ]]  && exit 0
else
  info "graalvm-ce $current_version is out-of-date. Updating..."
fi

declare -r -A products_urls=(
  [graalvm-ce]="https://github.com/graalvm/graalvm-ce-builds/releases/download/vm-${new_version}/graalvm-ce-java@platform@-${new_version}.tar.gz"
  [native-image-installable-svm]="https://github.com/graalvm/graalvm-ce-builds/releases/download/vm-${new_version}/native-image-installable-svm-java@platform@-${new_version}.jar"
  # [ruby-installable-svm]="https://github.com/oracle/truffleruby/releases/download/vm-${new_version}/ruby-installable-svm-java@platform@-${new_version}.jar"
  # [wasm-installable-svm]="https://github.com/graalvm/graalvm-ce-builds/releases/download/vm-${new_version}/wasm-installable-svm-java@platform@-${new_version}.jar"
  # [python-installable-svm]="https://github.com/graalvm/graalpython/releases/download/vm-${new_version}/python-installable-svm-java@platform@-${new_version}.jar"
)

readonly platforms=(
  "11-linux-aarch64"
  "17-linux-aarch64"
  "11-linux-amd64"
  "17-linux-amd64"
  "11-darwin-aarch64"
  "17-darwin-aarch64"
  "11-darwin-amd64"
  "17-darwin-amd64"
)

info "Generating hashes.nix file for 'graalvm-ce' $new_version. This will take a while..."

# Indentation of `echo_file` function is on purpose to make it easier to visualize the output
echo_file "# Generated by $0 script"
echo_file "{"
for product in "${!products_urls[@]}"; do
  url="${products_urls["${product}"]}"
echo_file "  \"$product\" = {"
  for platform in "${platforms[@]}"; do
    if hash="$(nix-prefetch-url "${url//@platform@/$platform}")"; then
echo_file "    \"$platform\" = {"
echo_file "      sha256 = \"$hash\";"
echo_file "      url = \"${url//@platform@/${platform}}\";"
echo_file "    };"
    fi
  done
echo_file "  };"
done
echo_file "}"

info "Updating graalvm-ce version..."
# update-source-version does not work here since it expects src attribute
sed "s|$current_version|$new_version|" -i default.nix

info "Moving the temporary file to hashes.nix"
mv "$tmpfile" hashes.nix

info "Done!"
