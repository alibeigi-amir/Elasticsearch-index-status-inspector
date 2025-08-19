#!/usr/bin/env bash
set -euo pipefail

# ################ Colors ################
YELLOW=$'\033[1;33m'
RED=$'\033[0;31m'
ORANGE=$'\033[0;33m'
BLUE=$'\033[0;34m'
NC=$'\033[0m' # No color

# Alternating rows for nodes
BLACK_BG=$'\033[40m'
WHITE_BG=$'\033[47m'
WHITE_FG=$'\033[97m'
BLACK_FG=$'\033[30m'
RESET=$'\033[0m'

# ################ User Inputs ################
echo -ne "${YELLOW}Enter Elasticsearch IP (default: 192.168.152.14): ${NC}"
read ES_IP
ES_IP=${ES_IP:-192.168.152.14}
ES_URL="https://$ES_IP:9200"

echo -ne "${YELLOW}Enter Elasticsearch username (default: elastic): ${NC}"
read ES_USER
ES_USER=${ES_USER:-elastic}

echo -ne "${YELLOW}Enter Elasticsearch password: ${NC}"
read -s ES_PASS
echo

# --- Index selection ---
echo -e "${YELLOW}Select index prefix (or * for all):${NC}"
echo "1) filebeat"
echo "2) winlogbeat"
echo "3) packetbeat"
echo "4) metricbeat"
echo "5) auditbeat"
echo "6) heartbeat"
echo "7) custom (enter a keyword to search in index names)"
echo "*) all indices"
read -p "Your choice (default: filebeat): " choice

case "$choice" in
  1|"filebeat"|"" ) PREFIX="filebeat";;
  2|"winlogbeat") PREFIX="winlogbeat";;
  3|"packetbeat") PREFIX="packetbeat";;
  4|"metricbeat") PREFIX="metricbeat";;
  5|"auditbeat") PREFIX="auditbeat";;
  6|"heartbeat") PREFIX="heartbeat";;
  7|"custom")
      read -p "Enter a keyword to search in index names (e.g., sample): " CUSTOM_KEY
      PREFIX=""  # Clear prefix to use keyword
      ;;
  "*" ) PREFIX="*";;
  * ) PREFIX="$choice";;
esac

# --- Threshold ---
echo -ne "${YELLOW}Enter threshold in GB: ${NC}"
read THRESHOLD

# --- Determine pattern ---
if [[ -n "${CUSTOM_KEY:-}" ]]; then
    PATTERN="*${CUSTOM_KEY}*"
elif [[ -n "${PREFIX:-}" ]]; then
    PATTERN="${PREFIX}-*"
else
    PATTERN="*"
fi

# ################ Fetch ILM Explain ################
explain_json=$(curl -sS -k -u "$ES_USER:$ES_PASS" "$ES_URL/$PATTERN/_ilm/explain") || {
  echo "ERROR: Failed to call _ilm/explain"; exit 1; }

if ! echo "$explain_json" | jq -e 'type=="object" and has("indices")' >/dev/null 2>&1; then
  echo "ERROR: Unexpected _ilm/explain response. Raw output:"
  echo "$explain_json"
  exit 1
fi

# ################ Fetch Sizes ################
declare -A SIZE_GB
while IFS=$'\t' read -r idx size_raw; do
  [[ -z "${idx:-}" ]] && continue
  num=$(sed 's/[^0-9.]*//g' <<<"$size_raw")
  [[ -z "$num" ]] && num=0
  gb=$(awk "BEGIN{printf \"%.2f\", $num/1024}")
  SIZE_GB["$idx"]="$gb"
done < <(
  curl -sS -k -u "$ES_USER:$ES_PASS" \
    "$ES_URL/_cat/indices/$PATTERN?bytes=mb&h=index,store.size&format=txt" \
  | tr -s ' ' '\t'
)

