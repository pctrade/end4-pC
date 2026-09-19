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
EXT_TAG_HF_EEODB = 0x78

# DisplayID 2.0 data block tag that wraps a CTA-861-style data block
# collection (same tag/length encoding as the legacy CTA-861 extension).
DISPLAYID_TAG_CTA861 = 0x81

UNKNOWN_CAPS = {"digital": None, "maxBpc": None, "hdr": None, "hdrDynamic": None}


def find_edid_path(output_name):
    # st_size is always 0 for this sysfs attribute, so we can only check hat it exists. An empty read means disconnected.
    matches = glob.glob(f"/sys/class/drm/card*-{output_name}/edid")
    return matches[0] if matches else None


def scan_cta_data_blocks(data, start, end):
    """Walk a CTA-861-style data block collection (1-byte tag/length
    headers, tag 7 meaning an extended tag follows) between [start, end)
    and report which HDR-related blocks it contains. Used both for a
    legacy standalone CTA-861 extension and for the CTA-861 block
    DisplayID 2.0 nests inside its own data blocks."""
    hdr = False
    hdr_dynamic = False
    pos = start
    while pos < end and pos < len(data):
        header = data[pos]
        tag = header >> 5
        length = header & 0x1F
        if tag == 7 and length >= 1 and pos + 1 < len(data):
            ext_tag = data[pos + 1]
            if ext_tag == EXT_TAG_HDR_STATIC_METADATA:
                hdr = True
            elif ext_tag == EXT_TAG_HDR_DYNAMIC_METADATA:
                hdr_dynamic = True
        pos += length + 1
    return hdr, hdr_dynamic


def find_hf_eeodb_count(ext):
    if len(ext) < 5:
        return None
    dtd_offset = ext[2]
    pos = 4
    end = min(dtd_offset, len(ext))
    while pos < end:
        header = ext[pos]
        tag = header >> 5
        length = header & 0x1F
        if tag == 7 and length == 2 and pos + 2 < len(ext) and ext[pos + 1] == EXT_TAG_HF_EEODB:
            return ext[pos + 2]
        pos += length + 1
    return None


def scan_displayid_extension(ext):
    """DisplayID 2.0 uses its own 3-byte-header data blocks (tag,
    revision, length), unrelated to CTA-861's 1-byte header. Newer
    panels report HDR support by nesting a full CTA-861-style block
    collection inside one of these, tagged 0x81, instead of exposing a
    standalone CTA-861 extension at all."""
    hdr = False
    hdr_dynamic = False
    if len(ext) < 5:
        return hdr, hdr_dynamic

    section_bytes = ext[2]
    pos = 5
    end = min(5 + section_bytes, len(ext))
    while pos + 3 <= end:
        tag = ext[pos]
        length = ext[pos + 2]
        payload_start = pos + 3
        payload_end = payload_start + length
        if payload_end > len(ext):
            break
        if tag == DISPLAYID_TAG_CTA861:
            block_hdr, block_hdr_dynamic = scan_cta_data_blocks(ext, payload_start, payload_end)
            hdr = hdr or block_hdr
            hdr_dynamic = hdr_dynamic or block_hdr_dynamic
        pos = payload_end

    return hdr, hdr_dynamic


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
        if len(ext) >= 5 and ext[0] == 0x02:
            real_count = find_hf_eeodb_count(ext)
            if real_count is not None and real_count > n_ext:
                n_ext = real_count
            break

    truncated = len(data) < 128 + 128 * n_ext

    for i in range(n_ext):
        start = 128 + 128 * i
        ext = data[start:start + 128]
        if len(ext) < 5:
            continue

        if ext[0] == 0x02:
            dtd_offset = ext[2]
            hdr, hdr_dynamic = scan_cta_data_blocks(ext, 4, min(dtd_offset, len(ext)))
        elif ext[0] == 0x70:
            hdr, hdr_dynamic = scan_displayid_extension(ext)
        else:
            continue

        caps["hdr"] = caps["hdr"] or hdr
        caps["hdrDynamic"] = caps["hdrDynamic"] or hdr_dynamic

    if truncated and not caps["hdr"]:
        caps["hdr"] = None
    if truncated and not caps["hdrDynamic"]:
        caps["hdrDynamic"] = None

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
