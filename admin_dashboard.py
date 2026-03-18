import requests
import os

# Load Configuration
if not os.path.exists("secret.txt"):
    print("Error: secret.txt not found!")
    exit()

with open("secret.txt", "r") as f:
    SECRET = f.read().strip()

BASE_URL = "http://127.0.0.1:8000"

def clear(): os.system('cls' if os.name == 'nt' else 'clear')

def main_menu():
    while True:
        clear()
        print("--- FNFast ADMIN DASHBOARD ---")
        print("1. View Pending Levels")
        print("2. Rate / Feature a Level")
        print("3. Delete Level / List")
        print("4. Ban User or IP")
        print("5. View Ban List")
        print("6. Unban User or IP")
        print("7. View Suspicious IPs")
        print("8. Download Backup")
        print("9. Tempban User or IP")
        print("10. View / Lift Tempbans")
        print("q. Exit")

        choice = input("\nSelect: ")
        if choice == "1":   list_pending()
        elif choice == "2": rate_level()
        elif choice == "3": delete_item()
        elif choice == "4": ban_manager()
        elif choice == "5": view_bans()
        elif choice == "6": unban_manager()
        elif choice == "7": view_suspicious()
        elif choice == "8": download_backup()
        elif choice == "9": tempban_manager()
        elif choice == "10": view_tempbans()
        elif choice == "q": break

# ---- EXISTING FUNCTIONS ----

def list_pending():
    res = requests.get(f"{BASE_URL}/charts").json()
    print("\n--- PENDING LEVELS ---")
    for c in res:
        if c.get('status') != 'verified':
            print(f"  ID: {c['id']:<30} Author: {c.get('author', 'unknown'):<20} Suggested: {c.get('suggested_rating', '?')}")
    input("\nPress Enter...")

def rate_level():
    cid = input("Enter Chart ID: ")
    rating = input("Enter Rating (Stars): ")
    feat = input("Feature? (y/n): ").lower() == 'y'
    url = f"{BASE_URL}/admin/rate?id={cid}&rating={rating}&featured={feat}&secret={SECRET}"
    print(requests.get(url).json())
    input("\nDone.")

def delete_item():
    print("1. Delete Chart\n2. Delete Playlist")
    mode = input("Select: ")
    item_id = input("Enter ID to delete: ")
    route = "chart" if mode == "1" else "list"
    res = requests.delete(f"{BASE_URL}/admin/{route}/{item_id}?secret={SECRET}").json()
    print(res)
    input("\nDone.")

def ban_manager():
    print("1. Ban IP\n2. Ban Username")
    mode = input("Select: ")
    val = input("Enter IP or Username: ")
    b_type = "ips" if mode == "1" else "users"
    res = requests.post(f"{BASE_URL}/admin/ban_item?type={b_type}&value={val}&secret={SECRET}").json()
    print(res)
    input("\nDone.")

def view_bans():
    res = requests.get(f"{BASE_URL}/admin/bans?secret={SECRET}").json()
    print("\n--- BANNED IPs ---")
    if res.get("ips"):
        for ip in res["ips"]:
            print(f"  {ip}")
    else:
        print("  (none)")
    print("\n--- BANNED USERS ---")
    if res.get("users"):
        for u in res["users"]:
            print(f"  {u}")
    else:
        print("  (none)")
    input("\nPress Enter...")

# ---- NEW FUNCTIONS ----

def unban_manager():
    """Unban a specific user/IP or clear an entire list."""
    clear()
    print("--- UNBAN MANAGER ---")
    print("1. Unban a specific IP")
    print("2. Unban a specific Username")
    print("3. Clear ALL banned IPs")
    print("4. Clear ALL banned Users")
    print("b. Back")
    mode = input("\nSelect: ")

    if mode == "b":
        return

    if mode in ("1", "2"):
        val = input("Enter IP or Username to unban: ").strip()
        if not val:
            print("No value entered.")
            input("\nPress Enter...")
            return
        b_type = "ips" if mode == "1" else "users"
        res = requests.post(
            f"{BASE_URL}/admin/unban_item?type={b_type}&value={val}&secret={SECRET}"
        ).json()
        print(res)

    elif mode in ("3", "4"):
        b_type = "ips" if mode == "3" else "users"
        confirm = input(f"Are you sure you want to clear ALL banned {b_type}? (yes/no): ").strip().lower()
        if confirm == "yes":
            res = requests.post(
                f"{BASE_URL}/admin/unban_all?type={b_type}&secret={SECRET}"
            ).json()
            print(res)
        else:
            print("Cancelled.")

    input("\nDone. Press Enter...")

