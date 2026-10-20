#!/bin/bash

tempfile=$( mktemp )
strings=$( mktemp )

cleanup() {
  rm -f $tempfile $strings
}
trap cleanup EXIT

do_import() {
  project="$1"
  handling="$2"
  namespace="$3"
  file="$4"
  : > "$tempfile"

  echo -n "Importing $namespace..."
  result=$( curl -sS -X POST -w "%{http_code}" -o "$tempfile" \
    -H "X-Api-Token: $CF_API_KEY" \
    -F "metadata={ language: \"enUS\", namespace: \"$namespace\", \"missing-phrase-handling\": \"$handling\" }" \
    -F "localizations=<$file" \
    "https://www.wowace.com/api/projects/$project/localization/import"
  ) || exit 1
  case $result in
    200) echo "done." ;;
    *)
      echo "error! ($result)"
      [ -s "$tempfile" ] && grep -q "errorMessage" "$tempfile" && cat "$tempfile" | jq --raw-output '.errorMessage'
      exit 1
      ;;
  esac
}

project=$( grep -oiP '##\s*X-Curse-Project-ID:\s*\K[0-9]+' ./*.toc | head -1 )
[ -n "$project" ] || { echo "no X-Curse-Project-ID in the toc"; exit 1; }

handling="${LOCALE_MISSING_PHRASE_HANDLING:-DoNothing}"

# The importer only understands plain L[...] assignments, not the file header
grep '^L\[' locale/enUS.lua > "$strings" || { echo "no strings found in locale/enUS.lua"; exit 1; }

do_import "$project" "$handling" "" "$strings"

exit 0
