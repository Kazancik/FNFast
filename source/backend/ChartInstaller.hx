package backend;

import sys.io.File;
import sys.FileSystem;
import haxe.zip.Reader;
import haxe.io.Bytes;
import haxe.io.BytesInput;
import haxe.Json;

class ChartInstaller
{
    public static function install(songName:String, zipPath:String)
    {
        var base = "assets/shared/";

        var songsPath = "assets/songs/" + songName + "/"; 
        var dataPath  = base + "data/" + songName + "/";

        createDir(base + "songs/");
        createDir(base + "data/");
        createDir(songsPath);
        createDir(dataPath);

        var input = File.read(zipPath);
        var reader = new Reader(input);
        var entries = reader.read();

        for (entry in entries)
        {
            var filename = entry.fileName.toLowerCase();
            var bytes = Reader.unzip(entry);

            if (filename.endsWith(".json"))
            {
                // SMART JSON SAVING: Don't rename dialogue or events
                if (filename.indexOf("dialogue") != -1) {
                    File.saveBytes(dataPath + songName + "-dialogue.json", bytes);
                } else if (filename.indexOf("events") != -1) {
                    File.saveBytes(dataPath + "events.json", bytes);
                } else {
                    // Standard chart file
                    File.saveBytes(dataPath + songName + "-normal.json", bytes);
                }
            }
            else if (filename.indexOf("inst") != -1)
            {
                File.saveBytes(songsPath + "Inst.ogg", bytes);
            }
            else if (filename.indexOf("voices") != -1)
            {
                File.saveBytes(songsPath + "Voices.ogg", bytes);
            }
        }
        input.close();
        trace("Chart installed: " + songName);

        // --- NEW: ADD TO FREEPLAY AUTO-WEEK ---
        addToFreeplayWeek(songName);
    }

    public static function createDir(path:String)
    {
        if (!FileSystem.exists(path))
            FileSystem.createDirectory(path);
    }

    // --- PLAYLIST GENERATOR (Visible in Story Mode) ---
    public static function createWeekFile(weekName:String, songList:Array<String>)
    {
        var weekDir = "assets/shared/weeks/"; 
        if (!FileSystem.exists(weekDir)) FileSystem.createDirectory(weekDir);

        var songEntries:Array<Dynamic> = [];
        for (song in songList) {
            songEntries.push([song, "face", [146, 113, 253]]);
        }

        var weekData:Dynamic = {
            songs: songEntries,
            hideStoryMode: false,
            hideFreeplay: false,
            weekBackground: "stage",
            difficulties: "normal",
            weekCharacters: ["bf", "bf", "gf"],
            storyName: weekName,
            weekName: weekName,
            startUnlocked: true
        };

        File.saveContent(weekDir + ChartUtil.normalizeSong(weekName) + ".json", Json.stringify(weekData, "\t"));
        trace("Week file created for: " + weekName);
    }

    // --- SINGLE CHART GENERATOR (Hidden in Story Mode, Visible in Freeplay) ---
    public static function addToFreeplayWeek(songName:String)
    {
        var weekDir = "assets/shared/weeks/";
        createDir(weekDir);
        var weekPath = weekDir + "online_downloads.json";

        var weekData:Dynamic = null;

        // 1. Try to load the existing Freeplay week
        if (FileSystem.exists(weekPath)) {
            try {
                weekData = Json.parse(File.getContent(weekPath));
            } catch(e:Dynamic) {
                weekData = null; // File corrupted, we will recreate it
            }
        }

        // 2. If it doesn't exist, create the base template
        if (weekData == null) {
            weekData = {
                songs: [],
                hideStoryMode: true,   // Hide from Story Menu!
                hideFreeplay: false,   // Show in Freeplay!
                weekBackground: "stage",
                difficulties: "normal",
                weekCharacters: ["bf", "bf", "gf"],
                storyName: "Online Downloads",
                weekName: "Online Downloads",
                startUnlocked: true
            };
        }

        // 3. Check if the song is already in the list (prevent duplicates)
        var exists:Bool = false;
        var songArray:Array<Dynamic> = weekData.songs;
        for (i in 0...songArray.length) {
            if (songArray[i][0] == songName) {
                exists = true;
                break;
            }
        }

        // 4. Add it and save
        if (!exists) {
            songArray.push([songName, "face", [146, 113, 253]]);
            weekData.songs = songArray;
            File.saveContent(weekPath, Json.stringify(weekData, "\t"));
            trace("Added " + songName + " to the Online Freeplay week.");
        }
    }
}