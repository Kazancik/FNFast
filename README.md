# ⚡ FNFast Engine
> **See it. Beat it. Lead it.**

FNFast is an advanced online ecosystem for Friday Night Funkin' built on the Psych Engine. It introduces a live-streaming asset system (CDN), global leaderboards, and an in-game community browser.

## 🚀 Features
- **Centralized Browser:** Discover and download community-made charts and playlists instantly.
- **Asset CDN:** High-speed streaming for characters, stages, and scripts.
- **Global Ranking:** Compete on a verified leaderboard with anti-farming logic.
- **Creator Hub:** One-click publishing directly from the Chart Editor.
## Join us!
Join our discord [here](https://discord.gg/yzucpYzxEX)

## 🛠️ Installation (Client)
1. Clone the repo.
2. Run `lime test windows` to compile.
3. The client will automatically discover the current active server.

## 🖥️ Installation (Server)
1. Follow the discovery server setup guide [here](https://github.com/Kazancik/FNFastServer)
2. Install dependencies
3. Create a `secret.txt` and `admin.py` and add your admin password.
4. Run: `uvicorn main:app --host 0.0.0.0 --port 8000`.

## 📜 Credits
- **Psych Engine Team:** The foundation of this fork.
- **Kazancik:** I added all online features.
