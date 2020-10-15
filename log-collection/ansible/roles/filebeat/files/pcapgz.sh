#!/usr/bin/env bash
DIR="$1"
# COMMANDS="gunzip find tshark"
# https://github.com/koalaman/shellcheck/wiki/SC2044
while IFS= read -r -d '' pcapgz; do
  echo "Found file $pcapgz"
  gunzip "$pcapgz" -k
done < <(find "$DIR" -type f -name '*.pcap.gz' -print0)

while IFS= read -r -d '' pcap; do
  echo "Found file $pcap"
  tshark -r "$pcap" -T ek >"$pcap".json &
done < <(find "$DIR" -type f -name '*.pcap' -print0)

while IFS= read -r -d '' pcapjson; do
  echo "Found file $pcapjson,"
  id=$(basename "$pcapjson" .pcap.json)
  echo "Removing file $id.pcap.json"
  rm "$id".pcap.json
  echo "Removing file $id.pcap"
  rm "$id".pcap
  echo "Removing file $id.pcap.gz"
  rm "$id".pcap.gz
done < <(find "$DIR" -type f -name '*.pcap.json' -mmin 60 -print0)
