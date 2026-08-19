import os
import glob
import subprocess
import time
import sys

image_dir = r"C:\Users\gabri\Downloads\Sérum Retinol images"
images = sorted(glob.glob(os.path.join(image_dir, "*.jpeg")))
prompt_file = "my prompts/POV/serum.txt"
audio_file = "audio/Audio Larissa.mp3"
project_id = "5f9d6103-e16b-45a1-b3c0-345216b149cd"
collection_id = "d59a9fca-6a08-4a76-a1a1-02ebf330cd8b"
out_dir = r"C:\Users\gabri\Desktop\SerumVideos"
model = "veo-lite-lp"

os.makedirs(out_dir, exist_ok=True)

with open(prompt_file, "r", encoding="utf-8") as f:
    prompt = f.read().strip()

def get_audio_duration(file_path):
    cmd = ["ffprobe", "-v", "error", "-show_entries", "format=duration",
           "-of", "default=noprint_wrappers=1:nokey=1", file_path]
    result = subprocess.run(cmd, capture_output=True, text=True)
    return float(result.stdout.strip())

audio_duration = get_audio_duration(audio_file)
print(f"Found {len(images)} images.")
print(f"Audio duration: {audio_duration:.2f}s")
print(f"Output dir: {out_dir}")
sys.stdout.flush()


def find_newest_mp4(directory, after_time):
    """Return the newest UUID-named .mp4 created after `after_time`, or None."""
    candidates = []
    for f in os.listdir(directory):
        if not f.endswith(".mp4"):
            continue
        if "_part" in f or "_final" in f:
            continue
        full = os.path.join(directory, f)
        ct = os.path.getctime(full)
        if ct > after_time:
            candidates.append((ct, full))
    if not candidates:
        return None
    candidates.sort(reverse=True)  # newest first
    return candidates[0][1]


def run_i2v(image_path, label):
    """Run gflow video i2v once and return the saved .mp4 path, or None."""
    t0 = time.time()
    cmd = [
        "uv", "run", "gflow", "video", "i2v",
        "--initial-frame", image_path,
        prompt,
        "--model", model,
        "--duration", "8",
        "--count", "1",
        "--project", project_id,
        "--collection", collection_id,
        "--out-dir", out_dir,
        "--json",
    ]
    print(f"  [{label}] running gflow i2v...", flush=True)
    res = subprocess.run(cmd, capture_output=True, text=True)
    time.sleep(0.5)

    mp4 = find_newest_mp4(out_dir, t0)
    if mp4:
        print(f"  [{label}] saved: {mp4}", flush=True)
    else:
        print(f"  [{label}] FAILED — no mp4 found", flush=True)
        # Show last 300 chars of stdout/stderr for debugging
        print(f"    stdout tail: {res.stdout[-300:]}", flush=True)
        print(f"    stderr tail: {res.stderr[-300:]}", flush=True)
    return mp4


total = len(images)
done = 0
skipped = 0
failed = 0

for idx, img in enumerate(images, 1):
    base_name = os.path.splitext(os.path.basename(img))[0]
    final_path = os.path.join(out_dir, f"{base_name}_final.mp4")

    if os.path.exists(final_path):
        skipped += 1
        print(f"\n[{idx}/{total}] {base_name} — already exists, skipping.", flush=True)
        continue

    print(f"\n[{idx}/{total}] {base_name}", flush=True)

    # Part 1
    vid1 = run_i2v(img, "part1")
    if not vid1:
        failed += 1
        print(f"  Skipping {base_name} (part1 failed).", flush=True)
        continue

    # Rename immediately so part2 won't confuse it
    part1_path = os.path.join(out_dir, f"{base_name}_part1.mp4")
    os.replace(vid1, part1_path)

    # Part 2
    vid2 = run_i2v(img, "part2")
    if not vid2:
        failed += 1
        print(f"  Skipping {base_name} (part2 failed). Keeping part1.", flush=True)
        continue

    part2_path = os.path.join(out_dir, f"{base_name}_part2.mp4")
    os.replace(vid2, part2_path)

    # Concat + audio
    concat_txt = os.path.join(out_dir, f"{base_name}_concat.txt")
    with open(concat_txt, "w") as f:
        f.write(f"file '{part1_path.replace(chr(92), '/')}'\n")
        f.write(f"file '{part2_path.replace(chr(92), '/')}'\n")

    print(f"  Concatenating + adding audio...", flush=True)
    subprocess.run([
        "ffmpeg", "-y",
        "-f", "concat", "-safe", "0", "-i", concat_txt,
        "-i", audio_file,
        "-c:v", "copy", "-c:a", "aac",
        "-map", "0:v:0", "-map", "1:a:0",
        "-t", str(audio_duration),
        final_path,
    ], capture_output=True)

    # Cleanup intermediaries
    for tmp in (part1_path, part2_path, concat_txt):
        try:
            os.remove(tmp)
        except OSError:
            pass

    done += 1
    print(f"  DONE: {final_path}", flush=True)

print(f"\n=== Batch complete: {done} created, {skipped} skipped, {failed} failed ===", flush=True)