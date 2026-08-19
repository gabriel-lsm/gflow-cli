"""
i2v_runner.py — thin wrapper around ``gflow video i2v``.

Reads the video prompt from a file so that multi-line prompts containing
lines that begin with ``-`` are not mis-parsed as CLI flags by Click or by
the Windows/PowerShell shell layer.

After a successful generation, renames the output video to match the input
image filename (e.g. frame.jpeg -> frame.mp4) so that the batch script's
idempotency check works correctly.

Usage (called by batch_video_gen.ps1):
    uv run python scripts/i2v_runner.py
        --prompt-file C:\\Temp\\prompt.txt
        --initial-frame path/to/frame.jpeg
        --output-name frame.mp4
        --model veo-lite-lp
        --duration 8
        --aspect 9:16
        --project <project-id>
        --collection <collection-id>
        --out-dir path/to/videos/
"""

import argparse
import json
import pathlib
import shutil
import subprocess
import sys


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Wrapper: reads prompt from file and calls gflow video i2v"
    )
    parser.add_argument("--prompt-file", required=True, help="Path to UTF-8 text file containing the prompt")
    parser.add_argument("--initial-frame", required=True, help="Initial frame image path")
    parser.add_argument("--output-name", required=True, help="Desired output filename (e.g. frame.mp4)")
    parser.add_argument("--model", default="veo-lite-lp", help="Veo model")
    parser.add_argument("--duration", default="8", help="Duration in seconds")
    parser.add_argument("--aspect", default="9:16", help="Aspect ratio")
    parser.add_argument("--project", required=True, help="Flow project ID")
    parser.add_argument("--collection", required=True, help="Flow collection ID")
    parser.add_argument("--out-dir", required=True, help="Output directory for mp4")

    args = parser.parse_args()

    prompt_path = pathlib.Path(args.prompt_file)
    if not prompt_path.exists():
        print(f"ERROR: prompt file not found: {prompt_path}", file=sys.stderr)
        sys.exit(1)

    prompt = prompt_path.read_text(encoding="utf-8").strip()
    out_dir = pathlib.Path(args.out_dir)
    desired_path = out_dir / args.output_name

    # Build argument list — Python subprocess uses CreateProcess directly on
    # Windows, so each element is properly quoted. No shell interpolation.
    cmd = [
        "gflow", "video", "i2v",
        "--initial-frame", args.initial_frame,
        "--model", args.model,
        "--duration", args.duration,
        "--aspect", args.aspect,
        "--project", args.project,
        "--collection", args.collection,
        "--out-dir", str(out_dir),
        "--json",   # Machine-readable output so we can capture the saved path
        "--",       # Click end-of-options marker
        prompt,     # Passed as a single opaque string — no shell splitting
    ]

    result = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8")

    # Forward stderr (structured logs) to our stderr for debugging
    if result.stderr:
        print(result.stderr, file=sys.stderr, end="")

    if result.returncode != 0:
        # Forward stdout too on error (might contain error details)
        if result.stdout:
            print(result.stdout, end="")
        sys.exit(result.returncode)

    # Parse JSON output to find where gflow saved the file
    saved_path: pathlib.Path | None = None
    for line in result.stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            data = json.loads(line)
            if "local_path" in data and data.get("succeeded"):
                saved_path = pathlib.Path(data["local_path"])
                break
        except json.JSONDecodeError:
            continue

    # Fallback: find the newest mp4 in out_dir that isn't the desired name yet
    if saved_path is None or not saved_path.exists():
        candidates = sorted(out_dir.glob("*.mp4"), key=lambda p: p.stat().st_mtime, reverse=True)
        candidates = [p for p in candidates if p.name != args.output_name]
        if candidates:
            saved_path = candidates[0]

    # Rename to the desired name
    if saved_path and saved_path.exists() and saved_path != desired_path:
        if desired_path.exists():
            desired_path.unlink()
        shutil.move(str(saved_path), str(desired_path))
        print(f"Saved: {desired_path}")
    elif desired_path.exists():
        print(f"Saved: {desired_path}")
    else:
        print("ERROR: video file not found after generation", file=sys.stderr)
        sys.exit(1)

    sys.exit(0)


if __name__ == "__main__":
    main()
