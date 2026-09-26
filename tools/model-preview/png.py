"""Remove renderer timestamps without re-encoding pixels or changing color chunks."""
import struct


def strip_metadata(path):
    raw = path.read_bytes()
    result = bytearray(raw[:8])
    offset = 8
    while offset < len(raw):
        length = struct.unpack_from(">I", raw, offset)[0]
        kind = raw[offset+4:offset+8]
        end = offset+length+12
        # Blender writes date/render-time PNG metadata even with stamp overlays off.
        # Keep image/color/resolution chunks verbatim; identity must not depend on time.
        if kind not in (b"tEXt", b"zTXt", b"iTXt", b"tIME", b"eXIf"):
            result.extend(raw[offset:end])
        offset = end
    path.write_bytes(result)
