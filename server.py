import os
import io
import json
import hashlib
import sqlite3
import uuid
import zipfile
import shutil
import secrets
from collections import defaultdict
from datetime import datetime, timedelta
from typing import List, Optional
import subprocess
FFMPEG_LOC = r"C:\\Users\\pc\\Downloads\\ffmpeg-master-latest-win64-gpl-shared\\bin"
import asyncio
from fastapi import BackgroundTasks, FastAPI, Request, UploadFile, HTTPException, Depends
from fastapi.responses import FileResponse, PlainTextResponse
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from jose import JWTError, jwt
if not os.path.exists("secret.txt"):
    with open("secret.txt", "w") as f:
        f.write("my_admin_password_123")
with open("secret.txt", "r") as f:
    ADMIN_SECRET = f.read().strip()
BANS_FILE = "bans.json"

def load_bans():
    if not os.path.exists(BANS_FILE):
        return {"ips": [], "users": [], "tempbans": {}}
    data = json.load(open(BANS_FILE, "r"))
    # Migrate old files that don't have tempbans key
    if "tempbans" not in data:
        data["tempbans"] = {}
    return data

def save_bans(data):
    with open(BANS_FILE, "w") as f:
        json.dump(data, f, indent=4)

def get_file_hash(file_path):
    with open(file_path, "rb") as f:
        return hashlib.md5(f.read()).hexdigest()

def check_admin(secret: str):
    if secret != ADMIN_SECRET:
        raise HTTPException(status_code=403, detail="Invalid admin secret")

# ==========================================
# TEMPBAN HELPERS
# ==========================================
def add_tempban(target: str, duration_minutes: int, reason: str = "") -> dict:
    """
    Add a tempban entry for a username or IP.
    Returns the entry dict that was saved.
    """
    bans = load_bans()
    expires_at = (datetime.utcnow() + timedelta(minutes=duration_minutes)).isoformat()
    entry = {
        "expires_at": expires_at,
        "reason": reason,
        "duration_minutes": duration_minutes
    }
    bans["tempbans"][target] = entry
    save_bans(bans)
    return entry

def remove_tempban(target: str) -> bool:
    """Remove a tempban manually. Returns True if it existed."""
    bans = load_bans()
    if target in bans["tempbans"]:
        del bans["tempbans"][target]
        save_bans(bans)
        return True
    return False

def check_tempban(target: str) -> dict | None:
    """
    Returns the tempban entry if the target is currently tempbanned,
    None otherwise. Also auto-expires stale entries.
    """
    bans = load_bans()
    entry = bans["tempbans"].get(target)
    if not entry:
        return None
    expires_at = datetime.fromisoformat(entry["expires_at"])
    if datetime.utcnow() >= expires_at:
        # Auto-expire: clean up and return None
        del bans["tempbans"][target]
        save_bans(bans)
        return None
    return entry

def list_tempbans() -> list:
    """Return all active tempbans, pruning expired ones."""
    bans = load_bans()
    now = datetime.utcnow()
    active = []
    expired_keys = []
    for target, entry in bans["tempbans"].items():
        expires_at = datetime.fromisoformat(entry["expires_at"])
        if now >= expires_at:
            expired_keys.append(target)
        else:
            remaining = expires_at - now
            active.append({
                "target": target,
                "expires_at": entry["expires_at"],
                "reason": entry.get("reason", ""),
                "duration_minutes": entry.get("duration_minutes", 0),
                "remaining_minutes": int(remaining.total_seconds() / 60)
            })
    if expired_keys:
        for k in expired_keys:
            del bans["tempbans"][k]
        save_bans(bans)
    return active

# ==========================================
# CONFIGURATION & PATHS
# ==========================================
if not os.path.exists("password.txt"):
    with open("password.txt", "w") as f:
        f.write("my_admin_password_123")
with open("password.txt", "r") as f:
    SECRET_KEY = f.read().strip()
ALGORITHM = "HS256"
TOKEN_EXPIRE_DAYS = 30
CHARTS_DB = "charts_db.json"

