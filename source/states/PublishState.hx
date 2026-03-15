package states;

import flixel.FlxState;
import flixel.FlxG;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;

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

    var fileRef:FileReference;

    var chartPath:String;
    var instPath:String;
    var voicesPath:String;

    var meta:ChartMeta = null;
    var songName:String = null;

    // tells dialog what we are selecting
    var selecting:String = "";

    override public function create():Void
    {
        super.create();

        FlxG.mouse.visible = true;

        // ---------- TITLE ----------
        var title = new FlxText(0,20,0,"Publish Chart",32);
        title.setFormat(null,32,FlxColor.WHITE,CENTER);
        title.screenCenter(X);
        add(title);

        // ---------- INFO ----------
        infoText = new FlxText(0,80,0,
            "Select chart, Inst, and optional Voices",20);
        infoText.alignment = CENTER;
        infoText.screenCenter(X);
        add(infoText);

        // ---------- META ----------
        metaText = new FlxText(0,140,0,"",18);
        metaText.alignment = CENTER;
        metaText.screenCenter(X);
        add(metaText);

        // ---------- BUTTONS ----------

        add(makeButton(220,"Select Chart JSON",selectChart));
        add(makeButton(270,"Select Inst.ogg",selectInst));
        add(makeButton(320,"Voices.ogg",selectVoices));
        add(makeButton(380,"Publish",publishChart));

        var backBtn = new FlxButton(10,10,"Back",function(){
            FlxG.switchState(new CreatorMenuState());
        });
        add(backBtn);
    }

    function makeButton(y:Float,label:String,cb:Void->Void):FlxButton
    {
        var b = new FlxButton(0,y,label,cb);
        b.screenCenter(X);
        return b;
    }

    // =====================================================
    // FILE PICKERS
    // =====================================================

    function selectChart()
    {
        selecting = "chart";
        browse([new FileFilter("Psych Charts","*.json")]);
    }

    function selectInst()
    {
        selecting = "inst";
        browse([new FileFilter("OGG Audio","*.ogg")]);
    }

    function selectVoices()
    {
        selecting = "voices";
        browse([new FileFilter("OGG Audio","*.ogg")]);
    }

    function browse(filters:Array<FileFilter>)
    {
        fileRef = new FileReference();

        fileRef.addEventListener(Event.SELECT,onFileSelected);
        fileRef.addEventListener(IOErrorEvent.IO_ERROR,onFileError);

        fileRef.browse(filters);
    }

    function onFileSelected(e:Event)
    {
        fileRef.addEventListener(Event.COMPLETE,onFileLoaded);
        fileRef.load();
    }

    function onFileLoaded(e:Event):Void
    {
        try
        {
            var tempPath = "temp_" + selecting;
            if (!FileSystem.exists("temp"))
                FileSystem.createDirectory("temp");
            // set correct extension and assign into correct var
            if (selecting == "chart")
            {
                tempPath += ".json";
                File.saveBytes(tempPath, fileRef.data);
                chartPath = tempPath;
                loadChart(chartPath);
                infoText.text = "Chart selected.";
                return;
            }

            if (selecting == "inst")
            {
                tempPath += ".ogg";
                File.saveBytes(tempPath, fileRef.data);
                instPath = tempPath;
                infoText.text = "Inst selected.";
                return;
            }

            if (selecting == "voices")
            {
                tempPath += ".ogg";
                File.saveBytes(tempPath, fileRef.data);
                voicesPath = tempPath;
                infoText.text = "Voices selected.";
                return;
            }
        }
        catch(e:Dynamic)
        {
            infoText.text = "Failed loading file: " + Std.string(e);
            trace("onFileLoaded error: " + Std.string(e));
        }
    }

    function onFileError(e:IOErrorEvent)
    {
        infoText.text = "File dialog error.";
    }

    // =====================================================
    // LOAD METADATA
    // =====================================================

    function loadChart(path:String)
    {
        meta = ChartMetaReader.read(path);

        songName = ChartUtil.normalizeSong(meta.song);

        metaText.text =
            "Song: " + meta.song +
            "\nBPM: " + meta.bpm +
            "\nStage: " + meta.stage +
            "\nNeeds Voices: " + meta.needsVoices;

        infoText.text = "Chart loaded.";
    }

    // =====================================================
    // PUBLISH
    // =====================================================

    function publishChart()
    {
        if(meta == null)
        {
            infoText.text = "Select chart first!";
            return;
        }

        if(instPath == null)
        {
            infoText.text = "Select Inst.ogg!";
            return;
        }

        if(meta.needsVoices && voicesPath == null)
        {
            infoText.text = "Voices required!";
            return;
        }

        infoText.text = "Building package...";

        var zipPath = ChartPublisher.buildZip(
            chartPath,
            instPath,
            voicesPath,
            songName
        );

        uploadZip(zipPath);
    }

    // =====================================================
    // UPLOAD
    // =====================================================

    function uploadZip(zipPath:String)
    {
        var bytes = File.getBytes(zipPath);

        trace("ZIP SIZE = " + bytes.length);

        var http = new haxe.Http(
            backend.OnlineManager.serverURL + "/upload_chart"
        );

        http.setHeader("Content-Type", "application/octet-stream");
        http.setHeader("Chart-Name", songName);
        http.setHeader("Author-Name", backend.ClientPrefs.username);

        // ✅ THIS IS THE IMPORTANT LINE
        http.setPostBytes(bytes);

        http.onData = function(_)
        {
            infoText.text = "Upload successful!";
        };

        http.onError = function(err)
        {
            infoText.text = "Upload failed: " + err;
        };

        http.request(true); // POST
    }
}
