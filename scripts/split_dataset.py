"""Split dataset/<class>/*.jpg into dataset_split/{train,val,test}/<class>/ (70/15/15).

Run BEFORE any augmentation.  Near-duplicate photos (burst shots of the same view) must be
grouped manually first - a random split cannot know they are near-identical, and
leakage between train and test makes accuracy look better than it really is.

PowerShell, from the repository root:
    python scripts\split_dataset.py --src dataset --dst dataset_split
"""
import argparse
import random
import shutil
from pathlib import Path

CLASSES = ["stone_chariot", "vittala_temple", "lotus_mahal", "other"]
EXTS = {".jpg", ".jpeg", ".png", ".webp"}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", default="dataset")
    ap.add_argument("--dst", default="dataset_split")
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--val", type=float, default=0.15)
    ap.add_argument("--test", type=float, default=0.15)
    args = ap.parse_args()

    rng = random.Random(args.seed)
    src, dst = Path(args.src), Path(args.dst)
    if dst.exists():
        raise SystemExit(f"{dst} already exists - delete it first to avoid mixing old and new splits.")
    for cls in CLASSES:
        files = sorted(p for p in (src / cls).glob("*") if p.suffix.lower() in EXTS)
        if len(files) < 10:
            print(f"WARNING: only {len(files)} images in {src / cls} - collect more before training.")
        rng.shuffle(files)
        n_val, n_test = int(len(files) * args.val), int(len(files) * args.test)
        parts = {"test": files[:n_test], "val": files[n_test:n_test + n_val], "train": files[n_test + n_val:]}
        for split, items in parts.items():
            out = dst / split / cls
            out.mkdir(parents=True, exist_ok=True)
            for f in items:
                shutil.copy2(f, out / f.name)
        print(f"{cls}: train={len(parts['train'])} val={len(parts['val'])} test={len(parts['test'])}")


if __name__ == "__main__":
    main()
