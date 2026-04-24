import argparse
import json
import os
from pathlib import Path

import requests


DEFAULT_SUPABASE_URL = "https://trhwelbdnhhpldpkrxmp.supabase.co"
DEFAULT_TABLE = "APIReviewList"
BATCH_SIZE = 500
BLOGGER_NAME_COLUMN = "reivew_bloggername\u200b"
POSTDATE_COLUMN = "reivew_postdate\u200b"


def restaurant_name_from_path(path: Path) -> str:
    name = path.stem
    if name.startswith("reviews_"):
        name = name[len("reviews_") :]
    return name


def load_rows(data_dir: Path) -> list[dict]:
    rows = []
    for path in sorted(data_dir.glob("reviews_*.json")):
        restaurant_name = restaurant_name_from_path(path)
        with path.open("r", encoding="utf-8") as file:
            reviews = json.load(file)

        if not isinstance(reviews, list):
            raise ValueError(f"{path} must contain a JSON array")

        for review in reviews:
            if not isinstance(review, dict):
                raise ValueError(f"{path} contains a non-object review item")

            rows.append(
                {
                    "name": restaurant_name,
                    "review_url": review.get("url"),
                    "review_title": review.get("title"),
                    "review_description": review.get("description"),
                    BLOGGER_NAME_COLUMN: review.get("bloggername"),
                    POSTDATE_COLUMN: review.get("postdate"),
                }
            )

    return rows


def chunks(items: list[dict], size: int):
    for start in range(0, len(items), size):
        yield items[start : start + size]


def upload_rows(
    rows: list[dict],
    supabase_url: str,
    supabase_key: str,
    table: str,
    dry_run: bool,
) -> None:
    endpoint = f"{supabase_url.rstrip('/')}/rest/v1/{table}"
    headers = {
        "apikey": supabase_key,
        "Authorization": f"Bearer {supabase_key}",
        "Content-Type": "application/json",
        "Prefer": "return=minimal",
    }

    if dry_run:
        print(f"Dry run: {len(rows)} rows prepared for {table}")
        return

    uploaded = 0
    for batch in chunks(rows, BATCH_SIZE):
        response = requests.post(endpoint, headers=headers, json=batch, timeout=60)
        if not response.ok:
            raise RuntimeError(
                f"Upload failed after {uploaded} rows: "
                f"{response.status_code} {response.text}"
            )
        uploaded += len(batch)
        print(f"Uploaded {uploaded}/{len(rows)} rows")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Upload Naver review JSON files to Supabase APIReviewList."
    )
    parser.add_argument(
        "--data-dir",
        default=Path(__file__).resolve().parent,
        type=Path,
        help="Directory containing reviews_*.json files.",
    )
    parser.add_argument("--supabase-url", default=DEFAULT_SUPABASE_URL)
    parser.add_argument("--table", default=DEFAULT_TABLE)
    parser.add_argument(
        "--key",
        default=os.getenv("SUPABASE_SERVICE_ROLE_KEY")
        or os.getenv("SUPABASE_ANON_KEY")
        or os.getenv("SUPABASE_KEY"),
        help="Supabase service role key, or anon key if inserts are allowed.",
    )
    parser.add_argument("--dry-run", action="store_true")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    if not args.key and not args.dry_run:
        raise SystemExit(
            "Missing Supabase key. Set SUPABASE_SERVICE_ROLE_KEY, "
            "SUPABASE_ANON_KEY, or pass --key."
        )

    rows = load_rows(args.data_dir)
    upload_rows(
        rows=rows,
        supabase_url=args.supabase_url,
        supabase_key=args.key,
        table=args.table,
        dry_run=args.dry_run,
    )


if __name__ == "__main__":
    main()
