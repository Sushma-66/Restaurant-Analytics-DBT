"""
Generate synthetic raw data for the Hoshi Kitchen restaurant group.

Simulates the CSV exports a POS (point of sale) and a loyalty/CRM platform
drop into a landing zone each night. The data is deliberately *messy* in the
same ways real exports are, so the staging layer has real work to do:

  * mixed-case / padded text ("  Card ", "CASH")
  * money stored as strings with a currency symbol ("£12.50")
  * duplicated rows from re-exported files (same order_id, later _loaded_at)
  * voided orders and refunds
  * menu price changes over time (drives the SCD2 snapshot)
  * members who sign up but never order

Usage:
    python scripts/generate_raw_data.py                  # default: data/raw
    python scripts/generate_raw_data.py --out data/raw --seed 42 --end 2026-09-30

Deterministic for a given --seed so CI runs are reproducible.
"""

from __future__ import annotations

import argparse
from datetime import date, datetime, timedelta
from pathlib import Path

import numpy as np
import pandas as pd

BRANCHES = [
    # branch_code, name, city, opened_on, seats, size multiplier
    ("SOK", "Selly Oak", "Birmingham", "2021-03-12", 60, 1.00),
    ("NST", "New Street", "Birmingham", "2022-07-01", 85, 1.35),
    ("SOL", "Solihull", "Solihull", "2023-05-19", 55, 0.80),
    ("BRS", "Bristol", "Bristol", "2024-09-06", 70, 1.10),
    ("LEI", "Leicester", "Leicester", "2025-11-14", 50, 0.70),
]

MENU = [
    # sku, name, category, price, cost ratio, popularity weight
    ("SUS-001", "Salmon Nigiri (2pc)", "Sushi", 5.50, 0.38, 9),
    ("SUS-002", "Tuna Nigiri (2pc)", "Sushi", 6.20, 0.42, 6),
    ("SUS-003", "California Roll (8pc)", "Sushi", 8.90, 0.30, 10),
    ("SUS-004", "Dragon Roll (8pc)", "Sushi", 12.50, 0.33, 7),
    ("SUS-005", "Vegetable Maki (6pc)", "Sushi", 5.90, 0.22, 5),
    ("SUS-006", "Sashimi Platter", "Sushi", 18.90, 0.45, 3),
    ("RAM-001", "Tonkotsu Ramen", "Ramen", 13.50, 0.28, 9),
    ("RAM-002", "Chicken Shoyu Ramen", "Ramen", 12.90, 0.26, 8),
    ("RAM-003", "Spicy Miso Ramen", "Ramen", 13.20, 0.27, 6),
    ("RAM-004", "Vegan Ramen", "Ramen", 12.50, 0.24, 4),
    ("KAT-001", "Chicken Katsu Curry", "Mains", 13.90, 0.27, 11),
    ("KAT-002", "Pumpkin Katsu Curry", "Mains", 12.50, 0.22, 4),
    ("TER-001", "Chicken Teriyaki Don", "Mains", 12.90, 0.29, 7),
    ("TER-002", "Salmon Teriyaki Don", "Mains", 15.50, 0.40, 5),
    ("SID-001", "Edamame", "Sides", 4.50, 0.18, 9),
    ("SID-002", "Chicken Gyoza (5pc)", "Sides", 6.50, 0.25, 10),
    ("SID-003", "Prawn Tempura", "Sides", 7.90, 0.35, 6),
    ("SID-004", "Chicken Karaage", "Sides", 6.90, 0.26, 8),
    ("DES-001", "Mochi Ice Cream (3pc)", "Desserts", 5.90, 0.30, 4),
    ("DES-002", "Matcha Cheesecake", "Desserts", 6.50, 0.28, 2),
    ("DRK-001", "Asahi Draught", "Drinks", 5.80, 0.30, 7),
    ("DRK-002", "Ramune", "Drinks", 3.50, 0.35, 5),
    ("DRK-003", "Green Tea (pot)", "Drinks", 3.20, 0.10, 5),
    ("DRK-004", "Soft Drink", "Drinks", 2.90, 0.15, 8),
]

CHANNELS = ["dine_in", "takeaway", "delivery_deliveroo", "delivery_ubereats"]
CHANNEL_P = [0.58, 0.14, 0.16, 0.12]

PAYMENT_LABELS = {  # deliberately inconsistent raw labels
    "card": ["Card", "CARD", " card ", "Credit/Debit Card"],
    "cash": ["Cash", "CASH", "cash "],
    "gift_card": ["Gift Card", "GIFTCARD"],
    "third_party": ["Deliveroo", "Uber Eats", "UberEats"],
}

