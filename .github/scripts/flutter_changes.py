"""Detect Flutter inputs without skipping the workflow's required status check."""

import json
import os
from pathlib import Path
import subprocess


def git(*args):
    return subprocess.check_output(["git", *args])


def is_flutter_path(path):
    return (
        path.endswith((".dart", ".arb"))
        or path in {"pubspec.yaml", "pubspec.lock", "analysis_options.yaml",
                    "build.yaml", "l10n.yaml", ".metadata"}
        or path.startswith(("assets/", "fonts/", "android/", "ios/", ".github/"))
    )


def flutter_changed(event):
    if "pull_request" in event:
        base = event["pull_request"]["base"]["sha"]
        head = event["pull_request"]["head"]["sha"]
        base = git("merge-base", base, head).decode().strip()
    else:
        base, head = event["before"], event["after"]
        # A first push or unavailable old history must run the full checks.
        if not base.strip("0"):
            return True
        if subprocess.run(["git", "cat-file", "-e", base],
                          stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode:
            return True
    # Include both paths of renames so moving code out of a watched directory counts.
    paths = git("diff", "--name-only", "--no-renames", "-z", base, head).split(b"\0")
    return any(is_flutter_path(os.fsdecode(path)) for path in paths if path)


if __name__ == "__main__":
    event = json.loads(Path(os.environ["GITHUB_EVENT_PATH"]).read_text())
    changed = str(flutter_changed(event)).lower()
    with open(os.environ["GITHUB_OUTPUT"], "a") as output:
        output.write(f"flutter={changed}\n")
    print(f"Flutter-related changes: {changed}")
