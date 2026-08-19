import argparse
import json
import pathlib
import subprocess
import sys

def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--prompt-file", required=True)
    parser.add_argument("--initial-frame", required=True)
    parser.add_argument("--project", required=True)
    
    args = parser.parse_args()

    prompt_path = pathlib.Path(args.prompt_file)
    prompt = prompt_path.read_text(encoding="utf-8").strip()

    cmd = [
        "gflow", "video", "i2v",
        "--initial-frame", args.initial_frame,
        "--model", "veo-lite-lp",
        "--duration", "8",
        "--aspect", "9:16",
        "--project", args.project,
        "--json",
        "--",
        prompt,
    ]

    result = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8")
    
    if result.returncode != 0:
        if result.stderr:
            print(result.stderr, file=sys.stderr, end="")
        if result.stdout:
            print(result.stdout, file=sys.stderr, end="")
        sys.exit(result.returncode)

    for line in result.stdout.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            data = json.loads(line)
            if "media_id" in data and data.get("succeeded"):
                print(data["media_id"])
                sys.exit(0)
        except json.JSONDecodeError:
            continue
            
    print("media_id not found in output", file=sys.stderr)
    sys.exit(1)

if __name__ == "__main__":
    main()