ASSET_ROOT = "assetsfolder\\materials"
UPLOAD_DIR = "charts"
DB_FILE = "materials_db.json"
USER_DB = "users.db"

for folder in [ASSET_ROOT, UPLOAD_DIR, "assetsfolder/materials/characters", "assetsfolder/characters", "assetsfolder/images/characters", "assetsfolder/scripts", "assetsfolder/sounds"]:
    os.makedirs(folder, exist_ok=True)

app = FastAPI(title="Psych Engine Online Server")
from slowapi import Limiter, _rate_limit_exceeded_handler
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

limiter = Limiter(key_func=get_remote_address)
app.state.limiter = limiter
app.add_exception_handler(RateLimitExceeded, _rate_limit_exceeded_handler)

# ==========================================
# BOT DETECTION: In-memory tracking
# ==========================================
# Tracks IPs that have hit rate limits or made unauthenticated write attempts
_suspicious_counts: dict = defaultdict(lambda: {"rate_limit_hits": 0, "unauth_attempts": 0, "last_seen": None})
SUSPICIOUS_THRESHOLD = 5  # Flag after this many combined suspicious events

def record_suspicious(ip: str, reason: str):
    entry = _suspicious_counts[ip]
    if reason == "rate_limit":
        entry["rate_limit_hits"] += 1
    elif reason == "unauth":
        entry["unauth_attempts"] += 1
    entry["last_seen"] = datetime.utcnow().isoformat()

def is_suspicious(ip: str) -> bool:
    entry = _suspicious_counts.get(ip)
    if not entry:
        return False
    total = entry["rate_limit_hits"] + entry["unauth_attempts"]
    return total >= SUSPICIOUS_THRESHOLD

def verify_token_safe(token: str):
    """Like verify_token but never raises — returns None on any failure."""
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload.get("sub")
    except Exception:
        return None

@app.middleware("http")
async def ban_and_bot_middleware(request: Request, call_next):
    bans = load_bans()
    client_ip = request.client.host

    # --- Hard IP ban ---
    if client_ip in bans["ips"]:
        raise HTTPException(status_code=403, detail="Your IP is banned from this service.")

    # --- Tempban check for IP ---
    tb_ip = check_tempban(client_ip)
    if tb_ip:
        expires = tb_ip["expires_at"].replace("T", " ")[:16]
        reason_str = f" Reason: {tb_ip['reason']}." if tb_ip.get("reason") else ""
        raise HTTPException(
            status_code=403,
            detail=f"Your IP is temporarily banned until {expires} UTC.{reason_str}"
        )

    # --- Tempban / hard-ban check for username (decoded from Bearer token) ---
    auth_header = request.headers.get("Authorization", "")
    if auth_header.startswith("Bearer "):
        token = auth_header[7:]
        username = verify_token_safe(token)
        if username:
            if username in bans["users"]:
                raise HTTPException(status_code=403, detail="Your account is banned from this service.")
            tb_user = check_tempban(username)
            if tb_user:
                expires = tb_user["expires_at"].replace("T", " ")[:16]
                reason_str = f" Reason: {tb_user['reason']}." if tb_user.get("reason") else ""
                raise HTTPException(
                    status_code=403,
                    detail=f"Your account is temporarily banned until {expires} UTC.{reason_str}"
                )

    # --- Bot detection: unauthenticated writes ---
    write_paths = ["/upload_chart", "/upload_material_package", "/upload_list",
                   "/submit_score", "/post_comment", "/like_chart"]
    if request.method in ("POST", "DELETE") and any(request.url.path.startswith(p) for p in write_paths):
        if not auth_header:
            record_suspicious(client_ip, "unauth")

    response = await call_next(request)

    # --- Bot detection: rate limit hits ---
    if response.status_code == 429:
        record_suspicious(client_ip, "rate_limit")

    return response

