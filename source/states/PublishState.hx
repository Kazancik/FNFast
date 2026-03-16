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

        infoText = new FlxText(0,70,0,"Select JSON and paste SoundCloud links",18);
        infoText.setFormat(null,18,FlxColor.WHITE,CENTER);
        infoText.screenCenter(X);
        add(infoText);

        function createLabel(y:Float, str:String) {
            var t = new FlxText(FlxG.width/2 - 200, y, 400, str, 14);
            add(t);
        }

        createLabel(110, "SoundCloud INSTRUMENTAL URL:");
        scInstInput = new FlxUIInputText(FlxG.width/2 - 200, 130, 400, "https://soundcloud.com/", 14);
        add(scInstInput);

        createLabel(170, "SoundCloud VOICES URL (Optional):");
        scVoicesInput = new FlxUIInputText(FlxG.width/2 - 200, 190, 400, "https://soundcloud.com/", 14);
        add(scVoicesInput);

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

    override public function update(elapsed:Float)
    {
        super.update(elapsed);

        // --- PASTE SUPPORT (CTRL+V) ---
        if (FlxG.keys.pressed.CONTROL && FlxG.keys.justPressed.V)
        {
            var clipboardText:String = lime.system.Clipboard.text;
            if (clipboardText != null && clipboardText.length > 0)
            {
                if (scInstInput.hasFocus) scInstInput.text = clipboardText;
                if (scVoicesInput.hasFocus) scVoicesInput.text = clipboardText;
            }
        }
    }

    function makeButton(y:Float, label:String, cb:Void->Void):FlxButton
    {
        var b = new FlxButton(0, y, label, cb);
        b.screenCenter(X);
        return b;
    }

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
        if (!FileSystem.exists("temp")) FileSystem.createDirectory("temp");
        chartPath = "temp/upload_chart.json";
        File.saveBytes(chartPath, fileRef.data);
        loadChart(chartPath);
    }

    function onFileError(e:IOErrorEvent) { infoText.text = "File Dialog Error."; }

    function loadChart(path:String) {
        meta = ChartMetaReader.read(path);
        songName = ChartUtil.normalizeSong(meta.song);
        metaText.text = "CHART LOADED: " + meta.song.toUpperCase();
    }

function publishChart(){
    if (backend.ClientPrefs.data.authToken == null || backend.ClientPrefs.data.authToken == ""){
        infoText.text = "You must be logged in to publish!";
        return ;
    }
    
        if (chartPath == "") { 
            infoText.text = "Please select a JSON first!"; 
            infoText.color = FlxColor.RED;
            return; 
        }
        
        var instUrl = scInstInput.text;
        if (instUrl.indexOf("soundcloud.com") == -1) { 
            infoText.text = "Invalid SoundCloud link for Instrumental!"; 
            infoText.color = FlxColor.RED;
            return; 
        }

        infoText.text = "Injecting Cloud Links...";
        infoText.color = FlxColor.WHITE;

        // --- THE 100% CRASH-PROOF WAY (STRING REPLACEMENT) ---
        // We read the file as a raw string
        var rawJson:String = sys.io.File.getContent(chartPath);
        
        // We find the start of the "song" object
        var songObjectStart = rawJson.indexOf('"song":');
        if (songObjectStart == -1) songObjectStart = 1; // Fallback to root

        // We find the first comma inside that object and inject our fields right after it
        var firstComma = rawJson.indexOf(',', songObjectStart);
        
        var voicesUrl = scVoicesInput.text;
        var hasVoices = (voicesUrl.length > 25 && voicesUrl.indexOf("soundcloud.com") != -1);

        var injectionString = ',\n\t"sc_inst": "' + instUrl + '"';
        if (hasVoices) {
            injectionString += ',\n\t"sc_voices": "' + voicesUrl + '"';
        }

        // Slice the string apart, put our new fields in the middle, and glue it back together
        var modifiedJson = rawJson.substr(0, firstComma) + injectionString + rawJson.substr(firstComma);

        // Save the modified text back to the file
        sys.io.File.saveContent(chartPath, modifiedJson);
        // -----------------------------------------------------

        infoText.text = "Building ZIP Package...";

        // Build ZIP (Audio paths are null because links are now INSIDE the JSON)
        var zipPath = backend.ChartPublisher.buildZip(
            songName, 
            chartPath, 
            null, 
            null
        );

        uploadZip(zipPath);
    }

    function uploadZip(zipPath:String)
    {
        infoText.text = "Uploading...";
        var bytes = File.getBytes(zipPath);
        var http = new haxe.Http(backend.OnlineManager.serverURL + "/upload_chart");
        http.setHeader("Content-Type", "application/octet-stream");
        http.setHeader("Chart-Name", songName);
        trace("Username for header: " + backend.ClientPrefs.username);
        http.setHeader("Author-Name", backend.ClientPrefs.username);
        http.setPostBytes(bytes);
        http.onData = function(_) { 
            infoText.text = "SUCCESS!"; 
            if(FileSystem.exists(zipPath)) FileSystem.deleteFile(zipPath);
        };
        http.onError = function(err) { infoText.text = "Upload failed!"; };
        http.request(true);
    }
}