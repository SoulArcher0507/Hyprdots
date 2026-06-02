#!/usr/bin/env bash
set -u -o pipefail
export LC_ALL=C LANG=C
shopt -s nullglob

num_ok() {
  local value="${1:-0}"
  [[ "$value" =~ ^[0-9]+([.][0-9]+)?$ ]] && printf '%s' "$value" || printf '0'
}

json_escape() {
  local value="${1:-}"
  value=${value//\\/\\\\}
  value=${value//\"/\\\"}
  printf '%s' "$value"
}

calc_pct() {
  awk -v b1="$1" -v t1="$2" -v b2="$3" -v t2="$4" 'BEGIN{
    dt=t2-t1;
    db=b2-b1;
    print (dt>0 ? (db/dt*100) : 0)
  }'
}

read_cpu_snap() {
  awk '
    /^cpu[0-9]* /{
      id=$1;
      busy=$2+$3+$4+$7+$8+$9;
      total=0;
      for (i=2; i<=NF; ++i)
        total += $i;
      printf "%s %.0f %.0f\n", id, busy, total
    }
  ' /proc/stat 2>/dev/null
}

pick_net_iface() {
  local iface iface_path state

  iface=$(ip route show default 2>/dev/null | awk '/ dev / {for (i=1; i<=NF; ++i) if ($i == "dev") {print $(i+1); exit}}')
  if [[ -n "$iface" ]]; then
    printf '%s' "$iface"
    return
  fi

  if command -v nmcli >/dev/null 2>&1; then
    iface=$(nmcli -t -f DEVICE,TYPE,STATE device 2>/dev/null | awk -F: '$2 ~ /^(ethernet|wifi)$/ && $3 ~ /^connected/ {print $1; exit}')
    if [[ -n "$iface" ]]; then
      printf '%s' "$iface"
      return
    fi
  fi

  for iface_path in /sys/class/net/*; do
    iface=${iface_path##*/}
    [[ "$iface" == "lo" ]] && continue
    [[ "$(readlink -f "$iface_path")" == *"/virtual/"* ]] && continue
    state=$(cat "$iface_path/operstate" 2>/dev/null || printf 'down')
    if [[ "$state" == "up" ]]; then
      printf '%s' "$iface"
      return
    fi
  done

  for iface_path in /sys/class/net/*; do
    iface=${iface_path##*/}
    [[ "$iface" == "lo" ]] && continue
    state=$(cat "$iface_path/operstate" 2>/dev/null || printf 'down')
    if [[ "$state" == "up" ]]; then
      printf '%s' "$iface"
      return
    fi
  done
}

read_net_counter() {
  local iface="$1"
  local counter="$2"
  cat "/sys/class/net/$iface/statistics/$counter" 2>/dev/null || printf '0'
}

mapfile -t S1 < <(read_cpu_snap)
net_iface=$(pick_net_iface)
net_rx1=0
net_tx1=0
if [[ -n "$net_iface" ]]; then
  net_rx1=$(read_net_counter "$net_iface" rx_bytes)
  net_tx1=$(read_net_counter "$net_iface" tx_bytes)
fi
sleep 0.20
mapfile -t S2 < <(read_cpu_snap)
net_rx2=$net_rx1
net_tx2=$net_tx1
if [[ -n "$net_iface" ]]; then
  net_rx2=$(read_net_counter "$net_iface" rx_bytes)
  net_tx2=$(read_net_counter "$net_iface" tx_bytes)
fi

read -r net_down_bps net_up_bps net_total_bps < <(
  awk -v rx1="$net_rx1" -v tx1="$net_tx1" -v rx2="$net_rx2" -v tx2="$net_tx2" 'BEGIN{
    down=rx2-rx1;
    up=tx2-tx1;
    if (down < 0) down=0;
    if (up < 0) up=0;
    down=down/0.20;
    up=up/0.20;
    printf "%.2f %.2f %.2f\n", down, up, down+up;
  }'
)

cpu_total=0
per_core=()
for i in "${!S1[@]}"; do
  read -r id b1 t1 <<<"${S1[i]}"
  read -r _  b2 t2 <<<"${S2[i]}"
  pct=$(calc_pct "$b1" "$t1" "$b2" "$t2")
  if [[ "$id" == "cpu" ]]; then
    cpu_total="$pct"
  else
    per_core+=("$pct")
  fi
done

per_core_csv=""
for value in "${per_core[@]}"; do
  per_core_csv+=$(printf '%.2f,' "$value")
done
per_core_csv="${per_core_csv%,}"

read -r mem_used_gb mem_total_gb mem_pct < <(
  awk '
    /MemTotal:/     { total=$2 }
    /MemAvailable:/ { available=$2 }
    END{
      used=total-available;
      if (total <= 0)
        total = 1;
      printf "%.2f %.2f %.2f\n", used/1024/1024, total/1024/1024, (used/total*100)
    }
  ' /proc/meminfo 2>/dev/null
)