# ==========================================
# ADMIN: SUSPICIOUS IPS
# ==========================================
@app.get("/admin/suspicious_ips")
async def get_suspicious_ips(secret: str):
    check_admin(secret)
    results = []
    for ip, data in _suspicious_counts.items():
        total = data["rate_limit_hits"] + data["unauth_attempts"]
        if total > 0:
            results.append({
                "ip": ip,
                "rate_limit_hits": data["rate_limit_hits"],
                "unauth_attempts": data["unauth_attempts"],
                "total_score": total,
                "flagged": total >= SUSPICIOUS_THRESHOLD,
                "last_seen": data["last_seen"]
            })
    results.sort(key=lambda x: -x["total_score"])
    return results

@app.post("/admin/clear_suspicious")
async def clear_suspicious_ip(ip: str, secret: str):
    """Remove a specific IP from the suspicious tracking list."""
    check_admin(secret)
    if ip in _suspicious_counts:
        del _suspicious_counts[ip]
        return {"status": f"Cleared suspicious record for {ip}"}
    return {"status": "IP not found in suspicious list"}

from fastapi.responses import RedirectResponse

TEMP_AUDIO_DIR = "temp_audio"
os.makedirs(TEMP_AUDIO_DIR, exist_ok=True)

def cleanup_file(path: str):
    if os.path.exists(path):
        os.remove(path)
        print(f"Cleaned up temporary file: {path}")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

def analyze_difficulty(chart_data):
    if isinstance(chart_data.get("song"), dict):
        chart_data = chart_data["song"]

    keys = chart_data.get("keys", 4)
    if "mania" in chart_data:
        mania_map = {0: 4, 1: 6, 2: 7, 3: 9, 4: 5, 5: 8}
        keys = mania_map.get(chart_data["mania"], 4)

    notes = []
    timestamps = []

    for section in chart_data.get("notes", []):
        must_hit = section.get("mustHitSection", True)
        for note in section.get("sectionNotes", []):
            time = float(note[0])
            lane = int(note[1])

            is_player_note = False
            if must_hit and lane < keys:
                is_player_note = True
            elif not must_hit and keys <= lane < (keys * 2):
                is_player_note = True

            if is_player_note:
                timestamps.append(time)
                notes.append((time, lane))

    if not timestamps: return 0

    timestamps.sort()
    window = 1000
    left = 0
    cps_values = []
    for right in range(len(timestamps)):
        while timestamps[right] - timestamps[left] > window:
            left += 1
        cps_values.append((right - left + 1))

    avg_cps = sum(cps_values) / len(cps_values)
    peak_cps = max(cps_values)

    rating = (peak_cps * 5) + (avg_cps * 2)
    return round(rating, 2)

def get_difficulty_face(rating):
    if rating < 30: return "Easy"
    if rating < 60: return "Medium"
    if rating < 100: return "Hard"
    if rating < 130: return "Insane"
    if rating < 150: return "Easy Demon"
    if rating < 180: return "Medium Demon"
    if rating < 220: return "Hard Demon"
    if rating < 250: return "Insane Demon"
    return "Extreme Demon"


# ==========================================
# DATABASE SETUP
# ==========================================
def init_db():
    conn = sqlite3.connect(USER_DB)
    cur = conn.cursor()
    cur.execute("""
        CREATE TABLE IF NOT EXISTS users(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            username TEXT UNIQUE, password TEXT, token TEXT, rating REAL DEFAULT 0
        )
    """)
    cur.execute("""
        CREATE TABLE IF NOT EXISTS user_scores(
            username TEXT, chart_id TEXT, best_accuracy REAL, PRIMARY KEY(username, chart_id)
        )
    """)
    cur.execute("""
        CREATE TABLE IF NOT EXISTS chart_likes(
            username TEXT, chart_id TEXT, PRIMARY KEY(username, chart_id)
        )
    """)
    cur.execute("""
        CREATE TABLE IF NOT EXISTS chart_comments(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            chart_id TEXT,
            username TEXT,
            comment TEXT,
            timestamp DATETIME DEFAULT CURRENT_TIMESTAMP
        )
    """)
    conn.commit()
    conn.close()


init_db()

class LikeData(BaseModel):
    username: str
    token: str
    chart_id: str

