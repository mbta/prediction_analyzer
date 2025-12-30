import pandas as pd
import pytz
from datetime import datetime
import sys

def parse_tableau_time(time_str):
    """Convert Tableau datetime string to Unix timestamp"""
    try:
        # Parse format like "12/11/2025 5:00:38 AM"
        dt = pd.to_datetime(time_str, format='%m/%d/%Y %I:%M:%S %p')
        # Localize to Eastern time, then convert to UTC
        eastern = pytz.timezone('America/New_York')
        dt_eastern = eastern.localize(dt)
        dt_utc = dt_eastern.astimezone(pytz.UTC)
        return int(dt_utc.timestamp())
    except:
        return None

def unix_to_est(unix_time):
    """Convert Unix timestamp to EST formatted string"""
    if pd.isna(unix_time):
        return ''
    eastern = pytz.timezone('America/New_York')
    dt_utc = datetime.fromtimestamp(unix_time, tz=pytz.UTC)
    dt_est = dt_utc.astimezone(eastern)
    return dt_est.strftime('%Y-%m-%d %I:%M:%S %p %Z')

def match_departures(pa_file, tb_file, tolerance=15):
    """Match departure times between PA and Tableau data"""

    # Load Prediction Analyzer data
    pa_df = pd.read_csv(pa_file)
    pa_df['departure_time_unix'] = pd.to_numeric(pa_df['departure_time'], errors='coerce')
    pa_df = pa_df.dropna(subset=['departure_time_unix'])
    pa_df = pa_df.drop_duplicates(subset=['departure_time', 'trip_id'], keep='first')
    pa_df['departure_time_unix'] = pa_df['departure_time_unix'].astype('int64')

    # Load Tableau data
    tb_df = pd.read_csv(tb_file, sep='\t', encoding='utf-16')
    tb_df['departure_time_unix'] = tb_df['Departure Time'].apply(parse_tableau_time)
    tb_df = tb_df.dropna(subset=['departure_time_unix'])
    tb_df['departure_time_unix'] = tb_df['departure_time_unix'].astype('int64')

    # Sort both dataframes
    pa_sorted = pa_df.sort_values('departure_time_unix').reset_index(drop=True)
    tb_sorted = tb_df.sort_values('departure_time_unix').reset_index(drop=True)

    # Merge with tolerance using merge_asof
    merged = pd.merge_asof(
        tb_sorted,
        pa_sorted,
        on='departure_time_unix',
        direction='nearest',
        tolerance=tolerance,
        suffixes=('_tb', '_pa')
    )

    # Mark which Tableau rows successfully matched to a PA row
    merged['tb_matched'] = pd.notna(merged.get('trip_id'))
    merged['source'] = merged['tb_matched'].apply(lambda x: 'Tableau matched to PA' if x else 'Tableau only')

    # Find which unique PA rows were matched
    matched_pa_indices = set()
    for _, tb_row in merged[merged['tb_matched']].iterrows():
        tb_time = tb_row['departure_time_unix']
        matching_pa = pa_sorted[
            (pa_sorted['departure_time_unix'] >= tb_time - tolerance) &
            (pa_sorted['departure_time_unix'] <= tb_time + tolerance)
        ]
        if len(matching_pa) > 0:
            closest_idx = (matching_pa['departure_time_unix'] - tb_time).abs().idxmin()
            matched_pa_indices.add(closest_idx)

    # Mark PA rows
    pa_sorted['source'] = ['PA matched to Tableau' if idx in matched_pa_indices else 'PA only' for idx in pa_sorted.index]

    # Combine all Tableau rows and PA rows
    all_matches = pd.concat([merged, pa_sorted], ignore_index=True)

    # Add EST formatted time
    all_matches['departure_time_est'] = all_matches['departure_time_unix'].apply(unix_to_est)

    # Select and order output columns
    output_cols = ['departure_time_unix', 'departure_time_est', 'source']

    # Add relevant data columns based on source
    if 'trip_id' in all_matches.columns:
        output_cols.append('trip_id')
    if 'Trip ID' in all_matches.columns:
        all_matches['tableau_trip_id'] = all_matches['Trip ID']
        output_cols.append('tableau_trip_id')
    if 'vehicle_label' in all_matches.columns:
        output_cols.append('vehicle_label')
    if 'Vehicle Consist' in all_matches.columns:
        all_matches['tableau_consist'] = all_matches['Vehicle Consist']
        output_cols.append('tableau_consist')

    # Filter to available columns
    output_cols = [col for col in output_cols if col in all_matches.columns]

    result_df = all_matches[output_cols].copy()

    return result_df, len(tb_df), len(pa_df)

if __name__ == '__main__':
    tolerance = 15

    if len(sys.argv) == 4:
        tolerance = int(sys.argv[3])
        pa_file = sys.argv[1]
        tb_file = sys.argv[2]
    elif len(sys.argv) == 3:
        pa_file = sys.argv[1]
        tb_file = sys.argv[2]
    else:
        print("Usage: python departure_time_matcher.py <pa_csv> <tb<csv> [tolerance_seconds]")
        sys.exit(1)

    matches_df, total_tb, total_pa = match_departures(pa_file, tb_file, tolerance)

    # Save to CSV
    matches_df.to_csv('matches.csv', index=False)

    # Print summary
    tb_matched = len(matches_df[matches_df['source'] == 'Tableau matched to PA'])
    tb_only = len(matches_df[matches_df['source'] == 'Tableau only'])
    pa_matched = len(matches_df[matches_df['source'] == 'PA matched to Tableau'])
    pa_only = len(matches_df[matches_df['source'] == 'PA Only'])

    print(f"\n=== Departure Time Match Summary ===")
    print(f"Tolerance: {tolerance} seconds")
    print(f"\nTotal rows in Tableau: {total_tb}")
    print(f"Total rows in Prediction Analyzer: {total_pa}")
    print(f"\nTableau rows that matched to PA: {tb_matched}")
    print(f"Tableau rows with no PA match: {tb_only}")
    print(f"PA rows that matched to Tableau: {pa_matched}")
    print(f"PA rows with no Tableau match: {pa_only}")
    print(f"\nTotal output rows: {len(matches_df)} (should equal {total_tb + total_pa})")
    print(f"\nResults saved to matches.csv")
