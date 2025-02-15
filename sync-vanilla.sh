#!/usr/bin/env bash

TARGET_DIR="$HOME/.projects/lua/wow-1.12.1-addons.git/master"

function sync() {
  echo "Syncing addons with ${TARGET_DIR}..." >&2
  rsync -ah RollFor "$TARGET_DIR"
}

function listen() {
  echo "Listening..." >&2
  # The 4 digit regex deals with temporary neovim files.
  inotifywait -mqre create,close_write,delete,move --format "%e %w%f" --exclude '/[0-9]{4}$' . | while read -r event filename; do
    local name
    name=$(echo "$filename" | sed -E 's/^\.\///g')
    if [[ "$name" != *~ ]]; then
      on_change "$event" "$name"
    fi
  done
}

function on_change() {
  local event="$1"
  local filename="$2"

  if [[ "$filename" == "test/"* ]]; then
    echo "Ignoring test: $filename" >&2
    return
  fi

  if [[ "$filename" != "RollFor/"* ]]; then
    echo "Ignoring non-addon file: $filename" >&2
    return
  fi

  case "$event" in
    "CREATE,ISDIR")
      echo "Creating directory: $filename" >&2
      mkdir -p "${TARGET_DIR}/$filename"
      ;;
    "DELETE,ISDIR"|"MOVED_FROM,ISDIR")
      echo "Deleting directory: $filename" >&2
      rm -rf "${TARGET_DIR:?}/$filename"
      ;;
    "MOVED_TO,ISDIR")
      echo "Renaming directory: $filename" >&2
      cp -r "$filename" "${TARGET_DIR}/$filename"
      ;;
    "CREATE")
      # We ignore this, if the file is written, another event follows up.
      ;;
    "CLOSE_WRITE,CLOSE")
      echo "Modifying file: $filename" >&2
      cp "$filename" "${TARGET_DIR}/$filename"
      ;;
    "DELETE"|"MOVED_FROM")
      echo "Deleting file: $filename" >&2
      rm "${TARGET_DIR}/$filename"
      ;;
    "MOVED_TO")
      echo "Renaming file: $filename" >&2
      cp "$filename" "${TARGET_DIR}/$filename"
      ;;
    *)
      echo "Implement me! Event: $event" >&2
      ;;
  esac
}

function main() {
  if [[ -z "$TARGET_DIR" ]]; then
    echo "TARGER_DIR is invalid." >&2
    exit 1
  fi

  if [[ $# -eq 0 ]]; then
    tmux rename-window "sync"
  fi

  sync
  listen
}

main "$@"