@app.post("/like_chart")
async def like_chart(data: LikeData):
    if verify_token(data.token) != data.username:
        raise HTTPException(status_code=401, detail="Invalid Session")

    conn = sqlite3.connect(USER_DB)
    cur = conn.cursor()

    cur.execute("SELECT 1 FROM chart_likes WHERE username=? AND chart_id=?", (data.username, data.chart_id))
    if cur.fetchone():
        cur.execute("DELETE FROM chart_likes WHERE username=? AND chart_id=?", (data.username, data.chart_id))
        action = "unliked"
    else:
        cur.execute("INSERT INTO chart_likes (username, chart_id) VALUES (?, ?)", (data.username, data.chart_id))
        action = "liked"

    conn.commit()

    cur.execute("SELECT COUNT(*) FROM chart_likes WHERE chart_id=?", (data.chart_id,))
    total_likes = cur.fetchone()[0]
    conn.close()

    return {"status": action, "likes": total_likes}

def load_mat_db():
    if not os.path.exists(DB_FILE): return {}
    with open(DB_FILE, "r") as f: return json.load(f)

def save_mat_db(data):
    with open(DB_FILE, "w") as f: json.dump(data, f, indent=4)


# ==========================================
# AUTHENTICATION UTILS
# ==========================================
class UserAuth(BaseModel):
    username: str
    password: str

class TokenData(BaseModel):
    token: str

import bcrypt

def hash_password(password: str):
    pw_hash = hashlib.sha256(password.encode()).hexdigest().encode()
    return bcrypt.hashpw(pw_hash, bcrypt.gensalt()).decode()

def verify_password(password: str, hashed):
    pw_hash = hashlib.sha256(password.encode()).hexdigest().encode()
    if isinstance(hashed, str):
        hashed = hashed.encode()
    return bcrypt.checkpw(pw_hash, hashed)

def create_access_token(username: str):
    expire = datetime.utcnow() + timedelta(days=TOKEN_EXPIRE_DAYS)
    return jwt.encode({"sub": username, "exp": expire}, SECRET_KEY, algorithm=ALGORITHM)

def verify_token(token: str):
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        return payload.get("sub")
    except JWTError:
        return None


# ==========================================
# ROUTES: AUTHENTICATION
# ==========================================
class CommentData(BaseModel):
    username: str
    token: str
    chart_id: str
    comment: str

@app.post("/post_comment")
@limiter.limit("5/minute")
async def post_comment(request: Request, data: CommentData):
    if verify_token(data.token) != data.username:
        raise HTTPException(status_code=401, detail="Invalid Session")

    if len(data.comment.strip()) == 0 or len(data.comment) > 150:
        return {"status": "error", "message": "Comment must be 1-150 characters."}

    bans = load_bans()
    if data.username in bans["users"]:
        raise HTTPException(status_code=403, detail="You are banned from commenting.")

    conn = sqlite3.connect(USER_DB)
    cur = conn.cursor()
    cur.execute("INSERT INTO chart_comments (chart_id, username, comment) VALUES (?, ?, ?)",
                (data.chart_id, data.username, data.comment.strip()))
    conn.commit()
    conn.close()
    return {"status": "success"}

@app.get("/get_comments/{chart_id}")
async def get_comments(chart_id: str):
    conn = sqlite3.connect(USER_DB)
    cur = conn.cursor()
    cur.execute("SELECT username, comment, timestamp FROM chart_comments WHERE chart_id=? ORDER BY timestamp DESC LIMIT 50", (chart_id,))
    rows = cur.fetchall()
    conn.close()
    return [{"user": r[0], "text": r[1], "time": r[2].split(" ")[0]} for r in rows]

@app.post("/register")
@limiter.limit("3/minute")
async def register(request: Request, user: UserAuth):
    conn = sqlite3.connect(USER_DB)
    cur = conn.cursor()
    cur.execute("SELECT id FROM users WHERE username=?", (user.username,))
    if cur.fetchone():
        conn.close()
        raise HTTPException(status_code=400, detail="User already exists")

    hashed = hash_password(user.password)
    cur.execute("INSERT INTO users (username, password) VALUES (?,?)", (user.username, hashed))
    conn.commit()
    conn.close()
    return {"success": True, "token": create_access_token(user.username), "username": user.username}

