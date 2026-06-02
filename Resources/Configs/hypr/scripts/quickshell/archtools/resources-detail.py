#!/usr/bin/env python3
import json
import os
import re
import shutil
import subprocess
import sys
import time
from collections import Counter
from pathlib import Path

SAMPLE_INTERVAL = 0.22


def run_capture(cmd, timeout=2.0):
    try:
        proc = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
    except Exception:
        return "", "", 1
    return proc.stdout.strip(), proc.stderr.strip(), proc.returncode


def read_text(path):
    try:
        return Path(path).read_text().strip()
    except Exception:
        return ""


def read_int(path):
    try:
        return int(float(read_text(path)))
    except Exception:
        return None


def read_float(path):
    try:
        return float(read_text(path))
    except Exception:
        return None


def safe_float(value):
    if value is None:
        return None
    text = str(value).strip()
    if not text or text in {"[N/A]", "N/A", "-", "nan"}:
        return None
    try:
        return float(text)
    except Exception:
        return None


def safe_int(value):
    num = safe_float(value)
    return int(num) if num is not None else None


def rounded(value, digits=2):
    if value is None:
        return None
    return round(float(value), digits)


def first_existing(paths):
    for path in paths:
        candidate = Path(path)
        if candidate.exists():
            return candidate
    return None


def display_model():
    stdout, _, code = run_capture(["lspci"], timeout=1.5)
    if code != 0:
        return ""
    for line in stdout.splitlines():
        if re.search(r"(vga|3d|display)", line, re.IGNORECASE):
            return line.split(":", 2)[-1].strip()
    return ""


def detect_vendor_from_name(name):
    text = (name or "").lower()
    if "nvidia" in text or "geforce" in text or "quadro" in text:
        return "nvidia"
    if "amd" in text or "radeon" in text or "advanced micro devices" in text:
        return "amd"
    if "intel" in text or "arc" in text or "uhd" in text or "iris" in text:
        return "intel"
    return "unknown"


def parse_proc_stat():
    stats = {}
    try:
        with open("/proc/stat", "r", encoding="utf-8") as handle:
            for line in handle:
                if not line.startswith("cpu"):
                    continue
                parts = line.split()
                cpu_id = parts[0]
                if not re.match(r"^cpu\d*$", cpu_id):
                    continue
                values = [int(part) for part in parts[1:]]
                busy = values[0] + values[1] + values[2] + values[5] + values[6] + (values[7] if len(values) > 7 else 0)
                total = sum(values)
                stats[cpu_id] = (busy, total)
    except Exception:
        return {}
    return stats


def sample_cpu_usage(interval=SAMPLE_INTERVAL):
    snap1 = parse_proc_stat()
    time.sleep(interval)
    snap2 = parse_proc_stat()
    if not snap1 or not snap2:
        return 0.0, []

    total_usage = 0.0
    per_core = []
    for cpu_id, (busy1, total1) in snap1.items():
        if cpu_id not in snap2:
            continue
        busy2, total2 = snap2[cpu_id]
        delta_total = total2 - total1
        delta_busy = busy2 - busy1
        usage = (delta_busy / delta_total * 100.0) if delta_total > 0 else 0.0
        usage = max(0.0, usage)
        if cpu_id == "cpu":
            total_usage = usage
        else:
            per_core.append((int(cpu_id[3:]), usage))
    per_core.sort(key=lambda item: item[0])
    return total_usage, per_core


def cpu_model():
    try:
        with open("/proc/cpuinfo", "r", encoding="utf-8") as handle:
            for line in handle:
                if line.lower().startswith("model name"):
                    return line.split(":", 1)[1].strip()
    except Exception:
        pass
    stdout, _, code = run_capture(["lscpu"], timeout=1.2)
    if code == 0:
        match = re.search(r"Model name:\s+(.+)", stdout)
        if match:
            return match.group(1).strip()
    return "Unknown CPU"


def cpu_max_mhz():
    stdout, _, code = run_capture(["lscpu"], timeout=1.2)
    if code != 0:
        return None
    match = re.search(r"CPU max MHz:\s+([0-9.]+)", stdout)
    return safe_float(match.group(1)) if match else None


def cpu_freqs_mhz():
    freq_paths = sorted(
        Path("/sys/devices/system/cpu").glob("cpu[0-9]*/cpufreq/scaling_cur_freq"),
        key=lambda path: int(re.search(r"cpu(\d+)", str(path)).group(1)),
    )
    freqs = []
    for path in freq_paths:
        value = read_int(path)
        if value is not None:
            freqs.append(value / 1000.0)
    if freqs:
        return freqs

    try:
        with open("/proc/cpuinfo", "r", encoding="utf-8") as handle:
            for line in handle:
                if line.lower().startswith("cpu mhz"):
                    freqs.append(float(line.split(":", 1)[1].strip()))
    except Exception:
        pass
    return freqs


