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
    pa_df['departure_time_unix'] = pd.to_numeric(pa_df['departure_time'])
    pa_df = pa_df.dropna(subset=['departure_time_unix'])
    pa_df = pa_df.drop_duplicates(subset=['departure_time', 'trip_id'], keep='first')
    pa_df['departure_time_unix'] = pa_df['departure_time_unix'].astype('int64')

    # Load Tableau data
    tb_df = pd.read_csv(tb_file, sep='\t', encoding='utf-16')
    tb_df['departure_time_unix'] = tb_df['Departure Time'].apply(parse_tableau_time)
    tb_df = tb_df.dropna(subset=['departure_time_unix'])
    tb_df['departure_time_unix'] = tb_df['departure_time_unix']

    # Read false positive flag
    tb_df['is_false_positive'] = tb_df['False Positive Departure Flag'].notna()

    # Sort both dataframes
    pa_sorted = pa_df.sort_values('departure_time_unix').reset_index(drop=True)
    pa_sorted['pa_index'] = pa_sorted.index
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

    # Determine source
    merged['source'] = merged.apply(
        lambda row: 'Both' if pd.notna(row.get('trip_id')) else 'Tableau Only',
        axis=1
    )

    # Find all PA rows within tolerance of any Tableau row
    # matched_pa_indices = merged[merged['source'] == 'Both']['pa_index'].dropna().astype(int).values
    matched_pa_indices = set()
    for tb_time in tb_sorted['departure_time_unix']:
        # Find all PA rows within tolerance of this Tableau time
        within_tolerance = pa_sorted[
            (pa_sorted['departure_time_unix'] >= tb_time - tolerance) &
            (pa_sorted['departure_time_unix'] <= tb_time + tolerance)
        ]['pa_index'].values
        matched_pa_indices.update(within_tolerance)

    # PA-only rows not within tolerance of Tableau row
    pa_only = pa_sorted[~pa_sorted['pa_index'].isin(matched_pa_indices)].copy()
    pa_only['source'] = 'PA Only'
    pa_only['is_false_positive'] = False

    # Combine all results
    all_matches = pd.concat([merged, pa_only], ignore_index=True)

    # Count false positives by source before filtering
    fp_tableau_only = len(all_matches[(all_matches['source'] == 'Tableau Only') &(all_matches['is_false_positive'] == True)])
    fp_both = len(all_matches[(all_matches['source'] == 'Both') &(all_matches['is_false_positive'] == True)])

    # Filter out false positives
    all_matches = all_matches[~((all_matches['source'].isin(['Tableau Only', 'Both'])) & (all_matches['is_false_positive'] == True))]

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

    return result_df, len(tb_df), len(pa_df), fp_tableau_only, fp_both

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

    matches_df, total_tb, total_pa, fp_tableau_only, fp_both = match_departures(pa_file, tb_file, tolerance)

    # Save to CSV
    matches_df.to_csv('matches.csv', index=False)

    # Print summary
    tb_only = len(matches_df[matches_df['source'] == 'Tableau Only'])
    pa_only = len(matches_df[matches_df['source'] == 'PA Only'])
    both = len(matches_df[matches_df['source'] == 'Both'])

    print(f"\n=== Departure Time Match Summary ===")
    print(f"Tolerance: {tolerance} seconds")
    print(f"\nMatches in both: {both}")
    print(f"Tableau only (no PA match): {tb_only}")
    print(f"PA only (no Tableau match): {pa_only}")
    print(f"\nFalse positives detected and ignored:")
    print(f"    Tableau Only: {fp_tableau_only}")
    print(f"    Both: {fp_both}")
    print(f"    Total false positives: {fp_tableau_only + fp_both}")
    print(f"\nTotal output rows: {len(matches_df)}")
    print(f"\nResults saved to matches.csv")
