package states;

import flixel.FlxState;
import flixel.FlxG;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import flixel.addons.ui.FlxUIInputText;
import haxe.Http;
import haxe.Json;
import backend.ChartUtil;
import backend.OnlineManager;
import backend.ClientPrefs;

class ListCreatorState extends FlxState
{
    var nameInput:FlxUIInputText;
    var chartsInput:FlxUIInputText; // Input box for IDs
    var statusText:FlxText;

    override public function create():Void
    {
        super.create();
        add(new flixel.FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF121212));

        add(new FlxText(0, 20, FlxG.width, "CREATE WEEK", 32).setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, CENTER));

        // Name
        add(new FlxText(FlxG.width/2 - 200, 100, 400, "Week Name:", 16));
        nameInput = new FlxUIInputText(FlxG.width/2 - 200, 125, 400, "My Awesome Week", 16);
        add(nameInput);

        // IDs
        add(new FlxText(FlxG.width/2 - 200, 160, 400, "Chart IDs (Comma separated):", 16));
        chartsInput = new FlxUIInputText(FlxG.width/2 - 200, 185, 400, "song1,song2,song3", 16);
        add(chartsInput);

        statusText = new FlxText(0, 300, FlxG.width, "Ready to publish.", 16).setFormat(null, 16, FlxColor.GRAY, CENTER);
        add(statusText);

        var submitBtn = new FlxButton(FlxG.width/2 - 60, 250, "SUBMIT WEEK", submitList);
        add(submitBtn);

        add(new FlxButton(20, FlxG.height - 50, "BACK", function() FlxG.switchState(new CreatorMenuState())));
        FlxG.mouse.visible = true;
    }

function submitList():Void
    {
        if(nameInput.text == "" || chartsInput.text == "") return;

        var chartIDs:Array<String> = chartsInput.text.split(",");
        
        // Clean the array
        var cleanIDs:Array<String> = [];
        for (id in chartIDs) {
            var c = StringTools.trim(id);
            if (c.length > 0) cleanIDs.push(c);
        }

        var payload = {
            id: ChartUtil.normalizeSong(nameInput.text),
            name: nameInput.text,
            charts: cleanIDs,
            author: backend.ClientPrefs.data.username // Tells the server who made this!
        };

        var http = new haxe.Http(backend.OnlineManager.serverURL + "/upload_list");
        http.setPostData(haxe.Json.stringify(payload));
        http.setHeader("Content-Type", "application/json");
        http.onData = function(res) {
            statusText.text = "WEEK PUBLISHED!";
            statusText.color = flixel.util.FlxColor.LIME;
        };
        http.request(true);
    }
}