def sensors_json():
    if not shutil.which("sensors"):
        return {}
    stdout, _, code = run_capture(["sensors", "-j"], timeout=2.0)
    if code != 0 or not stdout:
        return {}
    try:
        return json.loads(stdout)
    except Exception:
        return {}


def find_sensor_value(sensor_data, label_patterns, value_pattern):
    patterns = [pattern.lower() for pattern in label_patterns]
    fallback = None
    for chip_data in sensor_data.values():
        if not isinstance(chip_data, dict):
            continue
        for label, values in chip_data.items():
            if label == "Adapter" or not isinstance(values, dict):
                continue
            label_lower = label.lower()
            value = None
            for key, raw in values.items():
                if key.endswith(value_pattern):
                    value = safe_float(raw)
                    if value is not None:
                        break
            if value is None:
                continue
            if any(pattern in label_lower for pattern in patterns):
                return value
            if fallback is None:
                fallback = value
    return fallback


def cpu_temperature_c(sensor_data):
    primary = find_sensor_value(sensor_data, ["package", "tdie", "tctl", "cpu"], "_input")
    if primary is not None:
        return primary
    return find_sensor_value(sensor_data, ["core"], "_input")


def sample_power_from_energy(paths, interval=0.18):
    candidates = [Path(path) for path in paths if Path(path).exists()]
    candidates.sort(key=lambda path: (str(path).count(":"), len(str(path))))
    
    for path in candidates:
        max_path = path.with_name("max_energy_range_uj")
        start = read_float(path)
        if start is None:
            continue
            
        t1 = time.monotonic()
        time.sleep(interval)
        end = read_float(path)
        t2 = time.monotonic()
        
        if end is None:
            continue
            
        delta = end - start
        max_energy = read_float(max_path)
        
        if delta < 0 and max_energy:
            delta = (max_energy - start) + end
            
        elapsed = t2 - t1
        if elapsed <= 0 or delta < 0:
            continue
            
        return delta / 1_000_000.0 / elapsed
    return None


def snapshot_proc_cpu():
    snapshot = {}
    total_ticks = 0
    try:
        with open("/proc/stat", "r") as f:
            line = f.readline()
            if line.startswith("cpu "):
                total_ticks = sum(int(p) for p in line.split()[1:])
    except Exception:
        pass

    for entry in Path("/proc").iterdir():
        if not entry.name.isdigit():
            continue
        pid = int(entry.name)
        try:
            stat_text = (entry / "stat").read_text()
            start_paren = stat_text.find('(')
            end_paren = stat_text.rfind(')')
            if start_paren == -1 or end_paren == -1:
                continue
            comm = stat_text[start_paren+1:end_paren]
            parts = stat_text[end_paren+2:].split()
            utime = int(parts[11])
            stime = int(parts[12])
            snapshot[pid] = {
                "name": comm,
                "ticks": utime + stime
            }
        except Exception:
            continue
    return snapshot, total_ticks


def top_processes_cpu(limit=5, interval=SAMPLE_INTERVAL):
    snap1, total1 = snapshot_proc_cpu()
    time.sleep(interval)
    snap2, total2 = snapshot_proc_cpu()
    
    delta_total = total2 - total1
    if delta_total <= 0:
        return []

    rows = []
    for pid, values in snap1.items():
        if pid not in snap2:
            continue
        newer = snap2[pid]
        tick_delta = newer["ticks"] - values["ticks"]
        if tick_delta <= 0:
            continue
            
        cpu_pct = (tick_delta / delta_total) * 100.0
        rows.append({
            "pid": pid,
            "name": newer["name"],
            "cpu_percent": rounded(cpu_pct),
        })
        
    rows.sort(key=lambda row: row["cpu_percent"], reverse=True)
    return rows[:limit]


def memory_info():
    values = {}
    try:
        with open("/proc/meminfo", "r", encoding="utf-8") as handle:
            for line in handle:
                key, raw = line.split(":", 1)
                values[key] = int(raw.strip().split()[0]) * 1024
    except Exception:
        return {}

    total = values.get("MemTotal", 0)
    available = values.get("MemAvailable", 0)
    free = values.get("MemFree", 0)
    cached = max(0, values.get("Cached", 0) + values.get("SReclaimable", 0) - values.get("Shmem", 0))
    used = max(0, total - available)
    swap_total = values.get("SwapTotal", 0)
    swap_free = values.get("SwapFree", 0)
    return {
        "total_bytes": total,
        "used_bytes": used,
        "free_bytes": free,
        "available_bytes": available,
        "cached_bytes": cached,
        "buffers_bytes": values.get("Buffers", 0),
        "percent": rounded((used / total * 100.0) if total else 0.0),
        "swap_total_bytes": swap_total,
        "swap_used_bytes": max(0, swap_total - swap_free),
    }


