package backend;

import sys.FileSystem;
import sys.io.File;
import haxe.io.Bytes;
import haxe.zip.Entry;
import haxe.zip.Writer;
import haxe.Http;
import haxe.Json;
import haxe.ds.List;
using StringTools; // Important for endsWith/startsWith

class MaterialSubmitter
{
    public static var SOURCE_FOLDER = "mods/material_submit/";
    
    public static function submit(materialName:String,description:String = "" ,onComplete:Bool->String->Void   )
    {
        if(!FileSystem.exists(SOURCE_FOLDER)) {
            FileSystem.createDirectory(SOURCE_FOLDER);
            onComplete(false, "Created folder mods/material_submit/. Put files there!");
            return;
        }

        var files = FileSystem.readDirectory(SOURCE_FOLDER);
        if(files.length == 0) {
            onComplete(false, "Folder is empty!");
            return;
        }

        var manifest = {
            type: "mixed",
            assets: [],
            json: [],
            lua: [],
            sounds: []
        };

        var entries = new List<Entry>();

        for(file in files)
        {
            var rawPath = SOURCE_FOLDER + file;
            if(FileSystem.isDirectory(rawPath)) continue;

            var content = File.getBytes(rawPath);
            var zipPath = ""; 

            // --- SMART FILE SORTING ---

            // 1. JSON Handling (Character vs Stage vs Chart)
            if(file.endsWith(".json")) 
            {
                var textContent = File.getContent(rawPath);
                
                // If it has animations/image/healthicon -> It's a CHARACTER
                if(textContent.indexOf("animations") != -1 || textContent.indexOf("healthicon") != -1 || textContent.indexOf("image") != -1) {
                    zipPath = "characters/" + file;
                }
                // If it has defaultZoom -> It's a STAGE
                else if(textContent.indexOf("defaultZoom") != -1) {
                    zipPath = "stages/" + file;
                }
                // Otherwise -> It's DATA (Chart)
                else {
                    zipPath = "data/" + file;
                }
                
                manifest.json.push(zipPath);
            }
            // 2. Image Handling (Character vs Icon vs Stage)
            else if(file.endsWith(".png") || file.endsWith(".xml")) 
            {
                if(file.startsWith("icon-")) {
                     zipPath = "images/icons/" + file;
                } 
                // Most loose PNGs in a material submit are character sprites
                else {
                     zipPath = "images/characters/" + file;
                }
                manifest.assets.push(zipPath);
            }
            // 3. Scripts
            else if(file.endsWith(".lua") || file.endsWith(".hx")) 
            {
                zipPath = "scripts/" + file;
                manifest.lua.push(zipPath);
            }
            // 4. Sounds
            else if(file.endsWith(".ogg")) 
            {
                zipPath = "sounds/" + file;
                manifest.sounds.push(zipPath);
            }

            if(zipPath != "") {
                entries.add(makeEntry(zipPath, content));
            }
        }

        // Add Manifest
        var manifestString = Json.stringify(manifest, "\t");
        entries.add(makeEntry("materials/characters/" + materialName + ".material", Bytes.ofString(manifestString)));

        // Create Zip
        var output = new haxe.io.BytesOutput();
        var writer = new Writer(output);
        writer.write(entries);
        var zipBytes = output.getBytes();

        uploadZip(zipBytes, materialName, onComplete, description);
    }

    static function uploadZip(bytes:Bytes, name:String, callback:Bool->String->Void, description:String = "")
    {
        // Make sure this URL matches your server
        var http = new Http(backend.OnlineManager.serverURL + "/upload_material_package");
        http.setHeader("Content-Type", "application/octet-stream");
        http.setHeader("Author-Name", backend.ClientPrefs.data.username); 
        http.setHeader("Material-Name", name);
        http.setHeader("Material-Desc", description);
        http.onData = function(res) callback(true, res);
        http.onError = function(err) callback(false, err);
        http.setPostBytes(bytes);
        http.request(true);
    }

    static function makeEntry(name:String, bytes:Bytes):Entry
    {
        return {
            fileName: name,
            fileSize: bytes.length,
            fileTime: Date.now(),
            compressed: false,
            dataSize: bytes.length,
            data: bytes,
            crc32: haxe.crypto.Crc32.make(bytes),
            extraFields: null
        };
    }
}