package states;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import flixel.group.FlxSpriteGroup;
import haxe.Http;
import haxe.Json;
import backend.OnlineManager;
import backend.ClientPrefs;

class AchievementsMenuState extends MusicBeatState {

    var leaderboardGroup:FlxSpriteGroup;

    override public function create():Void
    {
        super.create();
        
        // 1. Dark Modern Background
        var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF121212);
        add(bg);

        // 2. Stylish Title
        var title = new FlxText(0, 25, FlxG.width, "GLOBAL RANKINGS", 36);
        title.setFormat(Paths.font("vcr.ttf"), 36, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
        title.borderSize = 3;
        add(title);

        // 3. UI Buttons
        // Back Button (Top Left)
        var backBtn = new FlxButton(20, 20, "BACK", function() {
            MusicBeatState.switchState(new MainMenuState());
        });
        add(backBtn);

        // My Profile Button (Top Right)
        var profileBtn = new FlxButton(FlxG.width - 120, 20, "MY PROFILE", function() {
            // Switches to your profile using your saved username
            MusicBeatState.switchState(new states.ProfileState(backend.ClientPrefs.username));
        });
        add(profileBtn);

        // 4. Leaderboard Container
        leaderboardGroup = new FlxSpriteGroup();
        add(leaderboardGroup);

        fetchLeaderboard();
        
        FlxG.mouse.visible = true;
    }

    function fetchLeaderboard()
    {
        var http = new Http(OnlineManager.serverURL + "/leaderboard/players");
        
        http.onData = function(data:String) {
            try {
                var players:Array<Dynamic> = Json.parse(data);
                
                for (i in 0...players.length) {
                    var p = players[i];
                    
                    // Determine Rank Colors
                    var color = FlxColor.WHITE;
                    var suffix = "";
                    
                    if (i == 0) { color = FlxColor.YELLOW; suffix = " [KING]"; }
                    else if (i == 1) color = 0xFFC0C0C0; // Silver
                    else if (i == 2) color = 0xFFCD7F32; // Bronze

                    // Create a slot background for each player
                    var slotY = 110 + (i * 45);
                    var slotBg = new FlxSprite(100, slotY).makeGraphic(FlxG.width - 200, 40, 0xFF1F1F1F);
                    slotBg.alpha = 0.7;
                    leaderboardGroup.add(slotBg);

                    // Player Text
                    var rankNum = (i + 1);
                    var playerText = new FlxText(120, slotY + 8, FlxG.width - 240, rankNum + ". " + p.username + suffix);
                    playerText.setFormat(Paths.font("vcr.ttf"), 22, color, LEFT, OUTLINE, FlxColor.BLACK);
                    leaderboardGroup.add(playerText);

                    // Stars/Rating Text
                    var starsText = new FlxText(FlxG.width - 350, slotY + 8, 200, p.rating + " ★");
                    starsText.setFormat(Paths.font("vcr.ttf"), 22, color, RIGHT, OUTLINE, FlxColor.BLACK);
                    leaderboardGroup.add(starsText);
                }
            } catch(e:Dynamic) {
                trace("Error parsing leaderboard: " + e);
            }
        };
        
        http.onError = function(err) {
            var errorTxt = new FlxText(0, FlxG.height/2, FlxG.width, "COULD NOT CONNECT TO LEADERBOARD");
            errorTxt.setFormat(null, 24, FlxColor.RED, CENTER);
            add(errorTxt);
        };

        http.request();
    }
}