@app.post("/login")
async def login(user: UserAuth):
    conn = sqlite3.connect(USER_DB)
    cur = conn.cursor()
    cur.execute("SELECT password FROM users WHERE username=?", (user.username,))
    row = cur.fetchone()
    conn.close()

    if not row or not verify_password(user.password, row[0]):
        raise HTTPException(status_code=401, detail="Invalid credentials")

    return {"success": True, "token": create_access_token(user.username), "username": user.username}

@app.post("/token_login")
async def token_login(data: TokenData):
    username = verify_token(data.token)
    if not username:
        raise HTTPException(status_code=401, detail="Invalid session")
    return {"success": True, "token": data.token, "username": username}


# ==========================================
# ROUTES: CHARTS (SONGS)
# ==========================================
@limiter.limit("5/minute")
@app.get("/charts")
async def list_charts(q: str = "", username: str = "", request: Request = None):
    db = load_chart_db()
    results = list(db.values())

    conn = sqlite3.connect(USER_DB)
    cur = conn.cursor()

    cur.execute("SELECT chart_id, COUNT(*) FROM chart_likes GROUP BY chart_id")
    likes_dict = {row[0]: row[1] for row in cur.fetchall()}

    completed_set = set()
    if username:
        cur.execute("SELECT chart_id FROM user_scores WHERE username=? AND best_accuracy > 0", (username,))
        completed_set = {row[0] for row in cur.fetchall()}

    conn.close()

    for v in results:
        v['likes'] = likes_dict.get(v['id'], 0)
        v['desc'] = v.get('desc', 'No description provided.')
        v['completed'] = v['id'] in completed_set

    if q:
        query = q.lower()
        results = [v for v in results if query in v['name'].lower() or query in v.get('author', '').lower()]

    results.sort(
        key=lambda x: (
            not x.get('featured', False),
            x.get('status') != 'verified',
            -x.get('likes', 0),
            x['name']
        )
    )
    return results

@app.get("/admin/bans")
async def get_bans(secret: str):
    check_admin(secret)
    return load_bans()

@app.post("/admin/ban_item")
async def ban_item(type: str, value: str, secret: str):
    """type can be 'ips' or 'users'"""
    check_admin(secret)
    bans = load_bans()
    if type in bans and value not in bans[type]:
        bans[type].append(value)
        save_bans(bans)
        return {"status": f"Banned {value}"}
    return {"status": "Already banned or invalid type"}

# ==========================================
# ADMIN: UNBAN ROUTES
# ==========================================
@app.post("/admin/unban_item")
async def unban_item(type: str, value: str, secret: str):
    """
    Remove a user or IP from the ban list.
    type can be 'ips' or 'users'
    """
    check_admin(secret)
    bans = load_bans()
    if type not in bans:
        raise HTTPException(status_code=400, detail="Invalid ban type. Use 'ips' or 'users'.")
    if value not in bans[type]:
        return {"status": f"{value} is not currently banned"}
    bans[type].remove(value)
    save_bans(bans)
    return {"status": f"Unbanned {value}"}

@app.post("/admin/unban_all")
async def unban_all(type: str, secret: str):
    """
    Clear the entire IP or user ban list.
    type can be 'ips' or 'users'
    """
    check_admin(secret)
    bans = load_bans()
    if type not in bans:
        raise HTTPException(status_code=400, detail="Invalid type. Use 'ips' or 'users'.")
    count = len(bans[type])
    bans[type] = []
    save_bans(bans)
    return {"status": f"Cleared {count} entries from {type} ban list"}

