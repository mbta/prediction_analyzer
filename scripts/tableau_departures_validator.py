import pandas as pd
import delta_analyzer_departure
import pytz
import sys

def match_rows_with_reasons(pa, tb, tolerance_dep=15):
    pa['departure_time_unix'] = pd.to_numeric(pa['departure_time_unix'], errors='coerce')
    tb['departure_time_unix'] = pd.to_numeric(tb['departure_time_unix'], errors='coerce')

    pa = pa.dropna(subset=['departure_time_unix']).copy()
    tb = tb.dropna(subset=['departure_time_unix']).copy()
    pa['departure_time_unix'] = pa['departure_time_unix'].astype('int64')
    tb['departure_time_unix'] = tb['departure_time_unix'].astype('int64')

    eastern = pytz.timezone('America/New_York')
    # unmatched_rows = []
    # matched_rows = []

    # Sort both dataframes
    pa_sorted = pa.sort_values('departure_time_unix').reset_index(drop=True)
    tb_sorted = tb.sort_values('departure_time_unix').reset_index(drop=True)

    # Merge dataframes
    merged = pd.merge_asof(
        tb_sorted,
        pa_sorted,
        on='departure_time_unix',
        direction='nearest',
        tolerance=tolerance_dep,
        suffixes=('_tb', '_pa')
    )

    # Add source indicator
    merged['source_indicator'] = merged.apply(
        lambda row: 'Both' if pd.notna(row.get('trip_id_pa')) else 'Tableau only',
        axis=1
    )

    # Find Prediction Analyzer only rows
    # matched_pa_indices = merged[merged['source_indicator'] == 'Both'].index
    # pa_only = pa_sorted[~pa_sorted.index.isin(matched_pa_indices)].copy()
    pa_matched_times = merged[merged['source_indicator'] == 'Both']['departure_time_unix'].values
    pa_only = pa_sorted[~pa_sorted['departure_time_unix'].isin(pa_matched_times)].copy()

    # all_rows = pd.concat([merged, pa_only], ignore_index=True)
    pa_only = pa_only.rename(columns={'departure_time_unix': 'departure_time_unix_pa'})
    # Combine all results - use departure_time_unix from merged, departure_time_unix_pa from pa_only
    all_rows = pd.concat([merged, pa_only], ignore_index=True)

    # Add EST-formatted time
    # all_rows['departure_time_est'] = pd.to_datetime(
    #     all_rows['departure_time_unix'],
    #     unit='s',
    #     utc=True
    # ).dt.tz_convert(eastern).dt.strftime('%Y-%m-%d %H:%M:%S %Z')
    all_rows['departure_time_est'] = all_rows['departure_time_unix'].apply(
        lambda x: pd.Timestamp(x, unit='s', tz='UTC').tz_convert(eastern).strftime('%Y-%m-%d %H:%M:%S %Z')
        if pd.notna(x) else ''
    )

    # # check each row in tableau and see if it's present in prediction analyzer, with tolerance
    # for _, tb_row in tb.iterrows():
    #     if pd.isna(tb_row['departure_time_unix']):
    #         continue
    #     tb_dep = int(tb_row['departure_time_unix'])
    #     candidates = pa[
    #         (tb_dep >= pa['departure_time_unix'] - tolerance_dep)
    #         & (tb_dep <= pa['departure_time_unix'] + tolerance_dep)
    #     ]
        
    #     row_out = tb_row.copy()

    #     if candidates.empty:
    #         unmatched_rows.append(row_out)
    #     else:
    #         matched_rows.append(row_out)

    # unmatched_df = pd.DataFrame(unmatched_rows)
    # matched_df = pd.DataFrame(matched_rows)
    # all_rows = pd.concat([matched_df, unmatched_df], ignore_index=True)

    matched_df = all_rows[all_rows['source_indicator'] == 'Both']
    unmatched_df = all_rows[all_rows['source_indicator'] != 'Both']

    return matched_df, unmatched_df, all_rows

if __name__ == '__main__':
    if len(sys.argv) != 3:
        print('Usage: ./tableau-prediction-gap-validator (prediction analyzer file) (tableau file)', file=sys.stderr)
        exit(1)
    [_, pa_csv, tb_csv] = sys.argv
    pa_df, tb_df = delta_analyzer_departure.load_data(pa_csv, tb_csv)
    pa_df, tb_df = delta_analyzer_departure.normalize_keys(pa_df, tb_df)

    # filters out rows with invalid null columns
    # converts tableau datetime values to unix time
    tb_df = delta_analyzer_departure.preprocess_tableau(tb_df)

    matched_df, unmatched_df, all_rows = match_rows_with_reasons(pa_df, tb_df, tolerance_dep=15)
    
    # compare tableau dataframe against matched dataframe, instead of entire set of prediction analyzer data
    summary_df = delta_analyzer_departure.summarize(tb_df, matched_df)
    
    # file generation
    matched_df.to_csv('matched.csv', index=False)
    unmatched_df.to_csv('unmatched.csv', index=False)
    summary_df.to_csv('summary.csv', index=False)
    
    total_trip_ids = summary_df['trip_id'].nunique()
    perfect_matches = (summary_df['unmatched_rows'] == 0).sum()
    no_matches = (summary_df['matched_rows'] == 0).sum()
    partial_matches = ((summary_df['matched_rows'] > 0) & (summary_df['unmatched_rows'] > 0)).sum()
    
    print(f'{total_trip_ids} total unique trip_IDs in the Tableau data for that service day')
    print(f'{perfect_matches} trips had perfect matches')
    print(f'This includes {no_matches} trips with NO matches')
    print(f"Plus {partial_matches} trips with PARTIAL matches (some rows matched, some didn't)")