disk_root_pct=$(df -P / 2>/dev/null | awk 'NR==2{gsub("%","",$5); print $5}')
disk_home_pct=$(df -P /home 2>/dev/null | awk 'NR==2{gsub("%","",$5); print $5}')
disk_home_free_bytes=$(df -B1 -P /home 2>/dev/null | awk 'NR==2{print $4}')
read -r disk_os_name disk_os_pct < <(
  lsblk -P -b -o NAME,PKNAME,TYPE,SIZE,MOUNTPOINT,FSUSED 2>/dev/null | awk '
    function field(key, line, match_data) {
      return match(line, key "=\"([^\"]*)\"", match_data) ? match_data[1] : ""
    }
    function belongs_to_disk(name, disk, current) {
      current=name
      while (current != "") {
        if (current == disk)
          return 1
        current=parent[current]
      }
      return 0
    }
    {
      name=field("NAME", $0)
      parent[name]=field("PKNAME", $0)
      type[name]=field("TYPE", $0)
      size[name]=field("SIZE", $0) + 0
      mountpoint[name]=field("MOUNTPOINT", $0)
      used[name]=field("FSUSED", $0) + 0
      names[++count]=name
      if (mountpoint[name] == "/")
        root_name=name
    }
    END {
      disk=root_name
      while (parent[disk] != "")
        disk=parent[disk]
      total=size[disk] + 0
      total_used=0
      for (i=1; i<=count; ++i)
        if (mountpoint[names[i]] != "" && mountpoint[names[i]] != "[SWAP]" && belongs_to_disk(names[i], disk))
          total_used += used[names[i]]
      printf "%s %.2f\n", disk, (total > 0 ? total_used / total * 100 : 0)
    }
  '
)
[[ -z "${disk_root_pct:-}" ]] && disk_root_pct=0
[[ -z "${disk_home_pct:-}" ]] && disk_home_pct=$disk_root_pct
[[ -z "${disk_home_free_bytes:-}" ]] && disk_home_free_bytes=0
[[ -z "${disk_os_name:-}" ]] && disk_os_name="disk"
[[ -z "${disk_os_pct:-}" ]] && disk_os_pct=0

gpu_name=""
gpu_total=0
gpu_detail_json=""

if command -v lspci >/dev/null 2>&1; then
  gpu_name=$(lspci 2>/dev/null | grep -Ei 'VGA|3D|Display' | head -n1 | cut -d':' -f3- | sed 's/^[[:space:]]*//')
fi

if command -v nvidia-smi >/dev/null 2>&1; then
  if gpu_line=$(nvidia-smi --query-gpu=name,utilization.gpu,utilization.memory --format=csv,noheader,nounits 2>/dev/null | head -n1); then
    if [[ -n "${gpu_line// /}" ]]; then
      IFS=',' read -r n_name n_gpu_util n_mem_util <<<"$gpu_line"
      gpu_name=$(printf '%s' "${n_name:-$gpu_name}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
      gpu_total=$(num_ok "$(printf '%s' "${n_gpu_util:-0}" | tr -d '[:space:]')")
      mem_util=$(num_ok "$(printf '%s' "${n_mem_util:-0}" | tr -d '[:space:]')")
      gpu_detail_json=$(printf '"detail":[{"name":"graphics","percent":%s},{"name":"memory","percent":%s}]' "$gpu_total" "$mem_util")
    fi
  fi
fi

if [[ -z "$gpu_detail_json" ]]; then
  busy_files=(/sys/class/drm/card*/device/gpu_busy_percent)
  if ((${#busy_files[@]} > 0)); then
    busy_val=$(cat "${busy_files[0]}" 2>/dev/null || printf '0')
    gpu_total=$(num_ok "$busy_val")
    gpu_detail_json=$(printf '"detail":[{"name":"graphics","percent":%s}]' "$gpu_total")
  else
    engine_files=(/sys/class/drm/card*/engine/*/busy_percent)
    if ((${#engine_files[@]} > 0)); then
      sum=0
      count=0
      details=""
      for engine_file in "${engine_files[@]}"; do
        value=$(cat "$engine_file" 2>/dev/null || printf '0')
        value=$(num_ok "$value")
        name=$(basename "$(dirname "$engine_file")")
        sum=$(awk -v a="$sum" -v b="$value" 'BEGIN{print a+b}')
        count=$((count + 1))
        details+=$(printf '{"name":"%s","percent":%s},' "$(json_escape "$name")" "$value")
      done
      if ((count > 0)); then
        gpu_total=$(awk -v s="$sum" -v c="$count" 'BEGIN{print (c>0 ? s/c : 0)}')
        gpu_detail_json=$(printf '"detail":[%s]' "${details%,}")
      fi
    fi
  fi
fi

gpu_name_esc=$(json_escape "$gpu_name")
net_iface_esc=$(json_escape "$net_iface")
disk_os_name_esc=$(json_escape "$disk_os_name")

printf '{'
printf '"cpu":{"total":%.2f,"per_core":[%s]},' "$(num_ok "$cpu_total")" "$per_core_csv"
printf '"gpu":{"name":"%s","total":%.2f%s},' "$gpu_name_esc" "$(num_ok "$gpu_total")" "${gpu_detail_json:+,$gpu_detail_json}"
printf '"mem":{"used_gb":%.2f,"total_gb":%.2f,"percent":%.2f},' "$(num_ok "$mem_used_gb")" "$(num_ok "$mem_total_gb")" "$(num_ok "$mem_pct")"
printf '"disk":{"root_percent":%s,"home_percent":%s,"home_free_bytes":%s,"os_disk_name":"%s","os_disk_percent":%.2f},' "$(num_ok "$disk_root_pct")" "$(num_ok "$disk_home_pct")" "$(num_ok "$disk_home_free_bytes")" "$disk_os_name_esc" "$(num_ok "$disk_os_pct")"
printf '"net":{"iface":"%s","down_bps":%.2f,"up_bps":%.2f,"total_bps":%.2f}' "$net_iface_esc" "$(num_ok "$net_down_bps")" "$(num_ok "$net_up_bps")" "$(num_ok "$net_total_bps")"
printf '}\n'
