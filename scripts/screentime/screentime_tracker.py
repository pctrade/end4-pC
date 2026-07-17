#!/usr/bin/env python3
import os
import sys
import json
import time
import datetime
import subprocess

def get_btime():
    try:
        with open("/proc/stat", "r") as f:
            for line in f:
                if line.startswith("btime"):
                    return int(line.split()[1])
    except Exception:
        pass
    return int(time.time())

def is_locked():
    lock_comms = {"hyprlock", "gtklock", "swaylock"}
    try:
        for pid in os.listdir("/proc"):
            if pid.isdigit():
                try:
                    with open(f"/proc/{pid}/comm", "r") as f:
                        comm = f.read().strip()
                        if comm in lock_comms:
                            return True
                except Exception:
                    pass
    except Exception:
        pass
    return False

def get_active_window_class():
    try:
        out = subprocess.check_output(["hyprctl", "activewindow", "-j"]).decode("utf-8")
        data = json.loads(out)
        return data.get("class", "").strip()
    except Exception:
        return ""

def main():
    cache_dir = os.path.expanduser("~/.cache")
    os.makedirs(cache_dir, exist_ok=True)
    cache_path = os.path.join(cache_dir, "screentime.json")
    
    btime = get_btime()
    
    # Load state
    data = {
        "btime": btime,
        "total_screentime": 0,
        "total_uptime": 0,
        "apps": {},
        "hourly_usage": {str(i): 0 for i in range(24)}
    }
    
    if os.path.exists(cache_path):
        try:
            with open(cache_path, "r") as f:
                loaded = json.load(f)
                if loaded.get("btime") == btime:
                    data = loaded
                    if "hourly_usage" not in data or not isinstance(data["hourly_usage"], dict):
                        data["hourly_usage"] = {str(i): 0 for i in range(24)}
                    else:
                        for i in range(24):
                            if str(i) not in data["hourly_usage"]:
                                data["hourly_usage"][str(i)] = 0
        except Exception:
            pass

    interval = 2 # Check every 2 seconds
    
    try:
        while True:
            # 1. Update total uptime
            try:
                with open("/proc/uptime", "r") as f:
                    uptime_val = float(f.read().split()[0])
                    data["total_uptime"] = int(uptime_val)
            except Exception:
                pass
                
            # 2. Check lock state and update screentime
            if not is_locked():
                active_class = get_active_window_class()
                data["total_screentime"] += interval
                
                # Update hourly usage
                curr_hour = str(datetime.datetime.now().hour)
                data["hourly_usage"][curr_hour] = data["hourly_usage"].get(curr_hour, 0) + interval
                
                # Update app usage
                if active_class:
                    data["apps"][active_class] = data["apps"].get(active_class, 0) + interval
            
            # 3. Write cache
            try:
                temp_path = cache_path + ".tmp"
                with open(temp_path, "w") as f:
                    json.dump(data, f, indent=2)
                os.replace(temp_path, cache_path)
            except Exception:
                pass
                
            time.sleep(interval)
            
    except KeyboardInterrupt:
        sys.exit(0)

if __name__ == "__main__":
    main()
