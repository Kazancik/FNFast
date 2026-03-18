import base64
import gzip
import os
import random
import xml.etree.ElementTree as ET
from collections import defaultdict
import kagglehub
# --- CONFIGURATION ---
path = kagglehub.dataset_download("hudsonston/geometry-dash-levels") 
DATASET = path 
print(os.listdir(DATASET))

GAMEPLAY_IDS = {1, 8, 12, 35, 36, 39, 67, 103, 104, 110, 115}

def safe_parse_token(token):
    try:
        parts = token.split(":")
        return int(parts[0]), int(parts[1]), int(parts[2])
    except: return None

def decode_level_data(data):
    try:
        data = data.replace("-", "+").replace("_", "/")
        missing = len(data) % 4
        if missing: data += "=" * (4 - missing)
        return gzip.decompress(base64.b64decode(data)).decode("utf-8")
    except: return ""

def parse_objects(level_string):
    objects = []
    # Geometry Dash levels are often semicolon separated
    for obj in level_string.split(";"):
        if not obj: continue
        parts = obj.split(",")
        # Key 1=ID, 2=X, 3=Y
        data = {}
        for i in range(0, len(parts)-1, 2):
            data[parts[i]] = parts[i+1]
        if "1" in data and "2" in data and "3" in data:
            x = int(float(data["2"])) // 30
            y = int(float(data["3"])) // 15
            objects.append(f"{data['1']}:{x}:{y}")
    return objects

def to_relative(tokens):
    # CRITICAL: Sort by X coordinate
    tokens.sort(key=lambda t: safe_parse_token(t)[1])
    rel = []
    for i in range(1, len(tokens)):
        o1, x1, y1 = safe_parse_token(tokens[i-1])
        o2, x2, y2 = safe_parse_token(tokens[i])
        # Limit the dx/dy to prevent wild jumps
        dx = max(-10, min(10, x2 - x1))
        dy = max(-5, min(5, y2 - y1))
        rel.append(f"{o2}:{dx}:{dy}")
    return rel

# --- DATA LOADING ---
sequences = []
if not os.path.exists(DATASET):
    print(f"Error: Folder '{DATASET}' not found!")
else:
    files = [f for f in os.listdir(DATASET) if f.endswith(".gmd")]
    print(f"Found {len(files)} files in {DATASET}...")
    
    for file in files:
        with open(os.path.join(DATASET, file), "r", encoding="utf-8", errors="ignore") as f:
            content = f.read()
            # Simple extraction for GMD files
            lvl = decode_level_data(content.split("k4</k><s>")[-1].split("</s>")[0])
            tokens = [t for t in parse_objects(lvl) if int(t.split(":")[0]) in GAMEPLAY_IDS]
            if len(tokens) > 10:
                sequences.append(to_relative(tokens))

print(f"Training on {len(sequences)} levels...")

if not sequences:
    print("FATAL: No valid level data found to train on. Check your DATASET folder.")
    exit()

# --- BRAIN BUILDING ---
brain = defaultdict(list)
for seq in sequences:
    for i in range(len(seq)-3):
        brain[tuple(seq[i:i+3])].append(seq[i+3])

def generate_sequence(brain, length=200):
    if not brain: return []
    state = random.choice(list(brain.keys()))
    result = list(state)
    for _ in range(length):
        state_key = tuple(result[-3:])
        choices = brain.get(state_key, [])
        if not choices:
            state_key = random.choice(list(brain.keys()))
            choices = brain[state_key]
        result.append(random.choice(choices))
    return result

# --- GENERATE ---
rel_tokens = generate_sequence(brain, 300)

# Build XML output
final_objs = []
x, y = 300, 150 # Start position
for rt in rel_tokens:
    obj, dx, dy = safe_parse_token(rt)
    x += dx * 30
    y += dy * 15
    final_objs.append(f"1,{obj},2,{x},3,{y}")

xml_content = ";".join(final_objs)

# --- CORRECTED XML WRITING ---
LEVEL_NAME = "GeneratedLevel"
CREATOR = "AI_Bot"

xml_string = f'''<?xml version="1.0"?>
<plist version="1.0" gjver="2.0">
<dict>
    <k>kCEK</k><i>4</i>
    <k>k2</k><s>{LEVEL_NAME}</s>
    <k>k4</k><s>{xml_content}</s>
    <k>k5</k><s>{CREATOR}</s>
    <k>k101</k><s>0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0</s>
    <k>k13</k><t/>
    <k>k21</k><i>2</i>
    <k>k16</k><i>1</i>
    <k>k80</k><i>84</i>
    <k>k83</k><i>611</i>
    <k>k50</k><i>42</i>
    <k>k47</k><t/>
    <k>k48</k><i>4</i>
    <k>kI1</k><r>172.789</r>
    <k>kI2</k><r>14.3704</r>
    <k>kI3</k><r>1.2</r>
</dict>
</plist>'''

with open("GeneratedLevel.gmd", "w") as f:
    f.write(xml_string)

print("Success! Created GeneratedLevel.gmd")