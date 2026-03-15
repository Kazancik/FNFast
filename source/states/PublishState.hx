package states;

import flixel.FlxState;
import flixel.FlxG;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import flixel.addons.ui.FlxUIInputText;
import sys.FileSystem;
import sys.io.File;
import openfl.net.FileReference;
import openfl.net.FileFilter;
import openfl.events.Event;
import openfl.events.IOErrorEvent;
import backend.ChartMeta;
import backend.ChartMetaReader;
import backend.ChartPublisher;
import backend.ChartUtil;

class PublishState extends FlxState
{
    var infoText:FlxText;
    var metaText:FlxText;
    
    // TWO SOUNDCLOUD INPUTS
    var scInstInput:FlxUIInputText; 
    var scVoicesInput:FlxUIInputText; 

    var fileRef:FileReference;
    var chartPath:String = "";
    
    var meta:ChartMeta = null;
    var songName:String = null;
    var selecting:String = "";

    override public function create():Void
    {
        super.create();
        FlxG.mouse.visible = true;

        var title = new FlxText(0,20,0,"Publish Chart (Cloud Stream)",32);
        title.setFormat(Paths.font("vcr.ttf"),32,FlxColor.WHITE,CENTER,OUTLINE,FlxColor.BLACK);
        title.screenCenter(X);
        add(title);

        infoText = new FlxText(0,70,0,"Select JSON and paste SoundCloud links for Inst and Voices",18);
        infoText.setFormat(null,18,FlxColor.WHITE,CENTER);
        infoText.screenCenter(X);
        add(infoText);

        // --- INPUT FIELDS ---
        function createLabel(y:Float, str:String) {
            var t = new FlxText(FlxG.width/2 - 200, y, 400, str, 14);
            add(t);
        }

        createLabel(110, "SoundCloud INSTRUMENTAL URL (Required):");
        scInstInput = new FlxUIInputText(FlxG.width/2 - 200, 130, 400, "https://soundcloud.com/", 14);
        add(scInstInput);

        createLabel(170, "SoundCloud VOICES URL:");
        scVoicesInput = new FlxUIInputText(FlxG.width/2 - 200, 190, 400, "https://soundcloud.com/", 14);
        add(scVoicesInput);

        // --- BUTTONS ---
        add(makeButton(250, "1. SELECT CHART JSON", selectChart));
        
        var pubBtn = makeButton(340, "PUBLISH TO FNFAST", publishChart);
        pubBtn.color = FlxColor.LIME;
        add(pubBtn);

        add(new FlxButton(10, 10, "BACK", function(){
            MusicBeatState.switchState(new CreatorMenuState());
        }));

        metaText = new FlxText(0, 290, FlxG.width, "No Chart Selected", 16);
        metaText.alignment = CENTER;
        add(metaText);
    }

    function makeButton(y:Float, label:String, cb:Void->Void):FlxButton
    {
        var b = new FlxButton(0, y, label, cb);
        b.screenCenter(X);
        return b;
    }

    // =====================================================
    // FILE PICKER LOGIC
    // =====================================================

    function selectChart() {
        selecting = "chart";
        browse([new FileFilter("FNF Chart JSON", "*.json")]);
    }

    function browse(filters:Array<FileFilter>) {
        fileRef = new FileReference();
        fileRef.addEventListener(Event.SELECT, onFileSelected);
        fileRef.addEventListener(IOErrorEvent.IO_ERROR, onFileError);
        fileRef.browse(filters);
    }

    function onFileSelected(e:Event) {
        fileRef.addEventListener(Event.COMPLETE, onFileLoaded);
        fileRef.load();
    }

    function onFileLoaded(e:Event):Void {
        try {
            if (!FileSystem.exists("temp")) FileSystem.createDirectory("temp");
            var path = "temp/upload_chart.json";
            File.saveBytes(path, fileRef.data);
            chartPath = path;
            loadChart(path);
        } catch(e:Dynamic) {
            infoText.text = "Error loading JSON file!";
        }
    }

    function onFileError(e:IOErrorEvent) { infoText.text = "File Dialog Error."; }

    function loadChart(path:String) {
        meta = ChartMetaReader.read(path);
        songName = ChartUtil.normalizeSong(meta.song);
        metaText.text = "CHART LOADED: " + meta.song.toUpperCase() + " (" + meta.bpm + " BPM)";
        metaText.color = FlxColor.CYAN;
    }

    // =====================================================
    // PUBLISH & UPLOAD
    // =====================================================

    function publishChart()
    {
        if(meta == null) { 
            infoText.text = "Please select a JSON first!"; 
            infoText.color = FlxColor.RED;
            return; 
        }
        
        if(scInstInput.text.indexOf("soundcloud.com") == -1) { 
            infoText.text = "Invalid SoundCloud link for Instrumental!"; 
            infoText.color = FlxColor.RED;
            return; 
        }

        infoText.text = "Building ZIP Package...";
        infoText.color = FlxColor.WHITE;

        // Extract Voices link if it's not the default placeholder
        var voicesLink:String = null;
        if (scVoicesInput.text.length > 25 && scVoicesInput.text.indexOf("soundcloud.com") != -1) {
            voicesLink = scVoicesInput.text;
        }

        // Build ZIP using BOTH links (Uses our new 6-argument buildZip)
        var zipPath = ChartPublisher.buildZip(
            songName, 
            chartPath, 
            null, // No local Inst
            null, // No local Voices
            scInstInput.text, 
            voicesLink
        );

        uploadZip(zipPath);
    }

    function uploadZip(zipPath:String)
    {
        infoText.text = "Uploading to FNFast Server...";
        
        var bytes = File.getBytes(zipPath);
        var http = new haxe.Http(backend.OnlineManager.serverURL + "/upload_chart");

        http.setHeader("Content-Type", "application/octet-stream");
        http.setHeader("Chart-Name", songName);
        http.setHeader("Author-Name", backend.ClientPrefs.data.username);

        http.setPostBytes(bytes);

        http.onData = function(_) {
            infoText.text = "UPLOAD SUCCESSFUL!";
            infoText.color = FlxColor.LIME;
            
            // Clean up temp file
            if(FileSystem.exists(zipPath)) FileSystem.deleteFile(zipPath);
        };

        http.onError = function(err) {
            infoText.text = "Upload failed: " + err;
            infoText.color = FlxColor.RED;
        };

        http.request(true);
    }
}