def memory_speed_mhz():
    stdout, _, code = run_capture(
        ["udevadm", "info", "--query=property", "--path=/sys/devices/virtual/dmi/id"],
        timeout=2.5,
    )
    if code == 0 and stdout:
        speeds = []
        for line in stdout.splitlines():
            match = re.search(r"MEMORY_DEVICE_\d+_(?:CONFIGURED_)?SPEED_MTS=(\d+)", line)
            if match:
                value = int(match.group(1))
                if value > 0:
                    speeds.append(value)
        if speeds:
            return Counter(speeds).most_common(1)[0][0]

    stdout, _, code = run_capture(["dmidecode", "--type", "17"], timeout=2.5)
    if code == 0 and stdout:
        matches = re.findall(r"(?:Configured Memory Speed|Speed):\s+(\d+)\s+MT/s", stdout)
        speeds = [int(match) for match in matches if int(match) > 0]
        if speeds:
            return Counter(speeds).most_common(1)[0][0]
    return None


def top_processes_ram(limit=5):
    stdout, _, code = run_capture(["ps", "-eo", "pid=,comm=,rss=,%mem=", "--sort=-rss"], timeout=1.5)
    if code != 0:
        return []
    rows = []
    for line in stdout.splitlines():
        parts = line.split(None, 3)
        if len(parts) < 4:
            continue
        pid, name, rss_kb, pct = parts
        rows.append({
            "pid": safe_int(pid),
            "name": name.strip(),
            "rss_bytes": (safe_int(rss_kb) or 0) * 1024,
            "mem_percent": rounded(safe_float(pct) or 0.0),
        })
        if len(rows) >= limit:
            break
    return rows


def mounted_filesystem_usage(path):
    stdout, _, code = run_capture(["df", "-P", "-B1", path], timeout=1.5)
    if code != 0 or not stdout:
        return {}
    lines = stdout.splitlines()
    if len(lines) < 2:
        return {}
    parts = lines[-1].split()
    if len(parts) < 6:
        return {}
    return {
        "device": parts[0],
        "total_bytes": safe_int(parts[1]) or 0,
        "used_bytes": safe_int(parts[2]) or 0,
        "free_bytes": safe_int(parts[3]) or 0,
        "percent": rounded(safe_float(parts[4].replace("%", "")) or 0.0),
        "mountpoint": parts[5],
    }


def parse_lsblk():
    stdout, _, code = run_capture(
        [
            "lsblk",
            "-J",
            "-b",
            "-o",
            "NAME,KNAME,PATH,TYPE,SIZE,MODEL,MOUNTPOINT,FSTYPE,FSUSED,FSAVAIL,FSUSE%,TRAN,RM,ROTA",
        ],
        timeout=2.5,
    )
    if code != 0 or not stdout:
        return []
    try:
        data = json.loads(stdout)
    except Exception:
        return []
    return data.get("blockdevices", [])


def parse_diskstats(names=None):
    wanted = set(names or [])
    stats = {}
    try:
        with open("/proc/diskstats", "r", encoding="utf-8") as handle:
            for line in handle:
                parts = line.split()
                if len(parts) < 10:
                    continue
                name = parts[2]
                if wanted and name not in wanted:
                    continue
                stats[name] = {
                    "read_sectors": int(parts[5]),
                    "write_sectors": int(parts[9]),
                }
    except Exception:
        return {}
    return stats


def sample_disk_rates(names, interval=SAMPLE_INTERVAL):
    snap1 = parse_diskstats(names)
    time.sleep(interval)
    snap2 = parse_diskstats(names)
    rates = {}
    for name, values in snap1.items():
        if name not in snap2:
            continue
        read_delta = max(0, snap2[name]["read_sectors"] - values["read_sectors"])
        write_delta = max(0, snap2[name]["write_sectors"] - values["write_sectors"])
        rates[name] = {
            "read_bps": rounded(read_delta * 512 / interval),
            "write_bps": rounded(write_delta * 512 / interval),
        }
    return rates


