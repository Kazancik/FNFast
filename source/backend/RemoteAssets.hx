package backend;

import haxe.Http;
import haxe.io.Bytes;
import sys.io.File;
import sys.FileSystem;
import haxe.Json;
import sys.io.File;
import sys.FileSystem;
import haxe.io.Path; // <--- ADD THIS IMPORT
import backend.OnlineManager;
class RemoteAssets
{
    // Make sure this matches your server URL exactly
    public static var BASE_URL:String = backend.OnlineManager.serverURL + "/assets/";

    /**
     * characters/bf  -> downloads characters/bf.material
     * This blocks the game thread until finished to prevent crashes.
     */
    public static function ensureMaterial(type:String, name:String):Void
    {
        if(name == null || name.length == 0) return;

        // This builds the URL path: "materials/characters/bf.material"
        var materialRel = "materials/" + type + "/" + name + ".material";
        
        // This builds the local path: "assets/shared/materials/characters/bf.material"
        var localPath = "assets/shared/" + materialRel;


        trace("Material missing, downloading: " + materialRel);
        download(materialRel, localPath);
        MaterialProcessor.process(materialRel);
        


    }

    /**
     * Generic SYNCHRONOUS downloader.
     * Prevents the game from trying to load files before they exist.
     */
    public static function download(remote:String, local:String)
    {
        trace("Downloading: " + BASE_URL + remote);

        var http = new Http(OnlineManager.serverURL + BASE_URL + remote);
        
        http.onBytes = function(bytes:Bytes)
        {
            createDirFor(local);
            File.saveBytes(local, bytes);
            trace("Saved: " + local);
        };

        http.onError = function(err)
        {
            trace("Download failed: " + err + " | URL: " + BASE_URL + remote);
        };


        http.request(false); 
    }

    static function createDirFor(path:String)
    {
        var parts = path.split("/");
        parts.pop();

        var current = "";
        for(p in parts)
        {
            current += p + "/";
            if(!FileSystem.exists(current))
                FileSystem.createDirectory(current);
        }
    }
}








class MaterialProcessor
{
    public static function process(materialRel:String):Void
    {
        // materialRel is "materials/characters/bf.material"
        var path = "assets/shared/" + materialRel;
        if(!FileSystem.exists(path)) return;

        // --- THE FIX: CLEAN THE NAME ---
        // 1. Get "bf.material"
        var nameWithExt = Path.withoutDirectory(materialRel);
        // 2. Get "bf"
        var matID = Path.withoutExtension(nameWithExt);

        try {
            var content = File.getContent(path);
            var json:Dynamic = Json.parse(content);

            trace("Processing Material ID: " + matID);

            // Pass the clean matID to the downloader
            downloadList(json.assets, matID);
            downloadList(json.json, matID);
            downloadList(json.lua, matID);
            downloadList(json.sounds, matID);
            
        } catch(e:Dynamic) {
            trace("Error parsing material: " + e);
        }
    }

    static function downloadList(list:Dynamic, matID:String)
    {
        if(list == null) return;
        var fileList:Array<String> = cast list;

        for(file in fileList)
        {
            var local = "assets/shared/" + file;

            // --- THE FIX: FORCE SUBFOLDER FOR SCRIPTS ---
            if(file.toLowerCase().endsWith(".lua") || file.toLowerCase().endsWith(".hx")) 
            {
                // Get just "death.lua" even if the server sent "scripts/death.lua"
                var fileNameOnly = Path.withoutDirectory(file);
                // Result: assets/shared/scripts/bf/death.lua
                local = "assets/shared/scripts/" + matID + "/" + fileNameOnly;
            }

            if(FileSystem.exists(local)) continue;

            // Download from server, save to the SPECIFIC local path
            RemoteAssets.download(file, local);
        }
    }
}

