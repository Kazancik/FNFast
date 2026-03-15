package states;

import flixel.FlxState;
import flixel.FlxG;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.addons.ui.FlxUIInputText;
import flixel.group.FlxSpriteGroup;
import flixel.math.FlxMath;
import flixel.util.FlxColor;
import haxe.Http;
import haxe.Json;

class MaterialBrowserState extends FlxState
{
    var searchInput:FlxUIInputText;
    var listGroup:FlxSpriteGroup;
    var scrollY:Float = 0;
    var targetScrollY:Float = 0;
    var itemsCount:Int = 0;

    override public function create():Void
    {
        super.create();
        add(new flixel.FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF181818));

        // Header
        var header = new flixel.FlxSprite().makeGraphic(FlxG.width, 110, 0xFF000000);
        header.alpha = 0.7;
        add(header);

        var title = new FlxText(20, 15, 0, "ASSET REPOSITORY", 28);
        title.setFormat(null, 28, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
        add(title);

        searchInput = new FlxUIInputText(120, 65, 350, "", 18);
        searchInput.backgroundColor = 0xFF333333;
        add(searchInput);

        add(new FlxText(20, 65, 0, "SEARCH:", 18));

        var searchBtn = new FlxButton(480, 63, "FIND", doSearch);
        add(searchBtn);

        listGroup = new FlxSpriteGroup();
        add(listGroup);

        add(new FlxButton(FlxG.width - 100, 20, "BACK", function() FlxG.switchState(new CreatorMenuState())));
        
        doSearch(); // Initial load
        FlxG.mouse.visible = true;
    }

    override public function update(elapsed:Float) {
        super.update(elapsed);
        if (FlxG.mouse.wheel != 0) targetScrollY += FlxG.mouse.wheel * 100;
        
        var maxScroll = -(itemsCount * 90) + FlxG.height - 200;
        if (targetScrollY > 0) targetScrollY = 0;
        if (targetScrollY < maxScroll && maxScroll < 0) targetScrollY = maxScroll;

        scrollY = FlxMath.lerp(scrollY, targetScrollY, 0.1);
        listGroup.y = scrollY;
    }

    function doSearch():Void
    {
        listGroup.clear();
        var url = backend.OnlineManager.serverURL + "/materials/search?q=" + StringTools.urlEncode(searchInput.text);
        var http = new Http(url);
        http.onData = function(res) {
            displayResults(Json.parse(res));
        };
        http.request();
    }

    function displayResults(data:Array<Dynamic>):Void
    {
        itemsCount = data.length;
        for(i in 0...data.length)
        {
            var item = data[i];
            var yPos = 130 + (i * 90);

            var slot = new flixel.FlxSprite(40, yPos).makeGraphic(FlxG.width - 80, 80, 0xFF252525);
            slot.alpha = 0.8;
            listGroup.add(slot);

            var txt = new FlxText(60, yPos + 10, slot.width - 40, item.id.toUpperCase(), 22);
            txt.setFormat(null, 22, 0xFF00AAFF, LEFT, OUTLINE, FlxColor.BLACK);
            listGroup.add(txt);

            var desc = new FlxText(60, yPos + 40, slot.width - 200, item.desc, 14);
            desc.color = 0xFFAAAAAA;
            listGroup.add(desc);
        }
    }
}