#!/usr/bin/env python3
"""Build decision 496's K1 ground detail array from local ambientCG CC0 maps.

Only Pillow and numpy are needed. RGB stores unit-mean detail at half strength;
alpha stores percentile-normalized height. No source image is copied to output.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image


# Metres one 512 tile spans. The two asphalt photos hold their pattern three times
# over each way, so their tile spans three 4 m (6 m) patterns, not a 1.3 m (2 m) one.
LAYERS = (
    ("asphalt", "Road013A", 12.0),
    ("asphalt_patched", "Road012B", 18.0),
    ("concrete_road", "Concrete031", 3.0),
    ("pavement", "PavingStones136", 2.5),
    ("gravel", "Gravel041", 1.5),
    ("ballast", "Gravel043", 1.5),
    ("soil", "Ground106", 3.0),
    ("dry_grass", "Ground037", 3.0),
)
SIZE = 512
SIGMA = 96.0
LICENSE = "CC0 1.0, ambientCG"
IMPORT_SETTINGS = '''[remap]

importer="2d_array_texture"
type="CompressedTexture2DArray"

[params]

compress/mode=2
mipmaps/generate=true
slices/horizontal=1
slices/vertical=8
'''


def sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def resize_float(values: np.ndarray) -> np.ndarray:
    """LANCZOS in float mode, without an intermediate 8-bit clamp."""
    return np.asarray(
        Image.fromarray(values.astype(np.float32)).resize(
            (SIZE, SIZE), Image.Resampling.LANCZOS
        ),
        dtype=np.float64,
    )


def wrapped_blur(rgb: np.ndarray) -> np.ndarray:
    """Periodic Gaussian convolution: do not introduce a border into a tile."""
    height, width = rgb.shape[:2]
    fy = np.fft.fftfreq(height)[:, None]
    fx = np.fft.rfftfreq(width)[None, :]
    kernel = np.exp(-2.0 * np.pi**2 * SIGMA**2 * (fx * fx + fy * fy))
    return np.fft.irfft2(
        np.fft.rfft2(rgb, axes=(0, 1)) * kernel[:, :, None],
        s=(height, width),
        axes=(0, 1),
    )


def seam_ratio(values: np.ndarray) -> float:
    """Mean absolute wrap difference / mean absolute interior neighbour difference.

    Horizontal and vertical samples have equal weight on these square layers.
    Values are the final quantized channels, not the original photograph.
    """
    edge = (np.abs(values[0] - values[-1]).mean()
            + np.abs(values[:, 0] - values[:, -1]).mean()) * 0.5
    inside = (np.abs(np.diff(values, axis=0)).mean()
              + np.abs(np.diff(values, axis=1)).mean()) * 0.5
    return float(edge / max(float(inside), 1e-12))


def build_layer(src: Path, index: int) -> tuple[np.ndarray, dict]:
    name, source_id, tile_m = LAYERS[index]
    color_path = src / source_id / f"{source_id}_1K-JPG_Color.jpg"
    height_path = src / source_id / f"{source_id}_1K-JPG_Displacement.jpg"
    with Image.open(color_path) as image:
        if image.size != (1024, 1024):
            raise ValueError(f"F-INPUT-SHAPE: {color_path}: {image.size}")
        rgb = np.asarray(image.convert("RGB"), dtype=np.float64) / 255.0
    with Image.open(height_path) as image:
        if image.size != (1024, 1024):
            raise ValueError(f"F-INPUT-SHAPE: {height_path}: {image.size}")
        height = resize_float(np.asarray(image.convert("L"), dtype=np.float64) / 255.0)

    source_mean = rgb.mean(axis=(0, 1))
    delit = rgb / np.maximum(wrapped_blur(rgb), 1e-6) * source_mean
    reduced = np.stack([resize_float(delit[:, :, c]) for c in range(3)], axis=2)
    detail = reduced / np.maximum(reduced.mean(axis=(0, 1)), 1e-6)
    luma = detail @ np.array([0.2126, 0.7152, 0.0722])
    detail = detail * 0.7 + luma[:, :, None] * 0.3
    rgb_out = np.clip(detail * 0.5, 0.0, 1.0)
    low, high = np.percentile(height, (2.0, 98.0))
    if high - low <= 1e-6:
        raise ValueError(f"F-INPUT-HEIGHT: {height_path}: flat height range")
    alpha = np.clip((height - low) / (high - low), 0.0, 1.0)
    rgba = np.rint(np.dstack((rgb_out, alpha)) * 255.0).astype(np.uint8)
    quantized = rgba.astype(np.float64) / 255.0
    output_mean = quantized[:, :, :3].mean(axis=(0, 1))
    if np.any(np.abs(output_mean - 0.5) > 0.03):
        raise ValueError(f"F-NORMALIZATION: {source_id}: {output_mean.tolist()}")
    ratio = seam_ratio(quantized)
    row = {
        "index": index,
        "name": name,
        "source_id": source_id,
        "tile_m": tile_m,
        "source_mean_srgb": source_mean.tolist(),
        "output_mean_rgb": output_mean.tolist(),
        "seam_ratio": ratio,
        "seam_ratio_rgb": seam_ratio(quantized[:, :, :3]),
        "seam_ratio_alpha": seam_ratio(quantized[:, :, 3:]),
        "height_percentiles": [float(low), float(high)],
        "license": LICENSE,
        "color_sha256": sha256(color_path),
        "displacement_sha256": sha256(height_path),
    }
    if ratio > 1.5:
        print(f"W-SEAM: {source_id}: RGBA wrap/interior={ratio:.6f} > 1.5", file=sys.stderr)
    return rgba, row


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--src", type=Path, required=True, help="Local ground_cc0 root")
    parser.add_argument("--out", type=Path, required=True, help="Generated ground texture directory")
    args = parser.parse_args()
    src, out = args.src.resolve(), args.out.resolve()
    if out == src or src in out.parents:
        parser.error("output must not be inside the source directory")
    # Validate all sixteen inputs before producing an incomplete strip.
    for _, source_id, _ in LAYERS:
        for suffix in ("Color", "Displacement"):
            path = src / source_id / f"{source_id}_1K-JPG_{suffix}.jpg"
            if not path.is_file():
                print(f"F-INPUT-MISSING: {path}", file=sys.stderr)
                return 2
    layers, rows = [], []
    for index in range(len(LAYERS)):
        layer, row = build_layer(src, index)
        layers.append(layer)
        rows.append(row)
        means = ",".join(f"{v:.6f}" for v in row["source_mean_srgb"])
        print(f"{index} {row['source_id']} mean_srgb=({means}) seam={row['seam_ratio']:.6f}")
    out.mkdir(parents=True, exist_ok=True)
    png = out / "ground_layers.png"
    Image.fromarray(np.concatenate(layers, axis=0)).save(png)
    import_path = out / "ground_layers.png.import"
    # A later rebuild must keep paths/UIDs filled in by Godot's importer.
    if not import_path.exists():
        import_path.write_text(IMPORT_SETTINGS, encoding="utf-8", newline="\n")
    ledger = out / "ground_layers.json"
    ledger.write_text(json.dumps(rows, ensure_ascii=False, indent=2) + "\n", encoding="utf-8", newline="\n")
    for path in (png, import_path, ledger):
        print(f"OUTPUT {path.name} bytes={path.stat().st_size} sha256={sha256(path)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
