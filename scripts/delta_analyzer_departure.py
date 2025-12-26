import pandas as pd
import numpy as np
import pytz
import sys

# CSV Load
def load_data(pa_path, tb_path):
    pa = pd.read_csv(pa_path)
    tb = pd.read_csv(tb_path, encoding="utf-16", sep="\t")

    pa = pa.rename(columns={
        "departure_time": "departure_time_unix",
        "trip_id": "trip_id",
        "generated_time": "generated_time_unix",
        "predicted_departure": "predicted_departure_unix",
        "vehicle_label": "consist"
    })

    tb = tb.rename(columns={
        "Departure Time": "departure_time_dt",
        "Prediction Generated Time": "generated_time_dt",
        "Predicted Departure Time": "predicted_departure_dt",
        "Trip ID": "trip_id",
        "Predicted Vehicle Consist": "consist"
    })

    return pa, tb

# Normalize Keys
def normalize_keys(pa, tb):
    for df in [pa, tb]:
        df['trip_id'] = df['trip_id'].astype(str).str.strip()
        df['consist'] = df['consist'].astype(str).str.strip()
    return pa, tb

# Tableau preprocess
def preprocess_tableau(tb):
    eastern = pytz.timezone('America/New_York')
    for col in ['departure_time_dt', 'generated_time_dt', 'predicted_departure_dt']:
        tb = tb[pd.to_datetime(tb[col], errors='coerce').notnull()]
        tb[col] = pd.to_datetime(tb[col], errors='coerce')
        tb[col] = tb[col].dt.tz_localize(eastern, ambiguous='NaT').dt.tz_convert('UTC')

    tb['departure_time_unix'] = (tb['departure_time_dt'].view(np.int64) // 10**9).astype(int)
    tb['generated_time_unix'] = tb['generated_time_dt'].astype(np.int64) // 10**9
    tb['predicted_departure_unix'] = tb['predicted_departure_dt'].astype(np.int64) // 10**9

    return tb

# Match PA/Tableau; record mismatches
def match_rows_with_reasons(pa, tb, tolerance_dep=15, tolerance=60):
    pa['departure_time_unix'] = pd.to_numeric(pa['departure_time_unix'], errors='coerce')
    tb['departure_time_unix'] = pd.to_numeric(tb['departure_time_unix'], errors='coerce')
    tb['predicted_departure_unix'] = pd.to_numeric(tb['predicted_departure_unix'], errors='coerce')
    pa['predicted_departure_unix'] = pd.to_numeric(pa['predicted_departure_unix'], errors='coerce')

    eastern = pytz.timezone('America/New_York')
    unmatched_rows = []
    matched_rows = []

    for _, pa_row in pa.iterrows():
        if pd.isna(pa_row['departure_time_unix']):
            continue

        pa_dep = int(pa_row['departure_time_unix'])
        candidates = tb[
            (tb['departure_time_unix'] >= pa_dep - tolerance_dep) &
            (tb['departure_time_unix'] <= pa_dep + tolerance_dep)
        ]

        row_out = pa_row.copy()
        tableau_time_str = ''
        tableau_generated_time_str = ''

        if candidates.empty:
            mismatch_reason = "No Tableau row with departure_time within tolerance"
        else:
            gen_diff = (candidates['generated_time_unix'] - pa_row['generated_time_unix']).abs()
            pred_diff = (candidates['predicted_departure_unix'] - pa_row['predicted_departure_unix']).abs()

            valid = (gen_diff <= tolerance) & (pred_diff <= tolerance)

            if valid.any():
                matched_rows.append(row_out)
                continue
            else:
                reasons = []
                if not (gen_diff <= tolerance).any():
                    reasons.append("Generated time difference exceeds tolerance")
                if not (pred_diff <= tolerance).any():
                    reasons.append("Predicted departure time difference exceeds tolerance")
                mismatch_reason = "; ".join(reasons)

            # Pick first candidate departure time for reference
            if len(candidates['departure_time_unix']) > 0:
                dt_utc = pd.to_datetime(candidates['departure_time_unix'].iloc[0], unit='s', utc=True)
                tableau_time_str = dt_utc.tz_convert(eastern).strftime('%Y-%m-%d %H:%M:%S %Z')
                gen_dt_utc = pd.to_datetime(candidates['generated_time_unix'].iloc[0], unit='s', utc=True)
                tableau_generated_time_str = gen_dt_utc.tz_convert(eastern).strftime('%Y-%m-%d %H:%M:%S %Z')

        row_out['mismatch_reason'] = mismatch_reason
        row_out['tableau_departure_time'] = tableau_time_str
        row_out['tableau_generated_departure_time'] = tableau_generated_time_str
        row_out['pa_departure_dt'] = pd.to_datetime(pa_row['departure_time_unix'], unit='s', utc='True').tz_convert(eastern).strftime('%Y-%m-%d %H:%M:%S %Z')
        row_out['pa_generated_dt'] = pd.to_datetime(pa_row['generated_time_unix'], unit='s', utc='True').tz_convert(eastern).strftime('%Y-%m-%d %H:%M:%S %Z')

        unmatched_rows.append(row_out)

    unmatched_df = pd.DataFrame(unmatched_rows)
    matched_df = pd.DataFrame(matched_rows)
    all_rows = pd.concat([matched_df, unmatched_df], ignore_index=True)

    return matched_df, unmatched_df, all_rows

# Summary
def summarize(pa, matched):
    pa = pa.copy()
    pa['matched'] = pa.index.isin(matched.index)
    summary = pa.groupby('trip_id').agg(
        total_rows=('trip_id', 'count'),
        matched_rows=('matched', 'sum')
    ).reset_index()
    summary['unmatched_rows'] = summary['total_rows'] - summary['matched_rows']
    summary['match_rate_percent'] = round(100 * summary['matched_rows'] / summary['total_rows'], 2)
    return summary

# Collapse mismatch reasons
def collapse_mismatch_reasons(all_rows):
    unmatched = all_rows[(all_rows['mismatch_reason'].notna()) & (all_rows['mismatch_reason'] != '')].copy()
    if len(unmatched) == 0:
        return pd.DataFrame(columns=['trip_id', 'mismatch_reason', 'total_unmatched_rows'])

    unmatched['mismatch_reason'] = unmatched['mismatch_reason'].str.split('; ')
    exploded = unmatched.explode('mismatch_reason')
    grouped = exploded.groupby('trip_id')['mismatch_reason'].unique().reset_index()
    grouped['mismatch_reason'] = grouped['mismatch_reason'].apply(lambda lst: '; '.join(sorted(lst)))
    count_unmatched = unmatched.groupby('trip_id').size().reset_index(name='total_unmatched_rows')
    final = pd.merge(grouped, count_unmatched, on='trip_id')
    return final

# Generate clean unmatched summary
def create_clean_unmatched_summary(unmatched_df, tb_df, minor_tol=60):
    if len(unmatched_df) == 0:
        return pd.DataFrame(columns=['departure_time', 'trip_id', 'consist', 'PA_departure_time', 'TB_departure_time', 'mismatch_reason'])
    
    eastern = pytz.timezone('America/New_York')
    result = []

    for pa_dep, group_dep in unmatched_df.groupby('departure_time_unix'):
        pa_dt = pd.to_datetime(pa_dep, unit='s', utc=True).tz_convert(eastern)
        pa_time_str = pa_dt.strftime('%Y-%m-%d %H:%M:%S %Z')
        
        for trip_id, group_trip in group_dep.groupby('trip_id'):
            consists = group_trip['consist'].dropna().unique()
            consist_str = '; '.join(consists) if len(consists) > 0 else ''

            tb_times = group_trip['tableau_departure_time'].dropna().unique()
            tb_times = [t for t in tb_times if t != '']
            tb_time_str = tb_times[0] if len(tb_times) > 0 else ''
            
            if tb_time_str == '':
                tb_trip = tb_df[tb_df['trip_id'] == str(trip_id)]
                if len(tb_trip) > 0:
                    tb_unix = tb_trip['departure_time_unix'].iloc[0]
                    tb_dt = pd.to_datetime(tb_unix, unit='s', utc=True).tz_convert(eastern)
                    tb_time_str = tb_dt.strftime('%Y-%m-%d %H:%M:%S %Z')

            reasons = group_trip['mismatch_reason'].dropna().unique()
            all_reasons = set()
            for r in reasons:
                if r:
                    for rr in r.split('; '):
                        all_reasons.add(rr.strip())

            # Flag minor deviations if TB row exists within tolerance
            # Flag minor deviations if any TB row exists within minor_tol, ignoring trip_id
            if "No Tableau row with departure_time within tolerance" in all_reasons:
                pa_unix = int(pa_dep)
                tb_candidates = tb_df[
                    (tb_df['departure_time_unix'] >= pa_unix - minor_tol) &
                    (tb_df['departure_time_unix'] <= pa_unix + minor_tol)
                ]
                if len(tb_candidates) > 0:
                    all_reasons.remove("No Tableau row with departure_time within tolerance")
                    all_reasons.add("Minor departure deviation")
                    # Optional: capture first candidate time for TB_departure_time
                    tb_unix = tb_candidates['departure_time_unix'].iloc[0]
                    tb_dt = pd.to_datetime(tb_unix, unit='s', utc=True).tz_convert(eastern)
                    tb_time_str = tb_dt.strftime('%Y-%m-%d %H:%M:%S %Z')


            reason_str = '; '.join(sorted(all_reasons)) if all_reasons else ''

            result.append({
                'departure_time': pa_time_str,
                'trip_id': trip_id,
                'consist': consist_str,
                'PA_departure_time': pa_time_str,
                'TB_departure_time': tb_time_str,
                'mismatch_reason': reason_str
            })

    return pd.DataFrame(result)

# Main
if __name__ == '__main__':
    if len(sys.argv) != 3:
        print("Usage: ./delta-analyzer-departure (prediction analyzer file) (tableau file)", file=sys.stderr)
        exit(1)
    [_, pa_csv, tb_csv] = sys.argv
    pa_df, tb_df = load_data(pa_csv, tb_csv)
    pa_df, tb_df = normalize_keys(pa_df, tb_df)
    tb_df = preprocess_tableau(tb_df)

    matched_df, unmatched_df, all_rows = match_rows_with_reasons(pa_df, tb_df, tolerance=5)
    summary_df = summarize(pa_df, matched_df)
    mismatch_collapsed_df = collapse_mismatch_reasons(all_rows)
    clean_unmatched_df = create_clean_unmatched_summary(unmatched_df, tb_df)

    matched_df.to_csv('matched.csv', index=False)
    unmatched_df.to_csv('unmatched.csv', index=False)
    summary_df.to_csv('summary.csv', index=False)
    mismatch_collapsed_df.to_csv('mismatch_reason_summary.csv', index=False)
    clean_unmatched_df.to_csv('unmatched_clean.csv', index=False)

    total_trip_ids = summary_df['trip_id'].nunique()
    perfect_matches = (summary_df['unmatched_rows'] == 0).sum()
    no_matches = (summary_df['matched_rows'] == 0).sum()
    partial_matches = ((summary_df['matched_rows'] > 0) & (summary_df['unmatched_rows'] > 0)).sum()
    any_discrepancies = total_trip_ids - perfect_matches
    trip_id_mismatches = all_rows[all_rows['mismatch_reason'].str.contains("Trip ID mismatch", na=False)]['trip_id'].nunique()

    print(f"{total_trip_ids} total unique trip_IDs in the Prediction Analyzer data for that service day")
    print(f"{perfect_matches} trips had perfect matches")
    print(f"{any_discrepancies} trips had at least some discrepancies")
    print(f"This includes {no_matches} trips with NO matches")
    print(f"Plus {partial_matches} trips with PARTIAL matches (some rows matched, some didn't)")
    print(f"Additionally, {trip_id_mismatches} trips had Trip ID mismatches (departure_time matched but trip_id differed)")
