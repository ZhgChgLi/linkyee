#!/usr/bin/env python3
"""Create review-only proposed updates from main, preserving website-owned files."""
import os
from pathlib import Path
import subprocess
import sys

BRANCH = "sync/main-to-website"
FILES = {"config.yml", "scaffold.rb", "deploy.sh", "CNAME"}
DIRS = (".github/", "locales/", "themes/glassmorphism/", "images/", "plugins/")

def git(*args, check=True):
    return subprocess.run(["git", *args], text=True, capture_output=True, check=check)

def excluded(path):
    return path in FILES or path.startswith(DIRS)

def output(name, value):
    if os.environ.get("GITHUB_OUTPUT"):
        with open(os.environ["GITHUB_OUTPUT"], "a", encoding="utf-8") as out:
            out.write(f"{name}={value}\n")

def main():
    git("fetch", "origin", "main", "website", "--prune")
    # Fetch the current proposal head so a later force-with-lease push can
    # safely refresh an existing PR without clobbering unexpected commits.
    probe = git("ls-remote", "--exit-code", "--heads", "origin", BRANCH, check=False)
    if probe.returncode == 0:
        git("fetch", "origin", f"refs/heads/{BRANCH}:refs/remotes/origin/{BRANCH}")
    elif probe.returncode != 2:
        raise RuntimeError("Unable to check existing sync branch")
    ancestor = git("merge-base", "origin/main", "origin/website").stdout.strip()
    if not ancestor:
        raise RuntimeError("main and website have no common ancestor")
    entries = subprocess.check_output([
        "git", "diff", "--no-renames", "--name-status", "-z",
        f"{ancestor}..origin/main"
    ]).decode("utf-8").split("\0")
    if entries[-1] == "":
        entries.pop()
    safe, skipped = [], []
    for i in range(0, len(entries), 2):
        status, path = entries[i:i+2]
        # Never overwrite a path separately customized on website, even if
        # it isn't on the explicit protected-path list.
        website_changed = git(
            "diff", "--quiet", ancestor, "origin/website", "--", path,
            check=False
        )
        if website_changed.returncode not in (0, 1):
            raise RuntimeError("Unable to inspect website changes: " + path)
        if excluded(path) or website_changed.returncode == 1:
            skipped.append(path)
        else:
            safe.append((status, path))
    git("switch", "-c", BRANCH, "origin/website")
    for status, path in safe:
        if status == "D":
            git("rm", "-f", "--ignore-unmatch", "--", path)
        else:
            git("restore", "--source=origin/main", "--staged", "--worktree", "--", path)
        if status != "D":
            git("add", "-A", "--", path)
    result = git("diff", "--cached", "--quiet", check=False)
    if result.returncode not in (0, 1):
        raise RuntimeError("Unable to inspect staged changes")
    summary = Path(os.environ.get("GITHUB_STEP_SUMMARY", "/tmp/sync-summary.md"))
    with summary.open("a", encoding="utf-8") as f:
        f.write("## Review-only main to website update\n\n")
        f.write("Protected upstream changes excluded:\n")
        f.write("\n".join("- " + p for p in skipped) if skipped else "- none")
        f.write("\n")
    if result.returncode == 0:
        output("changes", "false")
        print("No safe file differences to propose; website is unchanged.")
        return
    git("config", "user.name", "github-actions[bot]")
    git("config", "user.email", "41898282+github-actions[bot]@users.noreply.github.com")
    git("commit", "-m", "chore: propose safe main updates for website")
    output("changes", "true")
    details = [
        "## Review-only upstream update",
        "Contains non-protected changes from main, applied to website.",
        "No automatic merge or production deployment will occur.",
        "",
        "### Proposed files",
        *("- " + path for _, path in safe),
        "",
        "### Protected upstream changes excluded",
        *(("- " + path for path in skipped) if skipped else ["- none"]),
        "",
        "### Review checklist",
        "- Check Files changed and build results.",
        "- Merge any excluded upstream fixes manually if needed.",
        "- Only merge when your personalized settings and theme remain correct.",
    ]
    Path("/tmp/linkyee-sync-pr.md").write_text("\n".join(details) + "\n", encoding="utf-8")

if __name__ == "__main__":
    try:
        main()
    except (subprocess.CalledProcessError, OSError, ValueError, RuntimeError) as exc:
        print("Update preparation failed: " + str(exc), file=sys.stderr)
        if isinstance(exc, subprocess.CalledProcessError):
            print(exc.stderr, file=sys.stderr)
        sys.exit(1)
