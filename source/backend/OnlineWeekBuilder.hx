package backend;

import sys.FileSystem;
import sys.io.File;
import haxe.Json;

class OnlineWeekBuilder
{
    static var MOD_PATH = "mods/OnlineCharts/";
    static var SONGS_PATH = "assets/shared/data/";
    static var WEEK_PATH = MOD_PATH + "weeks/";
    static var WEEK_FILE = WEEK_PATH + "online.json";

    public static function rebuild():Void
    {
        if (!FileSystem.exists(WEEK_PATH))
            FileSystem.createDirectory(WEEK_PATH);

        var songs:Array<Dynamic> = [];

        if (FileSystem.exists(SONGS_PATH))
        {
            for (song in FileSystem.readDirectory(SONGS_PATH))
            {
                // ensure it's folder
                if (!FileSystem.isDirectory(SONGS_PATH + song))
                    continue;

                songs.push([
                    song,       // song name
                    "face",     // icon
                    [146,113,253] // color
                ]);
            }
        }

        var weekData:Dynamic = {
            songs: songs,
            hideStoryMode: true,
            hideFreeplay: false,
            weekBackground: "stage",
            weekCharacters: ["bf","bf","gf"],
            storyName: "Online Charts",
            weekName: "Online",
            startUnlocked: true
        };

        File.saveContent(
            WEEK_FILE,
            Json.stringify(weekData, "\t")
        );

        trace("Online week rebuilt with " + songs.length + " songs");
    }
}
