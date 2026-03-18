


#  FNFast Engine
> **See it. Beat it. Lead it.**

FNFast is an advanced, live-service ecosystem for Friday Night Funkin' built on the foundation of Psych Engine. It revolutionizes content delivery by introducing **Dynamic Asset Streaming (CDN)**, global leaderboards, and an in-game community repository.

---

##  Why FNFast?

Traditional FNF mods require downloading gigabytes of data just to play a single song. FNFast changes the game:

- **Instant Discovery:** Open the Online Browser, find a chart, and play instantly. 
- **Dynamic Asset CDN:** Missing a character or stage? FNFast streams required `.material` files on-the-fly and caches them locally.
- **Unified Creator Hub:** Package, upload, and publish your charts and materials directly from the in-game editor.
- **Competitive Integrity:** Every verified chart has an objective Star Rating. Earn rank by improving your personal best accuracy.

---

## 🛠️ Features

### See it
- **Global Browser:** Tabbed interface for individual Charts and curated Playlists (Weeks).
- **Featured System:** Curated high-quality content highlighted with custom UI styling.
- **Search:** Instant filtering by song name or author.

### Beat it
- **Difficulty Analysis:** Automated CPS (Notes per second) and Jack-density analysis for objective ratings.
- **Story Mode Integration:** Downloaded playlists automatically appear as playable weeks in Story Mode.
- **Script & Dialogue Support:** Full support for Lua events and dialogue boxes delivered via the streaming pipeline.

### Lead it
- **Global Leaderboard:** Star-based ranking system with anti-farming logic.
- **Admin Dashboard:** Standalone moderation tool for verifying, featuring, or deleting content.

---
## Want to join us?

We have a discord server so you can chat and also understand how to get the bestout of FNFast click [here](https://discord.gg/XQ8SMCrmhH) to join

## 🖥️ Server Setup (For Hosters)

If you want to host your own FNFast private server (please mod the link like [here](https://github.com/Kazancik/FNFastServer):

1. **Navigate to the server folder:**
   ```bash
   cd fnfast-server
   ```
2. **Install Dependencies:**
   ```bash
   pip install -r requirements.txt
   ```
3. **Set Security:**
   Create a `secret.txt and password.txt` file in the folder and put your admin passwords inside.
4. **Run the Server:**
   ```bash
   uvicorn main:app --host 0.0.0.0 --port 8000
   ```
5. **Manage:**
   Run `python admin_dashboard.py` in a separate window to manage uploads.

---

## 🎮 Client Setup (For Modders)

1. Clone this repository.
2. Install the Haxe/Flixel dependencies (Standard Psych Engine setup).
3. **Server Discovery:** FNFast uses an encrypted bootstrap system. Update `OnlineManager.hx` with your discovery URL.
4. **Compile:**
   ```bash
   lime test windows
   ```

---

## Security

- **Moderation:** Built-in IP and Username banning system to keep the community safe.

---




## 📜 Credits

- **Psych Engine Team:** For the incredible foundation.

---

## ⚖️ License & Legal

This project is licensed under the MIT License. Please see `LEGAL.md` for our DMCA policy and user-generated content disclaimers.



