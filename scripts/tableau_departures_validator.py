import pandas as pd
import delta_analyzer_departure
import pytz
import sys

def match_rows_with_reasons(pa, tb, tolerance_dep=15, tolerance=15):
    pa['departure_time_unix'] = pd.to_numeric(pa['departure_time_unix'], errors='coerce')
    tb['departure_time_unix'] = pd.to_numeric(tb['departure_time_unix'], errors='coerce')

    eastern = pytz.timezone('America/New_York')
    unmatched_rows = []
    matched_rows = []

    # check each row in tableau and see if it's present in prediction analyzer, with tolerance
    for _, tb_row in tb.iterrows():
        if pd.isna(tb_row['departure_time_unix']):
            continue
        tb_dep = int(tb_row['departure_time_unix'])
        candidates = pa[
            (tb_dep >= pa['departure_time_unix'] - tolerance_dep)
            & (tb_dep <= pa['departure_time_unix'] + tolerance_dep)
        ]
        
        row_out = tb_row.copy()

        if candidates.empty:
            unmatched_rows.append(row_out)
        else:
            matched_rows.append(row_out)

    unmatched_df = pd.DataFrame(unmatched_rows)
    matched_df = pd.DataFrame(matched_rows)
    all_rows = pd.concat([matched_df, unmatched_df], ignore_index=True)

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

    matched_df, unmatched_df, all_rows = match_rows_with_reasons(pa_df, tb_df, tolerance_dep=15, tolerance=60)
    
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