def view_suspicious():
    """Show IPs flagged by bot detection."""
    clear()
    print("--- SUSPICIOUS IPs (Bot Detection) ---")
    res = requests.get(f"{BASE_URL}/admin/suspicious_ips?secret={SECRET}").json()

    if not res:
        print("  No suspicious activity recorded yet.")
        input("\nPress Enter...")
        return

    print(f"  {'IP':<20} {'Rate Hits':>10} {'Unauth':>8} {'Total':>7} {'Flagged':>8}  Last Seen")
    print("  " + "-" * 75)
    for entry in res:
        flagged = "*** YES ***" if entry["flagged"] else "no"
        print(
            f"  {entry['ip']:<20} {entry['rate_limit_hits']:>10} {entry['unauth_attempts']:>8} "
            f"{entry['total_score']:>7} {flagged:>11}  {entry.get('last_seen', 'N/A')}"
        )

    print("\nOptions:")
    print("  b: Back")
    print("  ban <ip>: Immediately ban a flagged IP")
    print("  clear <ip>: Remove an IP from the suspicious list")
    action = input("\nAction: ").strip().lower()

    if action.startswith("ban "):
        ip = action[4:].strip()
        res = requests.post(f"{BASE_URL}/admin/ban_item?type=ips&value={ip}&secret={SECRET}").json()
        print(res)
        input("\nDone. Press Enter...")
    elif action.startswith("clear "):
        ip = action[6:].strip()
        res = requests.post(f"{BASE_URL}/admin/clear_suspicious?ip={ip}&secret={SECRET}").json()
        print(res)
        input("\nDone. Press Enter...")

def download_backup():
    """Download a server backup ZIP to the current directory."""
    clear()
    print("--- DOWNLOAD BACKUP ---")
    print("Requesting backup from server...")
    try:
        res = requests.get(f"{BASE_URL}/admin/backup?secret={SECRET}", stream=True, timeout=30)
        if res.status_code == 200:
            # Pull filename from Content-Disposition header if available
            cd = res.headers.get("Content-Disposition", "")
            filename = "backup.zip"
            if "filename=" in cd:
                filename = cd.split("filename=")[-1].strip().strip('"')
            with open(filename, "wb") as f:
                for chunk in res.iter_content(chunk_size=8192):
                    f.write(chunk)
            print(f"Backup saved as: {filename}")
        else:
            print(f"Error: {res.status_code} - {res.text}")
    except Exception as e:
        print(f"Failed: {e}")
    input("\nPress Enter...")

def tempban_manager():
    """Issue a tempban for a username or IP."""
    clear()
    print("--- TEMPBAN ---")
    target = input("Enter Username or IP to tempban: ").strip()
    if not target:
        print("No target entered.")
        input("\nPress Enter...")
        return

    print("\nDuration presets:")
    print("  1.  15 minutes     2.  30 minutes")
    print("  3.  1 hour         4.  6 hours")
    print("  5.  24 hours       6.  3 days")
    print("  7.  7 days         c.  Custom")
    preset = input("\nSelect: ").strip().lower()

    presets = {"1": 15, "2": 30, "3": 60, "4": 360, "5": 1440, "6": 4320, "7": 10080}
    if preset in presets:
        minutes = presets[preset]
    elif preset == "c":
        try:
            minutes = int(input("Enter duration in minutes: ").strip())
        except ValueError:
            print("Invalid number.")
            input("\nPress Enter...")
            return
    else:
        print("Invalid selection.")
        input("\nPress Enter...")
        return

    reason = input("Reason (optional, press Enter to skip): ").strip()

    res = requests.post(
        f"{BASE_URL}/admin/tempban",
        params={"target": target, "minutes": minutes, "reason": reason, "secret": SECRET}
    ).json()
    print(res)
    input("\nDone. Press Enter...")


def view_tempbans():
    """View all active tempbans and optionally lift one."""
    clear()
    print("--- ACTIVE TEMPBANS ---")
    res = requests.get(f"{BASE_URL}/admin/tempbans?secret={SECRET}").json()

    if not res:
        print("  No active tempbans.")
        input("\nPress Enter...")
        return

    print(f"  {'Target':<25} {'Remaining':>12}  {'Expires (UTC)':<20}  Reason")
    print("  " + "-" * 80)
    for entry in res:
        rem = entry["remaining_minutes"]
        hours, mins = divmod(rem, 60)
        rem_str = f"{hours}h {mins}m" if hours else f"{mins}m"
        expires = entry["expires_at"].replace("T", " ")[:16]
        print(f"  {entry['target']:<25} {rem_str:>12}  {expires:<20}  {entry.get('reason', '')}")

    print("\nOptions:")
    print("  b: Back")
    print("  lift <target>: Remove a tempban early")
    action = input("\nAction: ").strip().lower()

    if action.startswith("lift "):
        target = action[5:].strip()
        res = requests.post(
            f"{BASE_URL}/admin/untimeban",
            params={"target": target, "secret": SECRET}
        ).json()
        print(res)
        input("\nDone. Press Enter...")


if __name__ == "__main__":
    main_menu()