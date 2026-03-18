import json
from collections import defaultdict


WINDOW_MS = 1000  # CPS window


class ChartStats:
    def __init__(self):
        self.notes = []      # NEW
        self.timestamps = []
        self.chords = []
        self.hurt_notes = 0
        self.song_length = 0



# -----------------------------
# LOAD CHART (auto format detect)
# -----------------------------
def load_chart(path):
    with open(path, "r", encoding="utf-8") as f:
        data = json.load(f)

    if isinstance(data.get("song"), dict):
        return data["song"]

    return data


# -----------------------------
# ANALYZE
# -----------------------------
def analyze_chart(path):
    data = load_chart(path)

    if "notes" not in data:
        raise ValueError("Invalid chart: missing notes")

    stats = ChartStats()
    grouped = defaultdict(list)

    last_time = 0

    for section in data["notes"]:
        must_hit = section.get("mustHitSection", True)

        for note in section.get("sectionNotes", []):
            time = float(note[0])
            lane = int(note[1])

            # Player notes only
            if not must_hit:
                continue

            stats.timestamps.append(time)
            stats.notes.append((time, lane))

            grouped[time].append(lane)

            if len(note) >= 4 and note[3] == "Hurt Note":
                stats.hurt_notes += 1

            last_time = max(last_time, time)

    # chord detection
    for t, lanes in grouped.items():
        stats.chords.append(len(lanes))

    stats.song_length = last_time / 1000
    return stats
def sliding_cps(timestamps, window_ms=1000):
    timestamps.sort()

    cps_values = []
    left = 0

    for right in range(len(timestamps)):
        while timestamps[right] - timestamps[left] > window_ms:
            left += 1

        count = right - left + 1
        cps_values.append(count / (window_ms / 1000))

    return cps_values

def jack_density(notes, threshold_ms=150):
    """
    Detects rapid same-lane repetitions.
    """
    if len(notes) < 2:
        return 0

    notes.sort()
    jacks = 0

    for i in range(1, len(notes)):
        t1, lane1 = notes[i - 1]
        t2, lane2 = notes[i]

        if lane1 == lane2 and (t2 - t1) <= threshold_ms:
            jacks += 1

    return jacks / len(notes)
def skill_analysis(stats, cps_curve):
    avg_cps = sum(cps_curve) / len(cps_curve) if cps_curve else 0
    peak_cps = max(cps_curve) if cps_curve else 0

    jack_score = jack_density(stats.notes)

    speed = peak_cps
    stamina = avg_cps
    accuracy = stats.hurt_notes * 0.5
    jack_skill = jack_score * 20

    return {
        "speed": speed,
        "stamina": stamina,
        "accuracy": accuracy,
        "jack_skill": jack_skill
    }

def sustained_peak(values, sustain=20):
    """
    Finds hardest sustained difficulty,
    not just single spike.
    """
    if not values:
        return 0

    best = 0
    for i in range(len(values) - sustain):
        avg = sum(values[i:i+sustain]) / sustain
        best = max(best, avg)

    return best


def difficulty_metrics(stats):
    cps_curve = sliding_cps(stats.timestamps)

    avg_cps = sum(cps_curve) / len(cps_curve) if cps_curve else 0
    peak_cps = max(cps_curve) if cps_curve else 0
    sustain_cps = sustained_peak(cps_curve)

    # chord difficulty bonus
    chord_factor = sum(stats.chords) / max(len(stats.chords), 1)

    hurt_penalty = stats.hurt_notes * 0.03

    min_cps_win = sustain_cps * 0.8 + hurt_penalty
    min_cps_fc = peak_cps * 0.9 + chord_factor * 0.2 + hurt_penalty
    skills = skill_analysis(stats, cps_curve)

    rating = (
        skills["speed"] * 5 +
        skills["stamina"] * 4 +
        skills["jack_skill"] * 3 +
        skills["accuracy"]
    )


    return {
        "avg_cps": avg_cps,
        "peak_cps": peak_cps,
        "sustain_cps": sustain_cps,
        "min_cps_win": min_cps_win,
        "min_cps_fc": min_cps_fc,
        "rating": rating,
        "skills": skills,
        "hurt_notes": stats.hurt_notes
    }


import matplotlib.pyplot as plt


def cps_timeline(timestamps, window_ms=1000, step_ms=100):
    """
    Returns time-series CPS values.
    """
    if not timestamps:
        return [], []

    timestamps.sort()

    start = 0
    end = int(timestamps[-1])

    times = []
    cps_values = []

    left = 0
    right = 0

    for t in range(start, end, step_ms):

        while left < len(timestamps) and timestamps[left] < t:
            left += 1

        while right < len(timestamps) and timestamps[right] < t + window_ms:
            right += 1

        cps = (right - left) / (window_ms / 1000)

        times.append(t / 1000)
        cps_values.append(cps)

    return times, cps_values


def plot_difficulty(times, cps_values, title="Difficulty Graph"):
    plt.figure()

    plt.plot(times, cps_values)

    plt.xlabel("Time (seconds)")
    plt.ylabel("CPS")
    plt.title(title)

    plt.show()


LIST_FILE = "demonlist.json"


def save_demonlist(levels):
    with open(LIST_FILE, "w", encoding="utf-8") as f:
        json.dump(levels, f, indent=4)


def build_entry(name, metrics):
    return {
        "name": name,
        "rating": metrics["rating"],
        "min_cps_fc": metrics["min_cps_fc"],
        "min_cps_win": metrics["min_cps_win"],
        "skills": metrics["skills"]
    }
import os


DEMONLIST_FOLDER = "demonlist"


def analyze_all():
    levels = []

    for file in os.listdir(DEMONLIST_FOLDER):

        if not file.endswith(".json"):
            continue

        path = os.path.join(DEMONLIST_FOLDER, file)
        level_name = os.path.splitext(file)[0]

        print(f"Analyzing: {level_name}")

        try:
            stats = analyze_chart(path)
            metrics = difficulty_metrics(stats)

            entry = build_entry(level_name, metrics)
            levels.append(entry)

        except Exception as e:
            print(f"Failed {file}: {e}")

    # sort hardest → easiest
    levels.sort(key=lambda x: x["rating"], reverse=True)

    save_demonlist(levels)

    print("\n✅ Demonlist rebuilt!")
    print(f"Levels analyzed: {len(levels)}")


if __name__ == "__main__":
    analyze_all()
from flask import Flask, render_template, request, jsonify
import json

app = Flask(__name__)

LIST_FILE = "demonlist.json"


def load_list():
    try:
        with open(LIST_FILE, "r", encoding="utf-8") as f:
            return json.load(f)
    except:
        return []


def save_list(data):
    with open(LIST_FILE, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=4)


@app.route("/")
def index():
    levels = load_list()
    return render_template("index.html", levels=levels)


@app.route("/save_order", methods=["POST"])
def save_order():
    new_order = request.json
    save_list(new_order)
    return jsonify({"status": "ok"})


if __name__ == "__main__":
    app.run(debug=True)