# ==========================================
# ADMIN: TEMPBAN ROUTES
# ==========================================
@app.post("/admin/tempban")
async def tempban_item(target: str, minutes: int, secret: str, reason: str = ""):
    """
    Temporarily ban a username OR IP address for a given number of minutes.
    target: username or IP string
    minutes: ban duration (must be > 0)
    reason: optional human-readable reason shown to the banned user
    """
    check_admin(secret)
    if minutes <= 0:
        raise HTTPException(status_code=400, detail="Duration must be greater than 0 minutes.")
    entry = add_tempban(target, minutes, reason)
    return {
        "status": f"Tempbanned {target}",
        "expires_at": entry["expires_at"],
        "duration_minutes": minutes,
        "reason": reason
    }

@app.post("/admin/untimeban")
async def untimeban_item(target: str, secret: str):
    """Lift a tempban early for a username or IP."""
    check_admin(secret)
    removed = remove_tempban(target)
    if removed:
        return {"status": f"Tempban lifted for {target}"}
    return {"status": f"{target} was not tempbanned"}

@app.get("/admin/tempbans")
async def get_tempbans(secret: str):
    """List all currently active tempbans with remaining time."""
    check_admin(secret)
    return list_tempbans()

# ==========================================
# ADMIN: BACKUP
# ==========================================
@app.get("/admin/backup")
async def create_backup(secret: str):
    check_admin(secret)

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_filename = f"backup_{timestamp}"
    backup_path = f"backups/{backup_filename}"

    os.makedirs("backups", exist_ok=True)

    temp_dir = f"temp_backup_{timestamp}"
    os.makedirs(temp_dir, exist_ok=True)

    try:
        shutil.copy(USER_DB, temp_dir)
        shutil.copy(CHARTS_DB, temp_dir)
        shutil.copy(DB_FILE, temp_dir)
        shutil.copy(BANS_FILE, temp_dir)

        shutil.make_archive(backup_path, 'zip', temp_dir)
        shutil.rmtree(temp_dir)

        return FileResponse(f"{backup_path}.zip", filename=f"{backup_filename}.zip")
    except Exception as e:
        if os.path.exists(temp_dir): shutil.rmtree(temp_dir)
        raise HTTPException(500, detail=str(e))

# ==========================================
# USER PROFILE
# ==========================================
@app.get("/user/profile/{username}")
async def get_profile(username: str):
    conn = sqlite3.connect(USER_DB)
    cur = conn.cursor()

    cur.execute("SELECT rating FROM users WHERE username=?", (username,))
    row = cur.fetchone()
    if not row: raise HTTPException(404, "User not found")
    rating = row[0]

    cur.execute("SELECT COUNT(*) FROM users WHERE rating > ?", (rating,))
    rank = cur.fetchone()[0] + 1

    cur.execute("""
        SELECT chart_id, best_accuracy FROM user_scores 
        WHERE username=? ORDER BY best_accuracy DESC LIMIT 1
    """, (username,))
    best_play = cur.fetchone()
    best_play_data = {"song": best_play[0], "acc": round(best_play[1], 2)} if best_play else None

    conn.close()
    return {
        "username": username,
        "stars": round(rating, 1),
        "rank": rank,
        "best_play": best_play_data
    }

@app.get("/admin/feature")
def feature_song(id: str, secret: str):
    check_admin(secret)
    db = load_chart_db()
    if id in db:
        db[id]["featured"] = True
        save_chart_db(db)
        return {"status": "featured!"}
    return {"error": "not found"}

@app.get("/admin/rate")
def rate_level(id: str, rating: float, featured: bool, secret: str):
    check_admin(secret)
    db = load_chart_db()
    if id in db:
        db[id]["manual_rating"] = rating
        db[id]["featured"] = featured
        db[id]["status"] = "verified"
        save_chart_db(db)
        return {"status": "success"}
    raise HTTPException(404)

def load_chart_db():
    if not os.path.exists(CHARTS_DB): return {}
    with open(CHARTS_DB, "r") as f: return json.load(f)

def save_chart_db(data):
    with open(CHARTS_DB, "w") as f: json.dump(data, f, indent=4)