def snapshot_proc_io():
    snapshot = {}
    for entry in Path("/proc").iterdir():
        if not entry.name.isdigit():
            continue
        pid = int(entry.name)
        try:
            io_lines = (entry / "io").read_text().splitlines()
            io_map = {}
            for line in io_lines:
                if ":" not in line:
                    continue
                key, raw = line.split(":", 1)
                io_map[key.strip()] = int(raw.strip())
            snapshot[pid] = {
                "name": (entry / "comm").read_text().strip(),
                "read_bytes": io_map.get("read_bytes", 0),
                "write_bytes": io_map.get("write_bytes", 0),
            }
        except Exception:
            continue
    return snapshot


def top_processes_io(limit=5, interval=SAMPLE_INTERVAL):
    snap1 = snapshot_proc_io()
    time.sleep(interval)
    snap2 = snapshot_proc_io()
    rows = []
    for pid, values in snap1.items():
        if pid not in snap2:
            continue
        newer = snap2[pid]
        read_delta = max(0, newer["read_bytes"] - values["read_bytes"])
        write_delta = max(0, newer["write_bytes"] - values["write_bytes"])
        total = (read_delta + write_delta) / interval
        if total <= 0:
            continue
        rows.append({
            "pid": pid,
            "name": newer["name"] or values["name"],
            "read_bps": rounded(read_delta / interval),
            "write_bps": rounded(write_delta / interval),
            "total_bps": rounded(total),
        })
    rows.sort(key=lambda row: row["total_bps"], reverse=True)
    return rows[:limit]


def network_snapshot():
    snapshot = {}
    for entry in Path("/sys/class/net").iterdir():
        if entry.name == "lo":
            continue
        rx_bytes = read_int(entry / "statistics/rx_bytes")
        tx_bytes = read_int(entry / "statistics/tx_bytes")
        if rx_bytes is None or tx_bytes is None:
            continue
        snapshot[entry.name] = {
            "rx_bytes": rx_bytes,
            "tx_bytes": tx_bytes,
            "rx_packets": read_int(entry / "statistics/rx_packets") or 0,
            "tx_packets": read_int(entry / "statistics/tx_packets") or 0,
            "rx_errors": read_int(entry / "statistics/rx_errors") or 0,
            "tx_errors": read_int(entry / "statistics/tx_errors") or 0,
            "rx_dropped": read_int(entry / "statistics/rx_dropped") or 0,
            "tx_dropped": read_int(entry / "statistics/tx_dropped") or 0,
        }
    return snapshot


def default_route():
    stdout, _, code = run_capture(["ip", "-j", "route", "show", "default"], timeout=1.2)
    if code == 0 and stdout:
        try:
            routes = json.loads(stdout)
            if routes:
                route = routes[0]
                return {
                    "iface": route.get("dev", ""),
                    "gateway": route.get("gateway", ""),
                }
        except Exception:
            pass
    return {"iface": "", "gateway": ""}


