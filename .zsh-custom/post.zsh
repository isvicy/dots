# remove duplicates from PATH
export PATH=$(printf %s "$PATH" |
  awk -vRS=: -vORS= '{
         gsub(/\/$/, "", $0);  # Remove trailing slash
         if (!seen[$0]++) {
           if (NR > 1) printf ":";
           printf "%s", $0;
         }
}')

# If not started by nix develop (IN_NIX_SHELL is not set) then record PATH.
# This records will be used to check which PATH is added by nix develop/nix shell
if [[ -z "$IN_NIX_SHELL" ]]; then
  echo "$PATH" >"$HOME/.original_path"
fi

# If started by nix develop (IN_NIX_SHELL is set), then reorder the PATH.
# we have to make sure the PATH item added by nix has higher priority.
if [[ -n "$IN_NIX_SHELL" ]]; then
  # Read the original PATH from file (if available)
  if [[ -f "$HOME/.original_path" ]]; then
    ORIGINAL_PATH=$(<"$HOME/.original_path")
  else
    ORIGINAL_PATH=""
  fi

  # Split the original and current PATH into arrays.
  IFS=':' read -r -A orig_arr <<<"$ORIGINAL_PATH"
  IFS=':' read -r -A current_arr <<<"$PATH"

  new_entries=()      # entries added after original PATH
  existing_entries=() # entries that were originally there

  # Determine which entries in the current PATH are new.
  for entry in "${current_arr[@]}"; do
    local found=0
    for orig in "${orig_arr[@]}"; do
      if [[ "$entry" == "$orig" ]]; then
        found=1
        break
      fi
    done
    if ((found)); then
      existing_entries+=("$entry")
    else
      new_entries+=("$entry")
    fi
  done

  # Separate new entries into nix store entries and others.
  nix_entries=()
  non_nix_entries=()
  for entry in "${new_entries[@]}"; do
    if [[ "$entry" == /nix/store/* ]]; then
      nix_entries+=("$entry")
    else
      non_nix_entries+=("$entry")
    fi
  done

  # Reassemble PATH so that:
  #   1. All nix store entries come first.
  #   2. Then any other new entries.
  #   3. Followed by the original PATH entries.
  new_path=""
  for e in "${nix_entries[@]}"; do
    new_path+="${e}:"
  done
  for e in "${non_nix_entries[@]}"; do
    new_path+="${e}:"
  done
  for e in "${existing_entries[@]}"; do
    new_path+="${e}:"
  done

  # Remove trailing colon.
  PATH="${new_path%:}"
fi
