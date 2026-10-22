"""
Simulate tonight's menu export containing price rises, to demo the SCD2 snapshot.

    python scripts/simulate_menu_price_change.py --skus RAM-001 SID-002 --pct 5
    dbt snapshot
    # snap_menu_items now holds the old row (closed) and the new row (current)
"""

from __future__ import annotations

import argparse
from datetime import datetime
from pathlib import Path

import pandas as pd


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--file", default="data/raw/pos_menu_items.csv")
    ap.add_argument("--skus", nargs="+", default=["RAM-001", "SID-002"])
    ap.add_argument("--pct", type=float, default=5.0, help="price rise in percent")
    args = ap.parse_args()

    path = Path(args.file)
    df = pd.read_csv(path, dtype=str)
    now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    for sku in args.skus:
        mask = df.sku == sku
        if not mask.any():
            print(f"  ! {sku} not found, skipped")
            continue
        old = float(df.loc[mask, "price"].iloc[0].replace("£", ""))
        new = round(old * (1 + args.pct / 100), 2)
        ratio = float(df.loc[mask, "unit_cost"].iloc[0]) / old
        df.loc[mask, "price"] = f"£{new:.2f}"
        df.loc[mask, "unit_cost"] = f"{new * ratio:.2f}"
        df.loc[mask, "updated_at"] = now
        print(f"  {sku}: £{old:.2f} -> £{new:.2f}")
    df.to_csv(path, index=False)


if __name__ == "__main__":
    main()
