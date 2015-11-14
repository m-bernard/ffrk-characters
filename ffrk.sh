#!/bin/bash

FIELDS=(HP Attack Defense Magic Resistance Mind Accuracy Evasion Speed)
LEVELS=("Starting Value" "Lv 50" "Lv 65")  
declare -A RESULTS
KEYS=()
TMP=/tmp/ffrk
ABILITIES=()

download_all() {

  DOMAIN='https://ffrkstrategy.gamematome.jp'
  CHARACTER_DIR='game/951/wiki/Character'

  readarray -t CHARACTER_PAGES <<<"$(
    curl "$DOMAIN/$CHARACTER_DIR" 2>/dev/null | \
      grep -o "${CHARACTER_DIR}"'_\(FF\|Core\)[^"]*_[^"]*' | \
      sed "s/&#39;/'/g"
    )"

  C=1
  for CHARACTER_PAGE in "${CHARACTER_PAGES[@]}"; do
    printf "%02s/%02s: " $C ${#CHARACTER_PAGES[@]} >&2
    download_character "$DOMAIN/$CHARACTER_PAGE"
    ((C++))
  done
}

get_stats() {
  grep -E --no-group-separator -A $NUM_LEVELS "$PATTERN" $TMP \
    | awk -v mod="$MOD" -v num_rows="$NUM_ROWS" '(NR - mod) % num_rows == 0' \
    | tr -d '[<>/td]' \
    | paste -sd, 
}

get_abilities() {
  while read line; do
    NAME=$(echo $line | grep -o "^[^=]*")
    RARITY=$(echo $line | grep -o "[^=]*$")
    RESULTS["$1-${NAME}"]="$RARITY"
    ABILITIES+=("${NAME}")
  done < <(
    sed -n -E 's|.*<td>([^<]*)<br />\(Rarity ([1-5])\)</td>.*|\1=\2\n|p' $TMP \
      | grep -v ^$ )
}

download_character() {
  PATTERN=$(printf '(<td>%s<\/td>)\n' "${FIELDS[@]}" | paste -sd '|')
  curl "$1" 2>/dev/null > $TMP
  I=0
  NAME=$(sed -nE 's|.*<h1 itemprop="headline">([^<]*)</h1>.*|\1|p' "$TMP" \
    | sed "s/&#39;/'/g" )
  echo $NAME >&2 
  KEY=$(echo "$NAME" | tr -d -c '[a-zA-Z]')
  KEYS+=("$KEY")
  RESULTS[${KEY}-NAME]="$NAME"
  AVAILABLE_LEVELS=()
  for LEVEL in "${LEVELS[@]}"; do
    grep -F "$LEVEL</td>" "$TMP" >/dev/null && AVAILABLE_LEVELS+=("$LEVEL")
  done
  NUM_LEVELS=${#AVAILABLE_LEVELS[@]}
  for I in $(seq $NUM_LEVELS); do
    NUM_ROWS=$((NUM_LEVELS + 1))
    MOD=$((I + 1))
    LEVEL=${AVAILABLE_LEVELS[$((I-1))]}
    STATS=$(get_stats)
    RESULTS[${KEY}-${LEVEL}-STATS]="$STATS"
    ((I++))
  done
  get_abilities "${KEY}-ABILITIES"
}

print_results() {
  eval UNIQUE_ABILITIES=($(printf "%q\n" "${ABILITIES[@]}" | /usr/bin/sort -u))

  # Header
  echo -n "Name,"
  for L in "${LEVELS[@]}"; do
    for F in "${FIELDS[@]}"; do
      echo -n "${F} ${L},"
    done
  done
  for A in "${UNIQUE_ABILITIES[@]}"; do
    echo "$A"
  done | paste -sd,

  # Results
  for KEY in "${KEYS[@]}"; do
    NAME=${RESULTS[${KEY}-NAME]}
    echo -n '"'"$NAME"'",'
    for LEVEL in "${LEVELS[@]}"; do
      STATS=${RESULTS[${KEY}-${LEVEL}-STATS]}
      if [[ -z "$STATS" ]]; then
        for I in $(seq "${#FIELDS[@]}"); do
          echo -n ","
        done
      else
        echo -n "${STATS},"
      fi
    done
    for ABILITY in "${UNIQUE_ABILITIES[@]}"; do
      AKEY="${KEY}-ABILITIES-${ABILITY}"
      RARITY="${RESULTS[$AKEY]}"
      echo "${RARITY}"
    done | paste -sd,
  done
}

download_all
print_results