def network_connections():
    stdout, _, code = run_capture(["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "device"], timeout=1.5)
    if code != 0:
        return {}
    connections = {}
    for line in stdout.splitlines():
        parts = line.split(":", 3)
        if len(parts) < 4:
            continue
        connections[parts[0]] = {
            "kind": parts[1],
            "connection": parts[3],
            "connected": parts[2].startswith("connected"),
        }
    return connections


def network_addresses():
    stdout, _, code = run_capture(["ip", "-j", "addr", "show"], timeout=1.5)
    if code != 0 or not stdout:
        return {}
    try:
        rows = json.loads(stdout)
    except Exception:
        return {}
    addresses = {}
    for row in rows:
        iface_addresses = []
        for info in row.get("addr_info", []):
            local = info.get("local")
            if local:
                iface_addresses.append(f"{local}/{info.get('prefixlen', '')}")
        addresses[row.get("ifname", "")] = iface_addresses
    return addresses


def network_socket_rows():
    stdout, _, code = run_capture(["ss", "-Htunap"], timeout=1.5)
    if code != 0:
        return []
    rows = []
    for line in stdout.splitlines():
        parts = line.split(None, 6)
        if len(parts) < 6:
            continue
        processes = []
        for name, pid in re.findall(r'\("([^"]+)",pid=(\d+)', parts[6] if len(parts) > 6 else ""):
            processes.append({"name": name, "pid": int(pid)})
        rows.append({
            "protocol": parts[0].lower(),
            "state": parts[1].lower(),
            "local": parts[4],
            "peer": parts[5],
            "processes": processes,
        })
    return rows


def network_socket_summary(socket_rows):
    summary = {"total": 0, "tcp": 0, "udp": 0, "established": 0}
    for row in socket_rows:
        protocol = row["protocol"]
        state = row["state"]
        summary["total"] += 1
        if protocol.startswith("tcp"):
            summary["tcp"] += 1
        elif protocol.startswith("udp"):
            summary["udp"] += 1
        if state in {"estab", "established"}:
            summary["established"] += 1
    return summary


def endpoint_host_and_scope(endpoint):
    host = endpoint.rsplit(":", 1)[0].strip("[]")
    if "%" not in host:
        return host, ""
    host, scope = host.rsplit("%", 1)
    return host, scope


def network_processes_by_iface(socket_rows, interfaces, primary_iface):
    address_ifaces = {}
    known_ifaces = {item["name"] for item in interfaces}
    for item in interfaces:
        for address in item.get("addresses", []):
            address_ifaces[address.split("/", 1)[0]] = item["name"]

    process_maps = {name: {} for name in known_ifaces}
    for row in socket_rows:
        host, scope = endpoint_host_and_scope(row["local"])
        iface = scope if scope in known_ifaces else address_ifaces.get(host, "")
        if not iface and host in {"*", "0.0.0.0", "::"}:
            iface = primary_iface
        if not iface or iface not in process_maps:
            continue

        for process in row["processes"]:
            key = process["pid"]
            item = process_maps[iface].setdefault(key, {
                "pid": process["pid"],
                "name": process["name"],
                "sockets": 0,
                "tcp": 0,
                "udp": 0,
                "established": 0,
                "peers": [],
            })
            item["sockets"] += 1
            if row["protocol"].startswith("tcp"):
                item["tcp"] += 1
            elif row["protocol"].startswith("udp"):
                item["udp"] += 1
            if row["state"] in {"estab", "established"}:
                item["established"] += 1
            if row["peer"] not in item["peers"] and len(item["peers"]) < 3:
                item["peers"].append(row["peer"])

    result = {}
    for iface, process_map in process_maps.items():
        result[iface] = sorted(
            process_map.values(),
            key=lambda item: (-item["sockets"], -item["established"], item["name"]),
        )[:5]
    return result


def sample_network_rates(interval=SAMPLE_INTERVAL):
    snap1 = network_snapshot()
    time.sleep(interval)
    snap2 = network_snapshot()
    rates = {}
    for name, values in snap1.items():
        if name not in snap2:
            continue
        down_bps = max(0, snap2[name]["rx_bytes"] - values["rx_bytes"]) / interval
        up_bps = max(0, snap2[name]["tx_bytes"] - values["tx_bytes"]) / interval
        rates[name] = {
            "down_bps": rounded(down_bps),
            "up_bps": rounded(up_bps),
            "total_bps": rounded(down_bps + up_bps),
            **snap2[name],
        }
    return rates


def net_payload():
    rates = sample_network_rates()
    route = default_route()
    connections = network_connections()
    addresses = network_addresses()
    socket_rows = network_socket_rows()
    interfaces = []

    for name, values in rates.items():
        entry = Path("/sys/class/net") / name
        connection = connections.get(name, {})
        is_wireless = (entry / "wireless").exists()
        is_virtual = "/virtual/" in str(entry.resolve())
        speed_mbps = read_int(entry / "speed")
        if speed_mbps is not None and speed_mbps < 0:
            speed_mbps = None
        ssid = ""
        if is_wireless:
            ssid, _, _ = run_capture(["iwgetid", name, "--raw"], timeout=1.0)
        kind = connection.get("kind") or ("wifi" if is_wireless else ("virtual" if is_virtual else "ethernet"))
        interfaces.append({
            "name": name,
            "kind": kind,
            "virtual": is_virtual,
            "state": read_text(entry / "operstate") or "unknown",
            "carrier": read_int(entry / "carrier"),
            "connection": connection.get("connection", ""),
            "ssid": ssid,
            "mac": read_text(entry / "address"),
            "mtu": read_int(entry / "mtu"),
            "speed_mbps": speed_mbps,
            "addresses": addresses.get(name, []),
            **values,
        })

    interfaces.sort(
        key=lambda item: (
            item["name"] != route.get("iface"),
            item["state"] != "up",
            item["virtual"],
            -item["total_bps"],
            item["name"],
        )
    )
    primary = next((item for item in interfaces if item["name"] == route.get("iface")), None)
    if primary is None:
        primary = next((item for item in interfaces if item["state"] == "up"), None)
    if primary is None and interfaces:
        primary = interfaces[0]
    primary = primary or {}
    processes_by_iface = network_processes_by_iface(socket_rows, interfaces, primary.get("name", ""))
    for item in interfaces:
        item["default_route"] = item["name"] == route.get("iface")
        item["top_processes"] = processes_by_iface.get(item["name"], [])

    return {
        "primary_iface": primary.get("name", ""),
        "gateway": route.get("gateway", ""),
        "down_bps": primary.get("down_bps", 0.0),
        "up_bps": primary.get("up_bps", 0.0),
        "total_bps": primary.get("total_bps", 0.0),
        "rx_bytes": primary.get("rx_bytes", 0),
        "tx_bytes": primary.get("tx_bytes", 0),
        "interfaces": interfaces,
        "active_interfaces": sum(1 for item in interfaces if item["state"] == "up"),
        "sockets": network_socket_summary(socket_rows),
        "process_telemetry_note": "Processes are ranked by attributable active sockets; per-process byte counters per interface require eBPF or equivalent tracing.",
    }


def cpu_payload():
    sensor_data = sensors_json()
    total_usage, per_core_usage = sample_cpu_usage()
    freqs = cpu_freqs_mhz()
    per_core = []
    for idx, usage in per_core_usage:
        freq = freqs[idx] if idx < len(freqs) else None
        per_core.append({
            "id": idx,
            "usage_percent": rounded(usage),
            "mhz": rounded(freq),
        })

    power_w = sample_power_from_energy(
        [
            "/sys/devices/virtual/powercap/intel-rapl/intel-rapl:0/energy_uj",
            "/sys/class/powercap/intel-rapl/intel-rapl:0/energy_uj",
            "/sys/devices/virtual/powercap/amd-rapl/amd-rapl:0/energy_uj",
            "/sys/class/powercap/amd-rapl/amd-rapl:0/energy_uj",
        ]
    )
    
    if power_w is None:
        p_val = find_sensor_value(sensor_data, ["power", "cpu_power", "package_power", "pp0"], "_input")
        if p_val is not None:
            if p_val > 5000: 
                power_w = p_val / 1_000_000.0
            else:
                power_w = p_val

    avg_freq = sum(freqs) / len(freqs) if freqs else None
    return {
        "model": cpu_model(),
        "total_percent": rounded(total_usage),
        "average_mhz": rounded(avg_freq),
        "max_mhz": rounded(cpu_max_mhz()),
        "temperature_c": rounded(cpu_temperature_c(sensor_data)),
        "power_w": rounded(power_w),
        "per_core": per_core,
        "top_processes": top_processes_cpu(),
    }


def ram_payload():
    mem = memory_info()
    mem["frequency_mhz"] = memory_speed_mhz()
    mem["top_processes"] = top_processes_ram()
    return mem


def disk_payload():
    blockdevices = parse_lsblk()
    os_filesystem = mounted_filesystem_usage("/")
    os_disk = {}
    disks = []
    disk_names = []
    skip_prefixes = ("loop", "ram", "sr", "zram")

    for device in blockdevices:
        if device.get("type") != "disk":
            continue
        name = device.get("name", "")
        if name.startswith(skip_prefixes):
            continue
        disk_names.append(device.get("kname") or name)

    rates = sample_disk_rates(disk_names)
    io_processes = top_processes_io()
    total_capacity = 0
    total_used = 0

    for device in blockdevices:
        if device.get("type") != "disk":
            continue
        name = device.get("name", "")
        if name.startswith(skip_prefixes):
            continue

        size_bytes = safe_int(device.get("size")) or 0
        device_used = safe_int(device.get("fsused"))
        device_free = safe_int(device.get("fsavail"))
        partitions = []
        sum_used = 0
        sum_free = 0
        has_partition_usage = False

        for child in device.get("children", []) or []:
            if child.get("type") != "part":
                continue
            part_size = safe_int(child.get("size")) or 0
            part_used = safe_int(child.get("fsused"))
            part_free = safe_int(child.get("fsavail"))
            mounted_usage = mounted_filesystem_usage(child.get("mountpoint")) if child.get("mountpoint") else {}
            if mounted_usage:
                part_size = mounted_usage["total_bytes"]
                part_used = mounted_usage["used_bytes"]
                part_free = mounted_usage["free_bytes"]
            if part_used is None and part_free is not None and part_size:
                part_used = max(0, part_size - part_free)
            if part_free is None and part_used is not None and part_size:
                part_free = max(0, part_size - part_used)
            part_percent = None
            raw_percent = child.get("fsuse%")
            if mounted_usage:
                part_percent = mounted_usage["percent"]
            elif isinstance(raw_percent, str):
                part_percent = safe_float(raw_percent.replace("%", ""))
            elif raw_percent is not None:
                part_percent = safe_float(raw_percent)
            if part_percent is None and part_size and part_used is not None:
                part_percent = (part_used / part_size) * 100.0

            if part_used is not None:
                sum_used += part_used
                has_partition_usage = True
            if part_free is not None:
                sum_free += part_free

            partitions.append({
                "name": child.get("name"),
                "path": child.get("path"),
                "mountpoint": child.get("mountpoint"),
                "fstype": child.get("fstype"),
                "total_bytes": part_size,
                "used_bytes": part_used,
                "free_bytes": part_free,
                "percent": rounded(part_percent),
            })

        if device_used is None and has_partition_usage:
            device_used = sum_used
        if device_free is None and has_partition_usage:
            device_free = sum_free if sum_free > 0 else max(0, size_bytes - (device_used or 0))
        if device_used is None and device_free is not None and size_bytes:
            device_used = max(0, size_bytes - device_free)
        if device_free is None and device_used is not None and size_bytes:
            device_free = max(0, size_bytes - device_used)

        device_percent = (device_used / size_bytes * 100.0) if device_used is not None and size_bytes else None
        if size_bytes and device_used is not None:
            total_capacity += size_bytes
            total_used += device_used

        rate = rates.get(device.get("kname") or name, {})
        disks.append({
            "name": name,
            "path": device.get("path"),
            "model": (device.get("model") or "").strip(),
            "transport": device.get("tran"),
            "rotational": device.get("rota"),
            "total_bytes": size_bytes,
            "used_bytes": device_used,
            "free_bytes": device_free,
            "percent": rounded(device_percent),
            "read_bps": rate.get("read_bps", 0.0),
            "write_bps": rate.get("write_bps", 0.0),
            "partitions": partitions,
        })

    for disk in disks:
        if any(partition.get("path") == os_filesystem.get("device") for partition in disk["partitions"]):
            os_disk = {
                "name": disk["name"],
                "path": disk["path"],
                "total_bytes": disk["total_bytes"],
                "used_bytes": disk["used_bytes"],
                "free_bytes": disk["free_bytes"],
                "percent": disk["percent"],
            }
            break

    return {
        "os_filesystem": os_filesystem,
        "os_disk": os_disk,
        "total_percent": rounded((total_used / total_capacity * 100.0) if total_capacity else 0.0),
        "devices": disks,
        "top_processes": io_processes,
    }


def nvidia_process_memory():
    stdout, _, code = run_capture(
        [
            "nvidia-smi",
            "--query-compute-apps=pid,process_name,used_gpu_memory",
            "--format=csv,noheader,nounits",
        ],
        timeout=2.0,
    )
    if code != 0 or not stdout:
        return {}
    rows = {}
    for line in stdout.splitlines():
        parts = [part.strip() for part in line.split(",")]
        if len(parts) < 3:
            continue
        pid = safe_int(parts[0])
        if pid is None:
            continue
        rows[pid] = {
            "name": parts[1],
            "vram_mb": rounded(safe_float(parts[2])),
        }
    return rows


def nvidia_top_processes(limit=5):
    memory_map = nvidia_process_memory()
    stdout, _, code = run_capture(["nvidia-smi", "pmon", "-c", "1", "-s", "um"], timeout=2.5)
    rows = {}
    if code == 0 and stdout:
        lines = stdout.splitlines()
        command_idx = 7  
        
        for line in lines:
            if line.lstrip().startswith("#") and ("command" in line.lower() or "name" in line.lower()):
                h_parts = line.split()
                try:
                    offset = 1 if h_parts[0] == "#" else 0
                    if "command" in h_parts:
                        command_idx = h_parts.index("command") - offset
                    elif "name" in h_parts:
                        command_idx = h_parts.index("name") - offset
                except (ValueError, IndexError):
                    pass
                break
                
        for line in lines:
            if not line or line.lstrip().startswith("#"):
                continue
            parts = line.split()
            if len(parts) <= command_idx or parts[1] == "-":
                continue
            pid = safe_int(parts[1])
            if pid is None:
                continue
            gpu_percent = safe_float(parts[3]) or 0.0
            mem_percent = safe_float(parts[4]) or 0.0
            command = " ".join(parts[command_idx:]).strip()
            rows[pid] = {
                "pid": pid,
                "name": command or memory_map.get(pid, {}).get("name", f"pid {pid}"),
                "gpu_percent": rounded(gpu_percent),
                "memory_percent": rounded(mem_percent),
                "vram_mb": memory_map.get(pid, {}).get("vram_mb"),
                "_score": gpu_percent + mem_percent,
            }

    if not rows and memory_map:
        for pid, info in memory_map.items():
            rows[pid] = {
                "pid": pid,
                "name": info.get("name", f"pid {pid}"),
                "gpu_percent": None,
                "memory_percent": None,
                "vram_mb": info.get("vram_mb"),
                "_score": info.get("vram_mb") or 0.0,
            }

    ordered = sorted(rows.values(), key=lambda item: item.get("_score", 0.0), reverse=True)
    return [{key: value for key, value in row.items() if key != "_score"} for row in ordered[:limit]]


def gpu_payload():
    name = display_model()
    vendor = detect_vendor_from_name(name)
    payload = {
        "available": False,
        "vendor": vendor,
        "name": name or "GPU",
        "usage_percent": 0.0,
        "memory_percent": None,
        "vram_total_mb": None,
        "vram_used_mb": None,
        "vram_free_mb": None,
        "temperature_c": None,
        "power_w": None,
        "fan_percent": None,
        "top_processes": [],
        "message": "GPU telemetry unavailable for the current driver/session.",
    }

    stdout, _, code = run_capture(
        [
            "nvidia-smi",
            "--query-gpu=name,utilization.gpu,utilization.memory,memory.total,memory.used,memory.free,temperature.gpu,power.draw,fan.speed",
            "--format=csv,noheader,nounits",
        ],
        timeout=2.0,
    )
    if code == 0 and stdout:
        parts = [part.strip() for part in stdout.splitlines()[0].split(",")]
        if len(parts) >= 9:
            payload.update({
                "available": True,
                "vendor": "nvidia",
                "name": parts[0] or payload["name"],
                "usage_percent": rounded(safe_float(parts[1]) or 0.0),
                "memory_percent": rounded(safe_float(parts[2])),
                "vram_total_mb": rounded(safe_float(parts[3])),
                "vram_used_mb": rounded(safe_float(parts[4])),
                "vram_free_mb": rounded(safe_float(parts[5])),
                "temperature_c": rounded(safe_float(parts[6])),
                "power_w": rounded(safe_float(parts[7])),
                "fan_percent": rounded(safe_float(parts[8])),
                "top_processes": nvidia_top_processes(),
                "message": "",
            })
            return payload

    busy_files = sorted(Path("/sys/class/drm").glob("card*/device/gpu_busy_percent"))
    if busy_files:
        busy_file = busy_files[0]
        device_dir = busy_file.parent
        hwmon_dir = next((path for path in device_dir.glob("hwmon/hwmon*")), None)
        total_vram = read_int(device_dir / "mem_info_vram_total")
        used_vram = read_int(device_dir / "mem_info_vram_used")
        fan_raw = read_float(hwmon_dir / "pwm1") if hwmon_dir else None
        fan_max = read_float(hwmon_dir / "pwm1_max") if hwmon_dir else None
        fan_percent = None
        if fan_raw is not None and fan_max and fan_max > 0:
            fan_percent = fan_raw / fan_max * 100.0

        power_raw = None
        if hwmon_dir:
            power_raw = read_float(hwmon_dir / "power1_average")
            if power_raw is None:
                power_raw = read_float(hwmon_dir / "power1_input")

        temp_raw = read_float(hwmon_dir / "temp1_input") if hwmon_dir else None
        payload.update({
            "available": True,
            "usage_percent": rounded(read_float(busy_file) or 0.0),
            "vram_total_mb": rounded(total_vram / (1024 * 1024.0)) if total_vram is not None else None,
            "vram_used_mb": rounded(used_vram / (1024 * 1024.0)) if used_vram is not None else None,
            "vram_free_mb": rounded((total_vram - used_vram) / (1024 * 1024.0)) if total_vram is not None and used_vram is not None else None,
            "temperature_c": rounded(temp_raw / 1000.0) if temp_raw is not None else None,
            "power_w": rounded(power_raw / 1_000_000.0) if power_raw is not None else None,
            "fan_percent": rounded(fan_percent),
            "message": "",
        })
        return payload

    return payload


def main():
    resource = (sys.argv[1] if len(sys.argv) > 1 else "").strip().lower()
    if resource not in {"cpu", "ram", "disk", "gpu", "net"}:
        json.dump({"error": "unknown resource", "resource": resource}, sys.stdout)
        sys.exit(1)

    payload = {
        "resource": resource,
        "updated_ms": int(time.time() * 1000),
    }

    if resource == "cpu":
        payload["cpu"] = cpu_payload()
    elif resource == "ram":
        payload["ram"] = ram_payload()
    elif resource == "disk":
        payload["disk"] = disk_payload()
    elif resource == "gpu":
        payload["gpu"] = gpu_payload()
    elif resource == "net":
        payload["net"] = net_payload()

    json.dump(payload, sys.stdout, separators=(",", ":"))
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
