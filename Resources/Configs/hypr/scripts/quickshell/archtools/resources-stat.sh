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

mapfile -t S1 < <(read_cpu_snap)
sleep 0.20
mapfile -t S2 < <(read_cpu_snap)

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
[[ -z "${disk_root_pct:-}" ]] && disk_root_pct=0
[[ -z "${disk_home_pct:-}" ]] && disk_home_pct=$disk_root_pct

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

printf '{'
printf '"cpu":{"total":%.2f,"per_core":[%s]},' "$(num_ok "$cpu_total")" "$per_core_csv"
printf '"gpu":{"name":"%s","total":%.2f%s},' "$gpu_name_esc" "$(num_ok "$gpu_total")" "${gpu_detail_json:+,$gpu_detail_json}"
printf '"mem":{"used_gb":%.2f,"total_gb":%.2f,"percent":%.2f},' "$(num_ok "$mem_used_gb")" "$(num_ok "$mem_total_gb")" "$(num_ok "$mem_pct")"
printf '"disk":{"root_percent":%s,"home_percent":%s}' "$(num_ok "$disk_root_pct")" "$(num_ok "$disk_home_pct")"
printf '}\n'