# ################ Fetch Hot Nodes ################
declare -A HOT_NODE
for idx in "${!SIZE_GB[@]}"; do
  hot_nodes=$(curl -sS -k -u "$ES_USER:$ES_PASS" \
    "$ES_URL/_cat/shards/$idx?h=shard,prirep,node,state" \
    | awk '$2=="p" && $4=="STARTED" {print $3}' | sort -u | paste -sd "," -)
  HOT_NODE["$idx"]="$hot_nodes"
done

# ################ Temporary file for sorting ################
tmp=$(mktemp)

jq -r '.indices | to_entries[] | [.key, .value.phase, .value.age] | @tsv' <<<"$explain_json" \
| while IFS=$'\t' read -r idx phase age; do
    size_gb="${SIZE_GB[$idx]:-0}"
    if [[ -z "$size_gb" || ! "$size_gb" =~ ^[0-9.]+$ ]]; then size_gb=0; fi
    hot_node="${HOT_NODE[$idx]:-}"
    printf "%012.2f\t%s\t%s\t%s\t%s\t%s\n" "$size_gb" "$idx" "$phase" "$age" "$size_gb" "$hot_node" >>"$tmp"
done

# ################ Print Table Header ################
printf "| %-45s | %-6s | %-7s | %-8s | %-20s | %-s |\n" "Index" "Phase" "Age" "Size" "Note" "Hot Node"

# ################ Print Rows ################
delete_candidates=()
total_size=0
while IFS=$'\t' read -r sortkey idx phase age size_gb hot_node; do
  note=""
  bigger=$(awk -v s="$size_gb" -v t="$THRESHOLD" 'BEGIN{print (s+0 > t+0) ? 1 : 0}')
  if [[ "$bigger" -eq 1 ]]; then
    note="${RED}you can delete${NC}"
  fi

  case "$phase" in
    warm) color_phase="${ORANGE}$phase${NC}";;
    hot) color_phase="${RED}$phase${NC}";;
    cold) color_phase="${BLUE}$phase${NC}";;
    *) color_phase="$phase";;
  esac

  printf "| %-45s | %-6s | %-7s | %6.2f GB | %-20b | %-s |\n" "$idx" "$color_phase" "$age" "$size_gb" "$note" "$hot_node"

  delete_candidates+=("$idx")
  total_size=$(awk -v t="$total_size" -v s="$size_gb" 'BEGIN{print t+0 + s+0}')
done < <(sort -t $'\t' -k1,1nr "$tmp")

# ################ Print Total ################
printf "| %-45s | %-6s | %-7s | %6.2f GB | %-20s | %-s |\n" "TOTAL" "-" "-" "$total_size" "-" "-"

rm -f "$tmp"

# ################ Delete Command ################
if [[ ${#delete_candidates[@]} -ge 3 ]]; then
  echo
  echo "Example delete command for top 3 indices:"
  echo "curl -k -X DELETE \"$ES_URL/${delete_candidates[0]},${delete_candidates[1]},${delete_candidates[2]}\" -u $ES_USER"
fi

# ################ Cluster Nodes Status ################
echo
# Reset colors before printing the header to avoid affecting later prompts
echo -e "${RESET}${YELLOW}Cluster Nodes Status:${NC}"

nodes_txt=$(curl -sS -k -u "$ES_USER:$ES_PASS" \
  "$ES_URL/_cat/nodes?v&h=ip,name,heap.percent,ram.percent,cpu,load_1m,load_5m,load_15m,node.role,master,disk.used_percent,uptime&format=txt")

# Header
header=$(echo "$nodes_txt" | head -n1)
# Print header with white text on black background
echo -e "${WHITE_FG}${BLACK_BG}$header${RESET}"

# Alternating rows with different yellow shades
tail -n +2 <<<"$nodes_txt" | awk -v YB1="\033[43m" -v YB2="\033[103m" -v BF="$BLACK_FG" -v R="$RESET" '
{
  if(NR%2==1){
    printf "%s%s%s\n", YB1,BF,$0,R
  } else {
    printf "%s%s%s\n", YB2,BF,$0,R
  }
}'

# Reset colors after table to ensure next prompt is normal
echo -ne "${RESET}"
