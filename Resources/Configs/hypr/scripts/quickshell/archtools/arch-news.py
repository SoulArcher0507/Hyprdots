import sys
import urllib.request
import xml.etree.ElementTree as ET
import json
import os
import subprocess

CACHE_FILE = os.path.expanduser("~/.cache/quickshell/archnews.json")

def load_cache():
    if os.path.exists(CACHE_FILE):
        try:
            with open(CACHE_FILE, 'r') as f:
                return json.load(f)
        except:
            pass
    return {"seen": [], "unread": 0}

def save_cache(data):
    os.makedirs(os.path.dirname(CACHE_FILE), exist_ok=True)
    with open(CACHE_FILE, 'w') as f:
        json.dump(data, f)

if len(sys.argv) > 1 and sys.argv[1] == "--clear":
    data = load_cache()
    data["unread"] = 0
    save_cache(data)
    print(json.dumps({"unread": 0}))
    sys.exit(0)

data = load_cache()
req = urllib.request.Request('https://archlinux.org/feeds/news/', headers={'User-Agent': 'Mozilla/5.0'})
try:
    with urllib.request.urlopen(req, timeout=10) as response:
        xml_data = response.read()
    root = ET.fromstring(xml_data)
    items = root.findall('./channel/item')
    
    unread_added = 0
    
    for item in reversed(items[:10]):
        link = item.find('link').text
        title = item.find('title').text
        if link not in data["seen"]:
            unread_added += 1
            data["seen"].append(link)
            subprocess.run(["notify-send", "-a", "ArchTools", "-i", "distributor-logo-archlinux", "Arch Linux News", title], check=False)
            
    if unread_added > 0:
        data["unread"] += unread_added
        save_cache(data)
        
    print(json.dumps({"unread": data["unread"]}))
except Exception as e:
    print(json.dumps({"error": str(e), "unread": data.get("unread", 0)}))
