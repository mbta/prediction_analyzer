import requests
import pandas as pd
from io import StringIO
from datetime import datetime, timedelta
import time

# =========================
# SETTINGS
# =========================
DATES = ["2025-09-15"]  # Service dates (YYYY-MM-DD)
STOP_ID = "70106"                     # Stop ID to retrieve
MAX_RETRIES = 20                       # Retries per service hour if request fails
RETRY_DELAY = 1                       # Seconds to wait between retries
BASE_URL = "http://prediction-analyzer-dev.mbtace.com/predictions"
# =========================


def fetch_hour_data(service_date, hour, stop_id):
    """
    Fetch CSV data for a given date, hour, and stop_id with retry logic.
    Returns a pandas DataFrame or None if request fails.
    """
    url = f"{BASE_URL}?date={service_date}&hour={hour}&stop_id={stop_id}"
    for attempt in range(1, MAX_RETRIES + 1):
        print(f"[INFO] Fetching: {url} (Attempt {attempt})")
        try:
            response = requests.get(url, timeout=30)
            response.raise_for_status()
            if not response.text.strip():  # Empty response
                print(f"[WARN] No data returned for {service_date} hour {hour}")
                return None
            return pd.read_csv(StringIO(response.text))
        except Exception as e:
            print(f"[ERROR] Failed to fetch {service_date} hour {hour}: {e}")
            if attempt < MAX_RETRIES:
                print(f"[INFO] Retrying in {RETRY_DELAY} seconds...")
                time.sleep(RETRY_DELAY)
            else:
                print(f"[ERROR] Max retries reached for {service_date} hour {hour}")
                return None


def get_service_hours(service_date_str):
    """
    Given a service date string (YYYY-MM-DD), return list of (date, hour) pairs
    starting at 4:00 AM service_date to 3:00 AM next day.
    """
    start = datetime.strptime(service_date_str, "%Y-%m-%d").replace(hour=4, minute=0, second=0)
    hours = []
    for i in range(24):
        dt = start + timedelta(hours=i)
        hours.append((dt.strftime("%Y-%m-%d"), dt.hour))
    return hours


def retrieve_and_merge(dates, stop_id):
    all_data = []
    for service_date in dates:
        print(f"[INFO] Processing service date: {service_date}")
        hours = get_service_hours(service_date)
        for date_str, hour in hours:
            df = fetch_hour_data(date_str, hour, stop_id)
            if df is not None and not df.empty:
                all_data.append(df)

    if not all_data:
        print("[WARN] No data retrieved for given dates/stop_id.")
        return

    merged_df = pd.concat(all_data, ignore_index=True)
    merged_df.sort_values(by=merged_df.columns[0], inplace=True)

    date_str_for_filename = "-".join(dates)
    filename = f"merged-{stop_id}-{date_str_for_filename}.csv"
    merged_df.to_csv(filename, index=False)
    print(f"[INFO] Saved merged file: {filename}")


if __name__ == "__main__":
    retrieve_and_merge(DATES, STOP_ID)