@app.post("/upload_chart")
@limiter.limit("2/minute")
async def upload_chart(request: Request):
    content_length = request.headers.get('content-length')
    if content_length and int(content_length) > 5 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="Chart ZIP too large (Max 5MB)")

    name = request.headers.get("Chart-Name")
    if not name:
        raise HTTPException(status_code=400, detail="Chart-Name header is required")

    # FIX: Load db BEFORE referencing it
    db = load_chart_db()

    if name.replace(" ", "-").lower() in db:
        raise HTTPException(status_code=400, detail="A chart with this name already exists.")

    author = request.headers.get("Author-Name", "unknown")
    desc = request.headers.get("Chart-Desc", "No description provided.")
    bans = load_bans()
    if author in bans["users"]:
        raise HTTPException(status_code=403, detail="You are banned from uploading.")

    data = await request.body()
    path = os.path.join(UPLOAD_DIR, f"{name}.zip")

    with open(path, "wb") as f:
        f.write(data)

    rating = 0
    try:
        z = zipfile.ZipFile(io.BytesIO(data))
        json_file = [f for f in z.namelist() if f.endswith('.json')][0]
        chart_data = json.loads(z.read(json_file))
        rating = analyze_difficulty(chart_data)
    except:
        print("Analysis failed, setting to 0")

    db[name] = {
        "id": name, "name": name.replace("-", " ").title(), "author": author,
        "desc": desc,
        "suggested_rating": rating, "manual_rating": None, "status": "pending"
    }
    save_chart_db(db)

    return {"status": "ok", "suggested": rating}

@app.delete("/admin/chart/{chart_id}")
async def delete_chart(chart_id: str, secret: str):
    check_admin(secret)
    db = load_chart_db()
    if chart_id in db:
        del db[chart_id]
        save_chart_db(db)
        path = os.path.join(UPLOAD_DIR, f"{chart_id}.zip")
        if os.path.exists(path): os.remove(path)
        return {"status": "deleted"}
    raise HTTPException(404)

@app.delete("/admin/material/{mat_id}")
async def delete_material(mat_id: str, secret: str):
    check_admin(secret)
    db = load_mat_db()
    if mat_id in db:
        del db[mat_id]
        save_mat_db(db)
        return {"status": "deleted"}
    raise HTTPException(404)

@app.get("/download_chart")
async def download_chart(id: str):
    path = os.path.join(UPLOAD_DIR, f"{id}.zip")
    if not os.path.exists(path): raise HTTPException(404, "Chart not found")
    return FileResponse(path, media_type="application/zip", filename=f"{id}.zip")

class ScoreData(BaseModel):
    username: str
    token: str
    chart_id: str
    accuracy: float

@app.post("/submit_score")
async def submit_score(data: ScoreData):
    if verify_token(data.token) != data.username:
        raise HTTPException(status_code=401, detail="Invalid Session")

    db = load_chart_db()
    if data.chart_id not in db: raise HTTPException(404)

    chart = db[data.chart_id]
    if chart.get("status") != "verified":
        return {"status": "ignored", "message": "Chart not verified"}

    bans = load_bans()
    if data.username in bans["users"]:
        raise HTTPException(status_code=403, detail="You are banned.")

    chart_val = chart.get("manual_rating", 0)

    conn = sqlite3.connect(USER_DB)
    cur = conn.cursor()

    cur.execute("SELECT best_accuracy FROM user_scores WHERE username=? AND chart_id=?", (data.username, data.chart_id))
    row = cur.fetchone()
    old_acc = row[0] if row else 0

    if data.accuracy > old_acc:
        improvement = data.accuracy - old_acc
        earned_points = (chart_val * (improvement / 100.0))

        cur.execute("UPDATE users SET rating = rating + ? WHERE username = ?", (earned_points, data.username))
        cur.execute("INSERT OR REPLACE INTO user_scores (username, chart_id, best_accuracy) VALUES (?, ?, ?)",
                    (data.username, data.chart_id, data.accuracy))
        conn.commit()
        conn.close()
        return {"status": "success", "earned": round(earned_points, 2), "new_best": True}

    conn.close()
    return {"status": "success", "earned": 0, "new_best": False, "message": "No improvement over personal best"}

