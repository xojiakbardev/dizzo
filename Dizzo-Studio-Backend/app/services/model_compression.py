"""Draco compression for uploaded GLB models.

Admins upload models straight from their 3D tool, uncompressed: a garment
weighed 3-4 MB and loaded slowly on phones. Draco brings it down about ten
times while keeping vertex positions in the model's own units (to ~0.02 mm),
material names (the "tint" fabric) and everything else the print areas rely
on. The work is done by the gltf-transform CLI baked into the Docker image;
without it (local runs, tests) models are kept as uploaded.
"""

import asyncio
import json
import logging
import shutil
import struct
import tempfile
from pathlib import Path

logger = logging.getLogger(__name__)

COMPRESSED_EXTENSIONS = ("KHR_draco_mesh_compression", "EXT_meshopt_compression")
TIMEOUT_SECONDS = 120


def is_compressed(glb: bytes) -> bool:
    """True when the GLB already uses mesh compression, or isn't one we can read."""
    # 12-byte header, then the JSON chunk: length, type, data.
    if len(glb) < 20 or glb[:4] != b"glTF":
        return True
    (length,) = struct.unpack_from("<I", glb, 12)
    try:
        document = json.loads(glb[20 : 20 + length])
    except ValueError:
        return True
    used = document.get("extensionsUsed") or []
    return any(name in used for name in COMPRESSED_EXTENSIONS)


async def draco_compress(glb: bytes) -> bytes | None:
    """The Draco-compressed model, or None to keep the original (tool missing,
    already compressed, failed, or no smaller)."""
    tool = shutil.which("gltf-transform")
    if tool is None or is_compressed(glb):
        return None
    with tempfile.TemporaryDirectory() as tmp:
        source, target = Path(tmp) / "in.glb", Path(tmp) / "out.glb"
        source.write_bytes(glb)
        process = await asyncio.create_subprocess_exec(
            tool, "draco", str(source), str(target),
            stdout=asyncio.subprocess.DEVNULL, stderr=asyncio.subprocess.PIPE,
        )
        try:
            _, stderr = await asyncio.wait_for(process.communicate(), TIMEOUT_SECONDS)
        except TimeoutError:
            process.kill()
            await process.wait()
            logger.warning("model compression timed out after %ss", TIMEOUT_SECONDS)
            return None
        if process.returncode != 0 or not target.exists():
            logger.warning("model compression failed: %s", stderr.decode(errors="replace")[-500:])
            return None
        compressed = target.read_bytes()
    return compressed if len(compressed) < len(glb) else None
