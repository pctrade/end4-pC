#!/usr/bin/env -S /bin/sh -c "source $(eval echo $ILLOGICAL_IMPULSE_VIRTUAL_ENV)/bin/activate&&exec python -E \"$0\" \"$@\""
import argparse
import glob
import json
import os

# EDID byte 20, bits 6-4: supported color bit depth on digital displays.
BPC_CODES = {1: 6, 2: 8, 3: 10, 4: 12, 5: 14, 6: 16}

# CTA-861 extended data block tags.
EXT_TAG_HDR_STATIC_METADATA = 0x06
EXT_TAG_HDR_DYNAMIC_METADATA = 0x14

UNKNOWN_CAPS = {"digital": None, "maxBpc": None, "hdr": None, "hdrDynamic": None}


def find_edid_path(output_name):
    # st_size is always 0 for this sysfs attribute, so we can only check hat it exists. An empty read means disconnected.
    matches = glob.glob(f"/sys/class/drm/card*-{output_name}/edid")
    return matches[0] if matches else None


def parse_edid(data):
    caps = {"digital": False, "maxBpc": None, "hdr": False, "hdrDynamic": False}

    if len(data) < 128:
        return caps

    b20 = data[20]
    caps["digital"] = bool(b20 & 0x80)
    if caps["digital"]:
        bpc_code = (b20 >> 4) & 0x7
        caps["maxBpc"] = BPC_CODES.get(bpc_code)

    n_ext = data[126]
    for i in range(n_ext):
        start = 128 + 128 * i
        ext = data[start:start + 128]
        if len(ext) < 5 or ext[0] != 0x02:
            continue  # not a CTA-861 extension block

        dtd_offset = ext[2]
        pos = 4
        while pos < dtd_offset and pos < len(ext):
            header = ext[pos]
            tag = header >> 5
            length = header & 0x1F
            if tag == 7 and length >= 1 and pos + 1 < len(ext):
                ext_tag = ext[pos + 1]
                if ext_tag == EXT_TAG_HDR_STATIC_METADATA:
                    caps["hdr"] = True
                elif ext_tag == EXT_TAG_HDR_DYNAMIC_METADATA:
                    caps["hdrDynamic"] = True
            pos += length + 1

    return caps


def get_caps(output_name):
    path = find_edid_path(output_name)
    if not path:
        return {**UNKNOWN_CAPS, "source": "no-edid"}
    try:
        with open(path, "rb") as f:
            data = f.read()
    except OSError:
        return {**UNKNOWN_CAPS, "source": "read-error"}

    if not data:
        return {**UNKNOWN_CAPS, "source": "empty-edid"}

    caps = parse_edid(data)
    caps["source"] = path
    return caps


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("outputs", nargs="+", help="Monitor output names, e.g. DP-1 HDMI-A-1")
    args = p.parse_args()

    print(json.dumps({name: get_caps(name) for name in args.outputs}))
