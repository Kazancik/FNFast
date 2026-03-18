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
import backend.ClientPrefs;

class PublishState extends FlxState
{
    var infoText:FlxText;
    var metaText:FlxText;
    
    var scInstInput:FlxUIInputText; 
    var scVoicesInput:FlxUIInputText; 
    var descInput:FlxUIInputText; // NEW: Description Input

    var fileRef:FileReference;
    var chartPath:String = "";
    
    var meta:ChartMeta = null;
    var songName:String = null;
    var selecting:String = "";

    override public function create():Void
    {
        super.create();
        FlxG.mouse.visible = true;

        // 1. Dark Background
        add(new flixel.FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF121212));

        // 2. Form Container Box
        var box = new flixel.FlxSprite().makeGraphic(550, 480, 0xFF1F1F1F);
        box.screenCenter();
        add(box);

        var title = new FlxText(0, box.y + 15, FlxG.width, "PUBLISH CHART", 28);
        title.setFormat(Paths.font("vcr.ttf"), 28, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        add(title);

        infoText = new FlxText(0, box.y + 60, FlxG.width, "Provide links and select your JSON.", 16);
        infoText.setFormat(Paths.font("vcr.ttf"), 16, 0xFFAAAAAA, CENTER);
        add(infoText);

        // --- INPUT FIELDS ---
        function addLabel(y:Float, str:String) {
            var t = new FlxText(box.x + 50, y, 450, str, 14);
            t.color = 0xFF888888;
            add(t);
        }

        addLabel(box.y + 100, "SOUNDCLOUD INSTRUMENTAL URL (Required):");
        scInstInput = new FlxUIInputText(box.x + 50, box.y + 120, 450, "https://soundcloud.com/", 14);
        add(scInstInput);

        addLabel(box.y + 160, "SOUNDCLOUD VOICES URL (Optional):");
        scVoicesInput = new FlxUIInputText(box.x + 50, box.y + 180, 450, "https://soundcloud.com/", 14);
        add(scVoicesInput);

        addLabel(box.y + 220, "CHART DESCRIPTION / CREDITS:");
        descInput = new FlxUIInputText(box.x + 50, box.y + 240, 450, "A cool chart by...", 14);
        add(descInput);

        // --- BUTTONS ---
        var selectBtn = new FlxButton(0, box.y + 300, "SELECT CHART JSON", selectChart);
        selectBtn.setGraphicSize(200, 30);
        selectBtn.updateHitbox();
        selectBtn.screenCenter(X);
        add(selectBtn);

        metaText = new FlxText(0, box.y + 345, FlxG.width, "No Chart Selected", 14);
        metaText.setFormat(Paths.font("vcr.ttf"), 14, FlxColor.YELLOW, CENTER, OUTLINE, FlxColor.BLACK);
        add(metaText);

        var pubBtn = new FlxButton(0, box.y + 400, "PUBLISH TO FNFAST", publishChart);
        pubBtn.setGraphicSize(250, 40);
        pubBtn.updateHitbox();
        pubBtn.color = FlxColor.LIME;
        pubBtn.label.color = FlxColor.BLACK;
        pubBtn.screenCenter(X);
        add(pubBtn);

        add(new FlxButton(20, FlxG.height - 50, "BACK", function(){
            MusicBeatState.switchState(new CreatorMenuState());
        }));
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
                if (descInput.hasFocus) descInput.text = clipboardText;
            }
        }
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
        if (!FileSystem.exists("temp")) FileSystem.createDirectory("temp");
        chartPath = "temp/upload_chart.json";
        File.saveBytes(chartPath, fileRef.data);
        loadChart(chartPath);
    }

    function onFileError(e:IOErrorEvent) { infoText.text = "File Dialog Error."; infoText.color = FlxColor.RED; }

    function loadChart(path:String) {
        meta = ChartMetaReader.read(path);
        songName = ChartUtil.normalizeSong(meta.song);
        metaText.text = "READY: " + meta.song.toUpperCase() + " (" + meta.bpm + " BPM)";
        metaText.color = FlxColor.CYAN;
        infoText.text = "Chart mapped successfully.";
        infoText.color = FlxColor.LIME;
    }

    // =====================================================
    // PUBLISH & UPLOAD
    // =====================================================

    function publishChart()
    {
        if (ClientPrefs.data.authToken == null || ClientPrefs.data.authToken == "") {
            infoText.text = "You must be logged in to publish!";
            infoText.color = FlxColor.RED;
            return;
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
        var rawJson:String = sys.io.File.getContent(chartPath);
        
        var songObjectStart = rawJson.indexOf('"song":');
        if (songObjectStart == -1) songObjectStart = 1; 

        var firstComma = rawJson.indexOf(',', songObjectStart);
        
        var voicesUrl = scVoicesInput.text;
        var hasVoices = (voicesUrl.length > 25 && voicesUrl.indexOf("soundcloud.com") != -1);

        var injectionString = ',\n\t"sc_inst": "' + instUrl + '"';
        if (hasVoices) {
            injectionString += ',\n\t"sc_voices": "' + voicesUrl + '"';
        }

        var modifiedJson = rawJson.substr(0, firstComma) + injectionString + rawJson.substr(firstComma);
        sys.io.File.saveContent(chartPath, modifiedJson);
        // -----------------------------------------------------

        infoText.text = "Building ZIP Package...";

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
        infoText.text = "Uploading to Server...";
        
        var bytes = File.getBytes(zipPath);
        var http = new haxe.Http(backend.OnlineManager.serverURL + "/upload_chart");
        
        http.setHeader("Content-Type", "application/octet-stream");
        http.setHeader("Chart-Name", songName);
        http.setHeader("Author-Name", ClientPrefs.data.username);
        http.setHeader("Chart-Desc", descInput.text); // NEW: Send the description!

        http.setPostBytes(bytes);

        http.onData = function(_) { 
            infoText.text = "UPLOAD SUCCESSFUL!"; 
            infoText.color = FlxColor.LIME;
            if(FileSystem.exists(zipPath)) FileSystem.deleteFile(zipPath);
        };

        http.onError = function(err) { 
            infoText.text = "Upload failed: " + err; 
            infoText.color = FlxColor.RED;
        };

        http.request(true);
    }
}