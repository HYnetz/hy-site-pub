#!/usr/bin/env bash
set -euo pipefail
LIST="${1:-partner_list.txt}"
[[ ! -f "$LIST" ]] && { echo "Provide file: 'Name <email> | topic' per line"; exit 1; }
echo "------ Outreach (copy/paste) ------"
while IFS= read -r line; do
  name=$(echo "$line" | awk -F'|' '{print $1}' | xargs)
  topic=$(echo "$line" | awk -F'|' '{print $2}' | xargs)
  echo; echo "Subject: Add a free official-path helper (we pay CPM, auto-pause if complaints)"
  echo "Hi $name,"
  echo "we publish evidence-first guides for $topic. I can place a small helper on your pages that walks users through the official path. We pay a small CPM from our revenue; you can remove it anytime. If complaints ever exceed 1.2/1k, it auto-pauses."
  echo; echo "Want the one-line snippet and the one-pager?"; echo "– YOU"
done < "$LIST"