@app.get("/leaderboard/players")
async def get_player_leaderboard():
    conn = sqlite3.connect(USER_DB)
    cur = conn.cursor()
    cur.execute("SELECT username, rating FROM users ORDER BY rating DESC LIMIT 50")
    rows = cur.fetchall()
    conn.close()
    return [{"username": r[0], "rating": round(r[1], 1)} for r in rows]

@app.get("/charts/search")
def search_charts(q: str = ""):
    db = load_chart_db()
    results = []
    query = q.lower()
    for cid, data in db.items():
        if query in cid.lower() or query in data.get("desc", "").lower():
            results.append(data)
    return results


# ==========================================
# ROUTES: MATERIALS
# ==========================================
@app.get("/materials/search")
async def search_materials(q: str = ""):
    db = load_mat_db()
    query = q.lower()
    return [data for mid, data in db.items() if query in mid.lower() or query in data.get("desc", "").lower()]

@app.post("/upload_material_package")
@limiter.limit("2/minute")
async def upload_material_package(request: Request):
    content_length = request.headers.get('content-length')
    if content_length and int(content_length) > 25 * 1024 * 1024:
        raise HTTPException(status_code=413, detail="Material package too large (Max 25MB)")

    material_name = request.headers.get("Material-Name", "unknown")
    desc = request.headers.get("Material-Desc", "No description")
    author = request.headers.get("Author-Name", "unknown")
    bans = load_bans()
    if author in bans["users"]:
        raise HTTPException(status_code=403, detail="You are banned from uploading.")

    db = load_mat_db()
    if material_name in db:
        raise HTTPException(status_code=409, detail="Material already exists")

    data = await request.body()
    try:
        z = zipfile.ZipFile(io.BytesIO(data))
        for filename in z.namelist():
            if ".." in filename or filename.startswith("/"): continue

            full_path = os.path.join(ASSET_ROOT + "/notyetaccepted", filename)
            os.makedirs(os.path.dirname(full_path), exist_ok=True)

            with open(full_path, "wb") as f:
                f.write(z.read(filename))

        db[material_name] = {"id": material_name, "desc": desc, "files": len(z.namelist())}
        save_mat_db(db)
        return {"status": "ok", "message": f"Material {material_name} installed"}
    except Exception as e:
        raise HTTPException(500, f"Extraction failed: {str(e)}")


# ==========================================
# ROUTES: ASSET SERVING
# ==========================================
@app.get("/assets/{file_path:path}")
async def get_asset(file_path: str):
    clean_path = file_path.replace("assets/", "", 1)
    full = os.path.join(ASSET_ROOT, clean_path.replace("/", "\\"))

    if not os.path.exists(full):
        print(f"FAILED TO FIND: {full}")
        raise HTTPException(status_code=404, detail="File not found")

    return FileResponse(full)


# ==========================================
# LISTS
# ==========================================
LISTS_DB = "lists_db.json"

def load_lists_db():
    if not os.path.exists(LISTS_DB): return {}
    with open(LISTS_DB, "r") as f: return json.load(f)

def save_lists_db(data):
    with open(LISTS_DB, "w") as f: json.dump(data, f, indent=4)

@app.get("/lists")
async def get_lists(q: str = ""):
    db = load_lists_db()
    results = list(db.values())
    if q:
        query = q.lower()
        results = [l for l in results if query in l['name'].lower() or query in l.get('author', '').lower()]
    return results

@app.post("/upload_list")
async def upload_list(request: Request):
    data = await request.json()
    author = request.headers.get("Author-Name", "unknown")
    bans = load_bans()
    if author in bans["users"]:
        raise HTTPException(status_code=403, detail="You are banned from uploading.")
    db = load_lists_db()
    db[data['id']] = data
    save_lists_db(db)
    return {"status": "ok"}

@app.delete("/admin/list/{list_id}")
async def delete_list(list_id: str, secret: str):
    check_admin(secret)
    db = load_lists_db()
    if list_id in db:
        del db[list_id]
        save_lists_db(db)
        return {"status": "deleted"}
    raise HTTPException(404)

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)