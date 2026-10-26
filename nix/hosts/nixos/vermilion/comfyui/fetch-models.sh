#!/usr/bin/env bash
set -euo pipefail

manifest=$1
models_directory=$2

verify_model() {
  local file=$1 checksum=$2
  printf '%s  %s\n' "$checksum" "$file" | sha256sum --check --status
}

while IFS=$'\t' read -r directory name url sha256; do
  destination="$models_directory/$directory/$name"
  checksum_file="$destination.sha256"
  partial="$destination.part"
  mkdir -p "$(dirname "$destination")"

  if [[ -f $destination && ! -L $destination && $checksum_file -nt $destination ]] &&
    [[ $(cat "$checksum_file") == "$sha256" ]]; then
    continue
  fi

  if [[ -f $destination ]] && verify_model "$destination" "$sha256"; then
    # Migrate the old Nix-store links without downloading the weights again.
    if [[ -L $destination ]]; then
      cp --reflink=auto --dereference --no-preserve=mode "$destination" "$partial"
      mv -f "$partial" "$destination"
    fi
  else
    echo "Downloading $name"
    curl --fail --location --silent --show-error --retry 5 --retry-delay 5 \
      --continue-at - --output "$partial" "$url"
    if ! verify_model "$partial" "$sha256"; then
      echo "Checksum mismatch: $name" >&2
      rm -f "$partial"
      exit 1
    fi
    mv -f "$partial" "$destination"
  fi

  printf '%s\n' "$sha256" >"$checksum_file"
done < <(jq -r '.[] | [.directory, .name, .url, .sha256] | @tsv' "$manifest")
