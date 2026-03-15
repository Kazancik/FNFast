package states;

import flixel.FlxState;
import flixel.FlxG;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import haxe.Http;
import haxe.Json;

class ProfileState extends FlxState
{
    var user:String;
    
    public function new(username:String) {
        super();
        this.user = backend.ClientPrefs.username; // Force use logged in user, ignore passed username for security
    }

    override public function create():Void
    {
        super.create();
        add(new flixel.FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF121212));

        var title = new FlxText(0, 40, FlxG.width, "PLAYER PROFILE", 32);
        title.setFormat(null, 32, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        add(title);

        fetchProfile();

        add(new FlxButton(20, FlxG.height - 50, "BACK", function() {
            FlxG.switchState(new MainMenuState());
        }));
        FlxG.mouse.visible = true;
    }

    function fetchProfile() {
        var http = new Http(backend.OnlineManager.serverURL + "/user/profile/" + user);
        http.onData = function(data:String) {
            var p = Json.parse(data);
            
            // Big Username
            var nameTxt = new FlxText(0, 120, FlxG.width, p.username.toUpperCase(), 48);
            nameTxt.setFormat(null, 48, 0xFF00AAFF, CENTER, OUTLINE, FlxColor.BLACK);
            add(nameTxt);

            // Stats Layout
            function addStat(y:Float, label:String, value:String, color:FlxColor) {
                var l = new FlxText(0, y, FlxG.width/2, label + ": ", 24);
                l.alignment = RIGHT;
                add(l);
                var v = new FlxText(FlxG.width/2, y, FlxG.width/2, value, 24);
                v.color = color;
                add(v);
            }

            addStat(220, "GLOBAL RANK", "#" + p.rank, FlxColor.YELLOW);
            addStat(260, "TOTAL STARS", p.stars + " Stars", FlxColor.LIME);
            
            if (p.best_play != null) {
                addStat(320, "BEST PLAY", p.best_play.song + " (" + p.best_play.acc + "%)", 0xFFAAAAAA);
            }
        };
        http.request();
    }
}   