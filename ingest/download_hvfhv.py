#!/usr/bin/env python3
"""
Download NYC TLC High Volume For-Hire Vehicle trip data and the taxi
zone lookup table into data/raw/.

Usage:
    python ingest/download_hvfhv.py 2025-03
    python ingest/download_hvfhv.py 2025-01 2025-02 2025-03
    python ingest/download_hvfhv.py 2025-03 --force   # re-download even if the file exists

Idempotent by default: skips a month if its parquet file already exists on
disk, so re-running this script is always safe and won't silently
re-download ~500MB files you already have. This matters once this script
is called from Dagster later -- a scheduled/retried run shouldn't
re-fetch data it already has.
"""
import argparse
import time
from pathlib import Path

import requests

REPO_ROOT = Path(__file__).resolve().parent.parent
DATA_RAW = REPO_ROOT / "data" / "raw"

TRIP_DATA_URL = "https://d37ci6vzurychx.cloudfront.net/trip-data/fhvhv_tripdata_{year_month}.parquet"
ZONE_LOOKUP_URL = "https://d37ci6vzurychx.cloudfront.net/misc/taxi_zone_lookup.csv"

MAX_RETRIES = 3
RETRY_BACKOFF_SECONDS = 5


def download_with_retries(url: str, dest: Path) -> None:
    """Stream a URL to disk, retrying transient failures with a growing
    backoff. Writes to a .partial file first and only renames to the
    final name on success -- so a failed/interrupted download never
    leaves a file that LOOKS complete but isn't (which would otherwise
    make the "skip if it exists" idempotency check silently trust a
    corrupt file)."""
    last_error = None
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            with requests.get(url, stream=True, timeout=60) as resp:
                resp.raise_for_status()
                tmp_dest = dest.with_suffix(dest.suffix + ".partial")
                total_bytes = 0
                with open(tmp_dest, "wb") as f:
                    for chunk in resp.iter_content(chunk_size=8 * 1024 * 1024):
                        f.write(chunk)
                        total_bytes += len(chunk)
                tmp_dest.rename(dest)
                print(f"  downloaded {dest.name} ({total_bytes / 1e6:.1f} MB)")
                return
        except requests.exceptions.RequestException as e:
            last_error = e
            print(f"  attempt {attempt}/{MAX_RETRIES} failed: {e}")
            if attempt < MAX_RETRIES:
                time.sleep(RETRY_BACKOFF_SECONDS * attempt)
    raise RuntimeError(f"Failed to download {url} after {MAX_RETRIES} attempts") from last_error


def download_month(year_month: str, force: bool = False) -> None:
    """year_month like '2025-03'."""
    dest = DATA_RAW / f"fhvhv_{year_month}.parquet"
    if dest.exists() and not force:
        print(f"{dest.name} already exists, skipping (use --force to re-download)")
        return
    url = TRIP_DATA_URL.format(year_month=year_month)
    print(f"downloading {url}")
    download_with_retries(url, dest)


def download_zone_lookup(force: bool = False) -> None:
    dest = DATA_RAW / "taxi_zone_lookup.csv"
    if dest.exists() and not force:
        print(f"{dest.name} already exists, skipping (use --force to re-download)")
        return
    print(f"downloading {ZONE_LOOKUP_URL}")
    download_with_retries(ZONE_LOOKUP_URL, dest)


def main():
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter
    )
    parser.add_argument(
        "year_months", nargs="+", help="one or more YYYY-MM months to download, e.g. 2025-03"
    )
    parser.add_argument(
        "--force", action="store_true", help="re-download even if the file already exists"
    )
    args = parser.parse_args()

    DATA_RAW.mkdir(parents=True, exist_ok=True)

    download_zone_lookup(force=args.force)
    for ym in args.year_months:
        download_month(ym, force=args.force)


if __name__ == "__main__":
    main()
