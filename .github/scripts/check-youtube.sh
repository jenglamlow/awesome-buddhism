#!/usr/bin/env bash
# Checks YouTube video links through YouTube's oEmbed endpoint.
#
# youtube.com/watch answers 200 even when a video has been removed, so lychee
# cannot tell a dead video from a live one. oEmbed can:
#   200      the video exists and is public
#   400, 404 the video is unavailable (removed, or a bad id): counted as broken
#   401, 403 the video is private or blocks embedding: listed for a manual look
#   other    YouTube did not answer usefully (rate limit, outage): listed, not failed
#
# Usage: check-youtube.sh FILE [REPORT]
# Writes a Markdown section to REPORT (default: stdout).
# Exits 1 when at least one video is unavailable.
set -uo pipefail

file=${1:?usage: check-youtube.sh FILE [REPORT]}
report=${2:-/dev/stdout}

total=0
broken=0
manual=0
rows=""

while IFS=: read -r line url; do
  total=$((total + 1))
  status=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 20 --retry 2 --retry-delay 5 \
    --get --data-urlencode format=json --data-urlencode "url=$url" \
    https://www.youtube.com/oembed) || status=${status:-000}
  case $status in
    200) continue ;;
    400 | 404) broken=$((broken + 1)); meaning="unavailable (removed or bad id)" ;;
    401 | 403) manual=$((manual + 1)); meaning="private or embedding disabled, check in a browser" ;;
    *) manual=$((manual + 1)); meaning="no clear answer from YouTube, check in a browser" ;;
  esac
  rows+="| $line | <$url> | $status | $meaning |"$'\n'
  echo "$file:$line: $url -> oEmbed $status, $meaning" >&2
done < <(grep -noE 'https?://(www\.|m\.)?(youtube\.com/watch\?v=|youtu\.be/)[A-Za-z0-9_-]{11}' "$file")

{
  echo "## YouTube videos (oEmbed)"
  echo
  echo "Checked $total video links in \`$file\`: $broken unavailable, $manual need a manual look."
  if [ -n "$rows" ]; then
    echo
    echo "| Line | URL | oEmbed status | Meaning |"
    echo "| ---: | --- | ---: | --- |"
    printf '%s' "$rows"
  fi
} > "$report"

echo "YouTube: $total checked, $broken unavailable, $manual need a manual look" >&2
[ "$broken" -eq 0 ]
