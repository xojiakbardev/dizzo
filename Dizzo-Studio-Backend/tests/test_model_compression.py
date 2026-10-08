import json
import struct
from pathlib import Path

import httpx
import pytest

from app.services.model_compression import is_compressed
from tests.conftest import FakeStorage
from tests.test_catalog import ok
from tests.test_catalog_model import upload_model


def glb(document: dict, bin_size: int = 2000) -> bytes:
    data = json.dumps(document).encode()
    data += b" " * (-len(data) % 4)
    body = struct.pack("<I4s", len(data), b"JSON") + data + struct.pack("<I4s", bin_size, b"BIN\0") + b"\0" * bin_size
    return b"glTF" + struct.pack("<II", 2, 12 + len(body)) + body


PLAIN = glb({"asset": {"version": "2.0"}})
DRACO = glb({"asset": {"version": "2.0"}, "extensionsUsed": ["KHR_draco_mesh_compression"]})


def fake_tool(directory: Path, monkeypatch: pytest.MonkeyPatch, script: str) -> None:
    """Puts a stand-in `gltf-transform` first on PATH: called as `draco in out`."""
    tool = directory / "gltf-transform"
    tool.write_text("#!/bin/sh\n" + script + "\n")
    tool.chmod(0o755)
    monkeypatch.setenv("PATH", f"{directory}:{Path('/usr/bin')}:{Path('/bin')}")


def test_compressed_models_are_recognised() -> None:
    assert not is_compressed(PLAIN)
    assert is_compressed(DRACO)
    assert is_compressed(b"not a glb at all")


@pytest.mark.asyncio
async def test_an_uploaded_model_is_swapped_for_its_compressed_copy(
    admin_client: httpx.AsyncClient, storage: FakeStorage, tmp_path: Path, monkeypatch: pytest.MonkeyPatch,
) -> None:
    fake_tool(tmp_path, monkeypatch, 'head -c 100 "$2" > "$3"')
    media = ok(await upload_model(admin_client, storage, PLAIN))
    key = next(k for k in storage.bodies if media["id"] in k)
    assert storage.bodies[key] == PLAIN[:100]
    assert storage.objects[key].size_bytes == 100


@pytest.mark.asyncio
async def test_a_model_is_kept_when_compression_fails_or_is_not_needed(
    admin_client: httpx.AsyncClient, storage: FakeStorage, tmp_path: Path, monkeypatch: pytest.MonkeyPatch,
) -> None:
    fake_tool(tmp_path, monkeypatch, "echo broken >&2; exit 1")
    media = ok(await upload_model(admin_client, storage, PLAIN))
    assert storage.bodies[next(k for k in storage.bodies if media["id"] in k)] == PLAIN

    fake_tool(tmp_path, monkeypatch, 'head -c 100 "$2" > "$3"')
    media = ok(await upload_model(admin_client, storage, DRACO))
    assert storage.bodies[next(k for k in storage.bodies if media["id"] in k)] == DRACO
