#!/usr/bin/env python3
import re
import subprocess
import json
import os

def get_upower_devices():
    devices = []
    try:
        out = subprocess.check_output(["upower", "-e"]).decode("utf-8")
        for line in out.strip().split("\n"):
            line = line.strip()
            if not line or "battery_BAT" in line or "line_power_ACAD" in line or "DisplayDevice" in line:
                continue
            
            info_out = subprocess.check_output(["upower", "-i", line]).decode("utf-8")
            
            model = None
            dev_type = "unknown"
            battery = None
            connected = False
            charging = False
            
            model_m = re.search(r"model:\s*(.*)", info_out)
            if model_m:
                model = model_m.group(1).strip()
                
            type_m = re.search(r"device-type:\s*(.*)", info_out)
            if type_m:
                dev_type = type_m.group(1).strip()
                
            percent_m = re.search(r"percentage:\s*(\d+)%", info_out)
            if percent_m:
                battery = int(percent_m.group(1))
                
            connected_m = re.search(r"present:\s*(yes|no)", info_out)
            if connected_m:
                connected = connected_m.group(1) == "yes"
                
            state_m = re.search(r"state:\s*(.*)", info_out)
            if state_m:
                state_str = state_m.group(1).strip()
                charging = state_str == "charging"
                if not connected:
                    connected = state_str not in ["unknown", "empty"]

            if model:
                devices.append({
                    "name": model,
                    "type": dev_type,
                    "connected": connected,
                    "battery": battery,
                    "charging": charging,
                    "connection": "wireless/USB"
                })
    except Exception as e:
        pass
    return devices

def get_bluetooth_devices():
    devices = []
    try:
        out = subprocess.check_output(["bluetoothctl", "devices"]).decode("utf-8")
        for line in out.strip().split("\n"):
            m = re.match(r"Device\s+([0-9A-Fa-f:]+)\s+(.*)", line)
            if m:
                mac = m.group(1)
                name = m.group(2)
                
                info_out = subprocess.check_output(["bluetoothctl", "info", mac]).decode("utf-8")
                connected = "Connected: yes" in info_out
                
                battery = None
                bat_m = re.search(r"Battery Percentage:\s+.*\((\d+)\)", info_out)
                if not bat_m:
                    bat_m = re.search(r"Battery Percentage:\s+(\d+)", info_out)
                if bat_m:
                    battery = int(bat_m.group(1))
                
                dev_type = "unknown"
                if "Icon: audio-headset" in info_out or "audio" in name.lower() or "buds" in name.lower() or "head" in name.lower():
                    dev_type = "headphone"
                elif "Icon: input-mouse" in info_out or "mouse" in name.lower():
                    dev_type = "mouse"
                elif "Icon: input-keyboard" in info_out or "keyboard" in name.lower():
                    dev_type = "keyboard"
                
                devices.append({
                    "name": name,
                    "connected": connected,
                    "battery": battery,
                    "charging": False,
                    "type": dev_type,
                    "connection": "bluetooth"
                })
    except Exception as e:
        pass
    return devices

def get_usb_devices():
    devices = []
    try:
        usb_dir = "/sys/bus/usb/devices"
        if os.path.exists(usb_dir):
            for filename in os.listdir(usb_dir):
                product_path = os.path.join(usb_dir, filename, "product")
                if os.path.exists(product_path):
                    with open(product_path, "r") as f:
                        name = f.read().strip()
                    
                    if not name or name in ["xHCI Host Controller", "Bluetooth Radio", "Integrated Camera", "Root Hub"]:
                        continue
                        
                    name_lower = name.lower()
                    if "ite device" in name_lower or "ite tech" in name_lower:
                        continue
                        
                    dev_type = "unknown"
                    if "mouse" in name_lower:
                        dev_type = "mouse"
                    elif "keyboard" in name_lower:
                        dev_type = "keyboard"
                    elif "headset" in name_lower or "headphone" in name_lower or "audio" in name_lower:
                        dev_type = "headphone"
                        
                    devices.append({
                        "name": name,
                        "connected": True,
                        "battery": None,
                        "charging": False,
                        "type": dev_type,
                        "connection": "wired"
                    })
    except Exception as e:
        pass
    return devices

def get_kdeconnect_devices():
    devices = []
    try:
        out = subprocess.check_output(["kdeconnect-cli", "-l", "--id-name-only"]).decode("utf-8")
        for line in out.strip().split("\n"):
            line = line.strip()
            if not line:
                continue
            
            parts = line.split(" ", 1)
            if len(parts) < 2:
                continue
            dev_id, dev_name = parts[0], parts[1]
            
            connected = False
            try:
                reach_out = subprocess.check_output([
                    "qdbus", "org.kde.kdeconnect", 
                    f"/modules/kdeconnect/devices/{dev_id}", 
                    "org.kde.kdeconnect.device.isReachable"
                ]).decode("utf-8").strip()
                connected = reach_out == "true"
            except Exception:
                pass
                
            battery = None
            charging = False
            dev_type = "phone"
            
            if connected:
                try:
                    charge_out = subprocess.check_output([
                        "qdbus", "org.kde.kdeconnect", 
                        f"/modules/kdeconnect/devices/{dev_id}/battery", 
                        "org.kde.kdeconnect.device.battery.charge"
                    ]).decode("utf-8").strip()
                    battery = int(charge_out)
                    
                    charge_state = subprocess.check_output([
                        "qdbus", "org.kde.kdeconnect", 
                        f"/modules/kdeconnect/devices/{dev_id}/battery", 
                        "org.kde.kdeconnect.device.battery.isCharging"
                    ]).decode("utf-8").strip()
                    charging = charge_state == "true"
                except Exception:
                    pass
                
                try:
                    type_out = subprocess.check_output([
                        "qdbus", "org.kde.kdeconnect", 
                        f"/modules/kdeconnect/devices/{dev_id}", 
                        "org.kde.kdeconnect.device.type"
                    ]).decode("utf-8").strip()
                    if type_out:
                        dev_type = type_out
                except Exception:
                    pass
            
            type_map = {
                "phone": "phone",
                "tablet": "tablet",
                "laptop": "laptop",
                "pc": "laptop",
                "desktop": "laptop"
            }
            mapped_type = type_map.get(dev_type, "phone")
            
            devices.append({
                "name": dev_name,
                "connected": connected,
                "battery": battery,
                "charging": charging,
                "type": mapped_type,
                "connection": "kdeconnect"
            })
    except Exception as e:
        pass
    return devices

# Combine lists and avoid duplicates
upower_devs = get_upower_devices()
bt_devs = get_bluetooth_devices()
usb_devs = get_usb_devices()
kde_devs = get_kdeconnect_devices()

all_devices = []
seen_names = set()

# 1. Add KDE Connect devices
for d in kde_devs:
    all_devices.append(d)
    seen_names.add(d["name"].lower())

# 2. Add BT devices
for d in bt_devs:
    if d["name"].lower() not in seen_names:
        all_devices.append(d)
        seen_names.add(d["name"].lower())

# 3. Add UPower devices
for d in upower_devs:
    if d["name"].lower() not in seen_names:
        all_devices.append(d)
        seen_names.add(d["name"].lower())

# 4. Add USB devices (excluding internal/duplicates)
for d in usb_devs:
    if "hub" in d["name"].lower() or "controller" in d["name"].lower():
        continue
    if d["name"].lower() not in seen_names:
        all_devices.append(d)
        seen_names.add(d["name"].lower())

# Sort: connected devices first
all_devices.sort(key=lambda d: not d["connected"])
print(json.dumps(all_devices))
