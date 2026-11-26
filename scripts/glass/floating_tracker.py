#!/usr/bin/env python3
import json
import os
import socket
import time

PATH = f"{os.environ['XDG_RUNTIME_DIR']}/hypr/{os.environ['HYPRLAND_INSTANCE_SIGNATURE']}/.socket.sock"
INTERVAL = 0.004


def query() -> dict:
    with socket.socket(socket.AF_UNIX) as sock:
        sock.connect(PATH)
        sock.sendall(b"j/activewindow")
        chunks = []
        while True:
            chunk = sock.recv(65536)
            if not chunk:
                break
            chunks.append(chunk)
    return json.loads(b"".join(chunks))


def main():
    last = None
    while True:
        try:
            win = query()
            title = win.get("title")
            at = win.get("at")
            if title and at and (title, tuple(at)) != last:
                last = (title, tuple(at))
                print(json.dumps({"title": title, "at": at}), flush=True)
        except Exception:
            pass
        time.sleep(INTERVAL)


if __name__ == "__main__":
    main()