FIRST_NAMES = [
    "Aisha", "Ben", "Chloe", "Daniel", "Emily", "Farhan", "Grace", "Harry",
    "Imran", "Jess", "Kiran", "Liam", "Maya", "Noah", "Olivia", "Priya",
    "Rohan", "Sophie", "Tom", "Uma", "Victor", "Wei", "Yusuf", "Zara",
]
LAST_NAMES = [
    "Ahmed", "Brown", "Chen", "Davies", "Evans", "Khan", "Patel", "Smith",
    "Jones", "Taylor", "Wilson", "Singh", "Hughes", "Walker", "Ali", "Nguyen",
]

PROMOTIONS = [
    # promo_code, name, discount pct, applies_to_category, start, end, member_only
    ("SUSHICLUB50", "Sushi Club 50% off sushi", 0.50, "Sushi", "2025-06-01", "2026-12-31", True),
    ("STUDENT20", "Student 20% off food", 0.20, None, "2025-01-01", "2026-12-31", False),
    ("JANUARY15", "January 15% off", 0.15, None, "2026-01-02", "2026-01-31", False),
]


def money(x: float) -> str:
    """Render money the way the POS export does: '£12.50'."""
    return f"£{x:,.2f}"


def build_menu_history(rng: np.random.Generator, start: date, end: date) -> pd.DataFrame:
    """Each item gets 0-2 price rises; the export is a full daily snapshot of current prices,
    but we only ship the latest state plus an `updated_at` - the snapshot captures history."""
    rows = []
    for sku, name, cat, price, cost_ratio, _ in MENU:
        n_changes = rng.integers(0, 3)
        change_days = sorted(rng.integers(60, (end - start).days, size=n_changes))
        p, updated = price, datetime.combine(start, datetime.min.time())
        history = [(p, updated)]
        for d in change_days:
            p = round(p * (1 + rng.uniform(0.04, 0.10)) * 10) / 10  # price rises to nearest 10p
            updated = datetime.combine(start + timedelta(days=int(d)), datetime.min.time()) + timedelta(hours=6)
            history.append((p, updated))
        for price_v, updated_v in history:
            rows.append(
                {
                    "sku": sku,
                    "item_name": name,
                    "category": cat,
                    "price": price_v,
                    "unit_cost": round(price_v * cost_ratio, 2),
                    "is_active": True,
                    "updated_at": updated_v,
                }
            )
    return pd.DataFrame(rows)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="data/raw")
    ap.add_argument("--seed", type=int, default=42)
    ap.add_argument("--start", default="2025-01-01")
    ap.add_argument("--end", default="2026-09-30")
    ap.add_argument("--members", type=int, default=12000)
    args = ap.parse_args()

    rng = np.random.default_rng(args.seed)
    out = Path(args.out)
    out.mkdir(parents=True, exist_ok=True)
    start, end = date.fromisoformat(args.start), date.fromisoformat(args.end)

    # ---------------- menu ----------------
    menu_hist = build_menu_history(rng, start, end)
    menu_hist["updated_at"] = pd.to_datetime(menu_hist["updated_at"])
    # Pre-compute a fast lookup: per sku, sorted change timestamps + prices
    price_lookup = {
        sku: (g.updated_at.values, g.price.values, g.unit_cost.values)
        for sku, g in menu_hist.sort_values("updated_at").groupby("sku")
    }

    # ---------------- members ----------------
    n_mem = args.members
    signup_offsets = rng.integers(0, (end - start).days, size=n_mem)
    members = pd.DataFrame(
        {
            "member_id": [f"M{100000 + i}" for i in range(n_mem)],
            "first_name": rng.choice(FIRST_NAMES, n_mem),
            "last_name": rng.choice(LAST_NAMES, n_mem),
            "home_branch": rng.choice([b[0] for b in BRANCHES], n_mem, p=[0.28, 0.32, 0.16, 0.16, 0.08]),
            "signed_up_at": [
                datetime.combine(start + timedelta(days=int(d)), datetime.min.time())
                + timedelta(minutes=int(rng.integers(600, 1320)))
                for d in signup_offsets
            ],
            "marketing_opt_in": rng.choice(["Y", "N", "y", "", "Yes"], n_mem, p=[0.45, 0.30, 0.05, 0.12, 0.08]),
            "is_sushi_club": rng.random(n_mem) < 0.35,
        }
    )
    members["email"] = (
        members.first_name.str.lower() + "." + members.last_name.str.lower()
        + members.member_id.str[-4:] + "@example.com"
    )
    # Not every branch existed at sign-up time: re-home those to Selly Oak
    opened = {b[0]: pd.Timestamp(b[3]) for b in BRANCHES}
    bad = members.apply(lambda r: r.signed_up_at < opened[r.home_branch], axis=1)
    members.loc[bad, "home_branch"] = "SOK"
    # ~25% of members are "dormant" and never order; others have an engagement rate
    engagement = rng.gamma(1.2, 1.0, n_mem) * (rng.random(n_mem) > 0.25)
    member_ids = members.member_id.values

    # ---------------- orders ----------------
    order_rows, item_rows, pay_rows = [], [], []
    order_seq = 1
    n_days = (end - start).days + 1
    sku_arr = np.array([m[0] for m in MENU])
    sku_cat = {m[0]: m[2] for m in MENU}
    weights = np.array([m[5] for m in MENU], dtype=float)
    weights /= weights.sum()
    mem_p = engagement / engagement.sum()

    for day_i in range(n_days):
        d = start + timedelta(days=day_i)
        dow_mult = [0.75, 0.80, 0.85, 0.95, 1.30, 1.45, 1.10][d.weekday()]
        season = 1 + 0.12 * np.sin((d.timetuple().tm_yday / 365) * 2 * np.pi - 1.2)
        trend = 1 + 0.15 * day_i / n_days
        for code, _, _, opened_on, _, size in BRANCHES:
            if d < date.fromisoformat(opened_on):
                continue
            n_orders = rng.poisson(38 * size * dow_mult * season * trend)
            for _ in range(n_orders):
                hour = rng.choice([12, 13, 14, 17, 18, 19, 20, 21], p=[0.12, 0.14, 0.06, 0.08, 0.18, 0.2, 0.15, 0.07])
                ts = datetime.combine(d, datetime.min.time()) + timedelta(hours=int(hour), minutes=int(rng.integers(0, 60)))
                channel = rng.choice(CHANNELS, p=CHANNEL_P)
                is_member = channel in ("dine_in", "takeaway") and rng.random() < 0.32
                member_id = rng.choice(member_ids, p=mem_p) if is_member else None
                covers = int(rng.choice([1, 2, 2, 3, 4, 5])) if channel == "dine_in" else 1
                n_items = max(1, rng.poisson(1.6 * covers + 0.5))
                order_id = f"{code}-{order_seq:08d}"
                order_seq += 1

                # promo choice
                promo = None
                if member_id is not None and d >= date(2025, 6, 1) and rng.random() < 0.45:
                    promo = "SUSHICLUB50"
                elif rng.random() < 0.05:
                    promo = "STUDENT20"
                elif date(2026, 1, 2) <= d <= date(2026, 1, 31) and rng.random() < 0.25:
                    promo = "JANUARY15"

                skus = rng.choice(sku_arr, size=n_items, p=weights)
                if promo == "SUSHICLUB50":  # club members over-index on sushi when it's half price
                    skus = np.where(rng.random(n_items) < 0.5, rng.choice(sku_arr[:6], n_items), skus)

                gross = disc = 0.0
                for line_no, sku in enumerate(skus, start=1):
                    times, prices, costs = price_lookup[sku]
                    idx = np.searchsorted(times, np.datetime64(ts), side="right") - 1
                    unit_price, unit_cost = float(prices[idx]), float(costs[idx])
                    qty = int(rng.choice([1, 1, 1, 2]))
                    line_gross = round(unit_price * qty, 2)
                    line_disc = 0.0
                    if promo == "SUSHICLUB50" and sku_cat[sku] == "Sushi":
                        line_disc = round(line_gross * 0.5, 2)
                    elif promo == "STUDENT20" and sku_cat[sku] != "Drinks":
                        line_disc = round(line_gross * 0.2, 2)
                    elif promo == "JANUARY15":
                        line_disc = round(line_gross * 0.15, 2)
                    gross += line_gross
                    disc += line_disc
                    item_rows.append(
                        {
                            "order_id": order_id,
                            "line_number": line_no,
                            "sku": sku,
                            "quantity": qty,
                            "unit_price": money(unit_price),
                            "line_discount": money(line_disc),
                            "unit_cost": unit_cost,
                        }
                    )

                service = round((gross - disc) * 0.10, 2) if channel == "dine_in" and covers >= 4 else 0.0
                total = round(gross - disc + service, 2)
                status = rng.choice(["completed", "voided", "refunded"], p=[0.975, 0.017, 0.008])
                loaded_at = datetime.combine(d + timedelta(days=1), datetime.min.time()) + timedelta(hours=2, minutes=5)
                order_rows.append(
                    {
                        "order_id": order_id,
                        "branch_code": code.lower() if rng.random() < 0.03 else code,  # case drift
                        "ordered_at": ts.strftime("%Y-%m-%d %H:%M:%S"),
                        "channel": channel,
                        "covers": covers,
                        "member_id": member_id,
                        "promo_code": promo,
                        "gross_amount": money(gross),
                        "discount_amount": money(disc),
                        "service_charge": money(service),
                        "total_amount": money(total),
                        "order_status": status.upper() if rng.random() < 0.1 else status,
                        "_loaded_at": loaded_at.strftime("%Y-%m-%d %H:%M:%S"),
                    }
                )

                if status != "voided":
                    if channel.startswith("delivery"):
                        methods = ["third_party"]
                    elif rng.random() < 0.08:
                        methods = ["card", "cash"]  # split bill
                    else:
                        methods = [rng.choice(["card", "cash", "gift_card"], p=[0.86, 0.10, 0.04])]
                    remaining = total
                    for i, m in enumerate(methods):
                        amt = remaining if i == len(methods) - 1 else round(total * rng.uniform(0.3, 0.7), 2)
                        remaining = round(remaining - amt, 2)
                        label = rng.choice(PAYMENT_LABELS[m])
                        if m == "third_party":
                            label = "Deliveroo" if channel == "delivery_deliveroo" else rng.choice(["Uber Eats", "UberEats"])
                        pay_rows.append(
                            {
                                "payment_id": f"P{len(pay_rows) + 1:09d}",
                                "order_id": order_id,
                                "payment_method": label,
                                "amount": money(amt),
                                "tip_amount": money(round(amt * rng.choice([0, 0, 0, 0.05, 0.1]), 2)) if m == "card" else money(0),
                                "paid_at": (ts + timedelta(minutes=int(rng.integers(20, 90)))).strftime("%Y-%m-%d %H:%M:%S"),
                            }
                        )

    orders = pd.DataFrame(order_rows)
    items = pd.DataFrame(item_rows)
    payments = pd.DataFrame(pay_rows)

    # Till discrepancies: a small share of cash tenders are recorded short,
    # so the reconciliation mart has something real to find.
    cash_idx = payments.index[payments.payment_method.str.strip().str.lower() == "cash"]
    short = rng.choice(cash_idx, size=int(len(cash_idx) * 0.004), replace=False)
    for i in short:
        amt = float(payments.at[i, "amount"].replace("£", "").replace(",", ""))
        payments.at[i, "amount"] = money(max(0.0, round(amt - rng.choice([0.5, 1, 2, 5, 10]), 2)))

    # Re-exported files: ~0.5% of orders appear twice with a later _loaded_at
    dupes = orders.sample(frac=0.005, random_state=args.seed).copy()
    dupes["_loaded_at"] = (pd.to_datetime(dupes["_loaded_at"]) + pd.Timedelta(hours=24)).dt.strftime("%Y-%m-%d %H:%M:%S")
    orders = pd.concat([orders, dupes]).sample(frac=1, random_state=args.seed).reset_index(drop=True)

    # Menu export = current state only (latest row per sku); history is rebuilt by the snapshot
    menu_current = menu_hist.sort_values("updated_at").groupby("sku").tail(1).copy()
    menu_current["price"] = menu_current["price"].map(money)
    menu_current["updated_at"] = menu_current["updated_at"].dt.strftime("%Y-%m-%d %H:%M:%S")
    items = items.drop(columns=["unit_cost"])

    promos = pd.DataFrame(
        PROMOTIONS,
        columns=["promo_code", "promo_name", "discount_pct", "applies_to_category", "valid_from", "valid_to", "is_member_only"],
    )

    members["signed_up_at"] = members["signed_up_at"].dt.strftime("%Y-%m-%d %H:%M:%S")
    members = members[[
        "member_id", "first_name", "last_name", "email", "home_branch",
        "signed_up_at", "marketing_opt_in", "is_sushi_club",
    ]]

    files = {
        "pos_orders.csv": orders,
        "pos_order_items.csv": items,
        "pos_payments.csv": payments,
        "pos_menu_items.csv": menu_current[["sku", "item_name", "category", "price", "unit_cost", "is_active", "updated_at"]],
        "crm_members.csv": members,
        "crm_promotions.csv": promos,
    }
    for name, df in files.items():
        df.to_csv(out / name, index=False)
        print(f"  wrote {name:<24} {len(df):>9,} rows")



if __name__ == "__main__":
    main()
