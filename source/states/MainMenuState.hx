package states;

import flixel.FlxObject;
import flixel.effects.FlxFlicker;
import lime.app.Application;
import states.editors.MasterEditorMenu;
import options.OptionsState;
import flixel.FlxG;
import flixel.FlxState;
import flixel.ui.FlxButton;
import sys.io.File;
import sys.FileSystem;
import haxe.Http;
import backend.ChartUtil;
import backend.ChartInstaller;
import backend.WeekData;
import haxe.Json;      
import flixel.FlxState;
import flixel.FlxSubState;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.ui.FlxButton;
import flixel.group.FlxSpriteGroup;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.math.FlxMath;
import flixel.addons.ui.FlxUIInputText;
import haxe.Http;
import haxe.Json;
import backend.ChartUtil;
import backend.ChartInstaller;
import backend.OnlineManager;
import flixel.text.FlxText;
import flixel.group.FlxGroup;

import haxe.crypto.Md5;
class CommentsSubState extends FlxSubState
{
    var chartId:String;
    var chartName:String;
    
    var commentsGroup:FlxSpriteGroup;
    var commentInput:FlxUIInputText;
    var statusText:FlxText;

    var scrollY:Float = 0;
    var targetScrollY:Float = 0;
    var maxScroll:Float = 0;

    public function new(id:String, name:String)
    {
        super();
        this.chartId = id;
        this.chartName = name;
    }

    override public function create():Void
    {
        super.create();

        // Dark transparent background
        var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        bg.alpha = 0.85;
        add(bg);

        // Main Panel
        var panel = new FlxSprite(100, 50).makeGraphic(FlxG.width - 200, FlxG.height - 100, 0xFF1A1A1A);
        add(panel);

        var title = new FlxText(100, 60, FlxG.width - 200, "COMMENTS: " + chartName.toUpperCase(), 24);
        title.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.YELLOW, CENTER, OUTLINE, FlxColor.BLACK);
        add(title);

        add(new FlxButton(FlxG.width - 190, 60, "X CLOSE", function() { close(); }));

        // Comments Area
        commentsGroup = new FlxSpriteGroup();
        add(commentsGroup);

        // Input Area (Bottom)
        var bottomPanel = new FlxSprite(100, FlxG.height - 120).makeGraphic(FlxG.width - 200, 70, 0xFF2A2A2A);
        add(bottomPanel);

        commentInput = new FlxUIInputText(120, FlxG.height - 100, FlxG.width - 360, "", 16);
        add(commentInput);

        var sendBtn = new FlxButton(FlxG.width - 220, FlxG.height - 100, "SEND", postComment);
        add(sendBtn);

        statusText = new FlxText(120, FlxG.height - 75, 400, "", 12);
        statusText.color = FlxColor.RED;
        add(statusText);

        fetchComments();
    }

    override public function update(elapsed:Float):Void
    {
        super.update(elapsed);

        // Scrolling logic for comments
        if (FlxG.mouse.wheel != 0 && !commentInput.hasFocus) {
            targetScrollY += FlxG.mouse.wheel * 60;
        }

        if (targetScrollY > 0) targetScrollY = 0;
        if (targetScrollY < maxScroll) targetScrollY = maxScroll;
        
        scrollY = FlxMath.lerp(scrollY, targetScrollY, 0.15);
        commentsGroup.y = scrollY;
    }

    function fetchComments():Void
    {
        commentsGroup.clear();
        var loading = new FlxText(120, 150, 400, "Loading comments...", 16);
        commentsGroup.add(loading);

        var http = new Http(OnlineManager.serverURL + "/get_comments/" + chartId);
        http.onData = function(res) {
            var data:Array<Dynamic> = Json.parse(res);
            buildComments(data);
        };
        http.onError = function(err) {
            loading.text = "Error loading comments.";
        };
        http.request();
    }

    function buildComments(data:Array<Dynamic>):Void
    {
        commentsGroup.clear();
        
        if (data.length == 0) {
            commentsGroup.add(new FlxText(120, 150, 400, "No comments yet. Be the first!", 16));
            maxScroll = 0;
            return;
        }

        for (i in 0...data.length)
        {
            var c = data[i];
            var cy = 110 + (i * 60);

            var userTxt = new FlxText(120, cy, 0, c.user + " [" + c.time + "]:", 16);
            userTxt.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.CYAN, LEFT, OUTLINE, FlxColor.BLACK);
            commentsGroup.add(userTxt);

            var msgTxt = new FlxText(140, cy + 20, FlxG.width - 280, c.text, 14);
            msgTxt.color = FlxColor.WHITE;
            commentsGroup.add(msgTxt);
        }

        maxScroll = -(data.length * 60) + (FlxG.height - 300);
        if (maxScroll > 0) maxScroll = 0;
    }

    function postComment():Void
    {
        if (ClientPrefs.data.authToken == null || ClientPrefs.data.authToken == "") {
            statusText.text = "You must be logged in to comment.";
            return;
        }
        if (commentInput.text.length == 0) return;

        statusText.text = "Sending...";
        statusText.color = FlxColor.WHITE;

        var http = new Http(OnlineManager.serverURL + "/post_comment");
        http.setHeader("Content-Type", "application/json");
        
        var payload = {
            username: ClientPrefs.data.username,
            token: ClientPrefs.data.authToken,
            chart_id: chartId,
            comment: commentInput.text
        };

        http.setPostData(Json.stringify(payload));
        http.onData = function(res) {
            var r = Json.parse(res);
            if (r.status == "success") {
                commentInput.text = "";
                statusText.text = "Comment posted!";
                statusText.color = FlxColor.LIME;
                targetScrollY = 0; // Reset scroll to top
                fetchComments(); // Refresh list
            } else {
                statusText.text = r.message;
                statusText.color = FlxColor.RED;
            }
        };
        http.onError = function(err) {
            statusText.text = "Failed to post.";
            statusText.color = FlxColor.RED;
        };
        http.request(true);
    }
}
class HashUtil
{
    /**
     * Reads a file and returns its MD5 hash.
     * Returns an empty string if the file doesn't exist.
     */
    public static function getFileHash(path:String):String
    {
        if (!FileSystem.exists(path)) return "";
        
        try {
            var bytes = File.getBytes(path);
            // Convert bytes to a hex string MD5 hash
            return Md5.encode(bytes.toString());
        } catch(e:Dynamic) {
            trace("Hash error: " + e);
            return "";
        }
    }
}

enum MainMenuColumn {
	LEFT;
	CENTER;
	RIGHT;
}



class TutorialSubState extends FlxSubState
{
    public function new()
    {
        super();
    }

override function create()
    {
        super.create();

        // 1. Black Overlay
        var bg = new flixel.FlxSprite().makeGraphic(FlxG.width, FlxG.height, flixel.util.FlxColor.BLACK);
		bg.scrollFactor.set(0, 0); // Lock it to the screen, NOT the world
        bg.cameras = [FlxG.cameras.list[FlxG.cameras.list.length-1]]; // Force it to the top-most camera
        bg.screenCenter(); // Center it
        bg.alpha = 0.85;
        add(bg);

        // 2. Text
		var text = new flixel.text.FlxText(0, 0, 0, 
            "WELCOME TO FNFast!\n\n" +
            "1. Create charts in the 'Creator' menu.\n" +
            "2. Use community uploaded materials to give your charts a unique look.\n" +
            "3. Rank up by beating verified charts.\n\n" +
            "By accepting, you agree to the Terms of Service & Privacy Policy.\n" +
            "Join our Discord and Wiki for tutorials!\n\n" +
            "PRESS ENTER TO START", 24);
        
        text.setFormat(Paths.font("vcr.ttf"), 24, flixel.util.FlxColor.WHITE, CENTER, OUTLINE, flixel.util.FlxColor.BLACK);
        text.borderSize = 2;
        
        // --- ADD THESE 3 LINES ---
        text.scrollFactor.set(0, 0); // Lock it to the screen, NOT the world
        text.cameras = [FlxG.cameras.list[FlxG.cameras.list.length-1]]; // Force it to the top-most camera
        text.screenCenter(); // Center it
        // -------------------------
        
        add(text);
        
        add(text);
    }

    override function update(elapsed:Float)
    {
        super.update(elapsed);

        if (FlxG.keys.justPressed.ENTER)
        {
            FlxG.sound.play(Paths.sound('confirmMenu'));
            close();
        }
    }
}






class ChartsBrowserState extends FlxState
{
    var dataList:Array<Dynamic> = [];
    var mode:String = "charts"; // "charts" or "lists"
    var showUncompletedFirst:Bool = false; // Filter toggle
    
    var listGroup:FlxSpriteGroup;
    var progressBox:FlxSpriteGroup;
    var progressText:FlxText;
    var searchInput:FlxUIInputText;
    var filterBtn:FlxButton;
    
    var scrollY:Float = 0;
    var targetScrollY:Float = 0;
    var maxScroll:Float = 0;

    override public function create():Void
    {
        super.create();
        FlxG.mouse.visible = true;

        add(new FlxSprite().makeGraphic(FlxG.width, FlxG.height, 0xFF121212));
        listGroup = new FlxSpriteGroup();
        add(listGroup);

        // Header
        var header = new FlxSprite().makeGraphic(FlxG.width, 140, 0xFF000000);
        header.alpha = 0.8;
        add(header);

        add(new FlxText(20, 10, 0, "ONLINE BROWSER", 28).setFormat(Paths.font("vcr.ttf"), 28, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK));

        // Tabs
        add(new FlxButton(20, 50, "CHARTS", function() { mode = "charts"; loadData(""); }));
        add(new FlxButton(110, 50, "WEEKS", function() { mode = "lists"; loadData(""); }));

        // Search
        searchInput = new FlxUIInputText(200, 50, 200, "", 16);
        add(searchInput);
        add(new FlxButton(410, 50, "FIND", function() loadData(searchInput.text)));

        // Filter Button
        filterBtn = new FlxButton(20, 90, "Sort: Default", toggleFilter);
        filterBtn.setGraphicSize(150, 20);
        filterBtn.updateHitbox();
        add(filterBtn);

        add(new FlxButton(FlxG.width - 100, 20, "BACK", function() FlxG.switchState(new MainMenuState())));
        
        loadData("");
    }

    override public function update(elapsed:Float)
    {
        super.update(elapsed);
        if (FlxG.mouse.wheel != 0 && (progressBox == null || !progressBox.visible))
            targetScrollY += FlxG.mouse.wheel * 120;

        if (targetScrollY > 0) targetScrollY = 0;
        if (targetScrollY < maxScroll) targetScrollY = maxScroll;
        scrollY = FlxMath.lerp(scrollY, targetScrollY, 0.15);
        listGroup.y = scrollY;
    }

    function toggleFilter() 
    {
        showUncompletedFirst = !showUncompletedFirst;
        filterBtn.text = showUncompletedFirst ? "Sort: Unplayed" : "Sort: Alphabetic";
        applyFilterAndPopulate();
    }

    function loadData(query:String):Void
    {
        var endpoint = (mode == "charts") ? "/charts" : "/lists";
        var url = OnlineManager.serverURL + endpoint + "?q=" + StringTools.urlEncode(query) + "&username=" + StringTools.urlEncode(ClientPrefs.data.username);
        
        var http = new Http(url);
        http.onData = function(res) {
            try {
                dataList = Json.parse(res);
                applyFilterAndPopulate();
            } catch(e:Dynamic) {
                trace("Error parsing data: " + e);
            }
        };
        http.onError = function(err) {
            trace("Server Error: " + err);
        };
        http.request();
    }

    function applyFilterAndPopulate() 
    {
        if (showUncompletedFirst && mode == "charts") {
            // Sort so uncompleted (false) comes first
            dataList.sort(function(a, b) {
                var aComp:Bool = (a.completed == true);
                var bComp:Bool = (b.completed == true);
                if (aComp == bComp) return 0;
                if (aComp && !bComp) return 1;
                return -1;
            });
        }
        populateList();
    }

    function populateList():Void
    {
        listGroup.clear();

        if (dataList.length == 0)
        {
            var welcomeText = new FlxText(0, 200, FlxG.width, "NO CONTENT FOUND!\n\nBe the first to create and publish\nin the Creator Menu!", 24);
            welcomeText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER);
            listGroup.add(welcomeText);
            maxScroll = 0;
            return;
        }

        for (i in 0...dataList.length)
        {
            var item = dataList[i];
            var yOffset = 150 + (i * 110); // Increased slot height to 110 for description
            
            var isFeatured:Bool = (mode == "charts" && item.featured == true);
            var isCompleted:Bool = (item.completed == true);
            
            // Slot Background (Featured = Gold, Completed = Slight Green Tint)
            var slotColor:FlxColor = isFeatured ? 0xFF3D3814 : 0xFF1F1F1F;
            if (mode == "charts" && isCompleted) slotColor = 0xFF1A3320; 

            var slot = new FlxSprite(50, yOffset).makeGraphic(FlxG.width - 100, 100, slotColor);
            slot.alpha = 0.8;
            listGroup.add(slot);

            var author = (item.author != null && item.author != "") ? item.author : "Unknown";

            if (mode == "charts")
            {
                // ==========================================
                // CHART MODE UI
                // ==========================================
                var displayRating:Float = (item.manual_rating != null) ? item.manual_rating : (item.suggested_rating != null ? item.suggested_rating : 0);
                
                var rankName:String = "EASY";
                var rankColor:FlxColor = FlxColor.LIME;

                if (displayRating > 60)  { rankName = "MEDIUM"; rankColor = FlxColor.YELLOW; }
                if (displayRating > 100) { rankName = "HARD"; rankColor = FlxColor.ORANGE; }
                if (displayRating > 130) { rankName = "INSANE"; rankColor = FlxColor.PURPLE; }
                if (displayRating > 150) { rankName = "DEMON"; rankColor = 0xFFFF0077; }
                if (displayRating > 250) { rankName = "EXTREME"; rankColor = 0xFFFF0000; }

                var songText = new FlxText(70, yOffset + 10, slot.width - 250, item.name.toUpperCase(), 22);
                songText.setFormat(Paths.font("vcr.ttf"), 22, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
                listGroup.add(songText);

                var statusStr = (item.status != null) ? item.status.toUpperCase() : "UNKNOWN";
                var authorText = new FlxText(70, yOffset + 35, 0, "BY: " + author.toUpperCase() + " [" + statusStr + "]", 14);
                authorText.color = (item.status == "verified") ? FlxColor.LIME : 0xFFAAAAAA;
                listGroup.add(authorText);

                // DESCRIPTION
                var descStr = (item.desc != null && item.desc != "") ? item.desc : "No description provided.";
                if(descStr.length > 55) descStr = descStr.substring(0, 52) + "...";
                var descText = new FlxText(70, yOffset + 55, slot.width - 250, descStr, 14);
                descText.color = 0xFFCCCCCC;
                listGroup.add(descText);

                // DIFFICULTY BADGE
                var diffText = new FlxText(slot.x + slot.width - 220, yOffset + 10, 150, rankName + "\n" + displayRating + " ★", 18);
                diffText.setFormat(Paths.font("vcr.ttf"), 18, rankColor, CENTER, OUTLINE, FlxColor.BLACK);
                listGroup.add(diffText);

                // LIKE BUTTON
                var likes = (item.likes != null) ? item.likes : 0;
                var likeBtn = new FlxButton(slot.x + slot.width - 220, yOffset + 55, "Likes: " + likes, function() {
                    likeChart(item.id, i);
                });
                likeBtn.color = 0xFFFF6666;
                listGroup.add(likeBtn);
				var commentBtn = new FlxButton(slot.x + slot.width - 220, yOffset + 80, "💬 COMMENTS", function() {
        	
					
        			openSubState(new CommentsSubState(item.id, item.name));
				});
				listGroup.add(commentBtn);
                if(isFeatured) {
                    var featText = new FlxText(slot.x + slot.width - 220, yOffset + 80, 150, "FEATURED", 12);
                    featText.setFormat(Paths.font("vcr.ttf"), 12, FlxColor.YELLOW, CENTER, OUTLINE, FlxColor.BLACK);
                    listGroup.add(featText);
                }
            }
            else
            {
                // ==========================================
                // PLAYLIST MODE UI
                // ==========================================
                var listText = new FlxText(70, yOffset + 10, slot.width - 250, "WEEK: " + item.name.toUpperCase(), 22);
                listText.setFormat(Paths.font("vcr.ttf"), 22, FlxColor.YELLOW, LEFT, OUTLINE, FlxColor.BLACK);
                listGroup.add(listText);

                var authorText = new FlxText(70, yOffset + 35, 0, "CREATOR: " + author.toUpperCase(), 14);
                authorText.color = FlxColor.LIME;
                listGroup.add(authorText);

                var songString = "No tracks";
                if (item.charts != null) {
                    var songArray:Array<String> = cast item.charts;
                    songString = songArray.join(", ");
                    if (songString.length > 55) {
                        songString = songString.substring(0, 52) + "...";
                    }
                }

                var trackText = new FlxText(70, yOffset + 60, slot.width - 150, "TRACKS: " + songString, 12);
                trackText.color = 0xFFAAAAAA;
                listGroup.add(trackText);
            }

            // ==========================================
            // DOWNLOAD BUTTON
            // ==========================================
            var dlBtn = new FlxButton(slot.x + slot.width - 110, yOffset + 35, "GET", function() {
                if (mode == "charts") {
                    downloadChart(item.id, item.name);
                } else {
                    var playlist:Array<String> = cast item.charts;
                    downloadPlaylist(item.name, playlist);
                }
            });
            dlBtn.setGraphicSize(80, 40);
            dlBtn.updateHitbox();
            listGroup.add(dlBtn);
        }

        // ==========================================
        // CALL TO ACTION (End of list message)
        // ==========================================
        var endY = 150 + (dataList.length * 110) + 20;
        var endOfListText = new FlxText(0, endY, FlxG.width, 
            "--- End of the list ---\nInspired? Create and Publish your own content!", 18);
        endOfListText.setFormat(Paths.font("vcr.ttf"), 18, 0xFF666666, CENTER);
        listGroup.add(endOfListText);
        
        var spacer = new FlxSprite(0, endY + 80).makeGraphic(1, 1, 0x00000000);
        listGroup.add(spacer);

        maxScroll = -(endY + 100) + FlxG.height;
        if (maxScroll > 0) maxScroll = 0;
    }

    function likeChart(id:String, index:Int) 
    {
        if(ClientPrefs.data.authToken == "") return;

        var http = new Http(OnlineManager.serverURL + "/like_chart");
        http.setHeader("Content-Type", "application/json");
        http.setPostData(Json.stringify({
            username: ClientPrefs.data.username,
            token: ClientPrefs.data.authToken,
            chart_id: id
        }));
        
        http.onData = function(res) {
            var data = Json.parse(res);
            dataList[index].likes = data.likes;
            populateList(); // Refresh UI instantly
        };
        http.request(true);
    }

    function downloadPlaylist(playlistName:String, chartIDs:Array<String>)
    {
        for(id in chartIDs) {
            var cleanID = StringTools.trim(id);
            downloadChart(cleanID, cleanID); 
        }

        backend.ChartInstaller.createWeekFile(playlistName, chartIDs);
        WeekData.reloadWeekFiles();
        FlxG.switchState(new states.StoryMenuState());
    }

    function downloadChart(id:String, name:String)
    {
        showProgress(name);

        var http = new Http(OnlineManager.serverURL + "/download_chart?id=" + id);
        http.onBytes = function(bytes:haxe.io.Bytes) {
            var norm = ChartUtil.normalizeSong(name);
            var path = "temp/" + norm + ".zip";
            if (!sys.FileSystem.exists("temp")) sys.FileSystem.createDirectory("temp");
            sys.io.File.saveBytes(path, bytes);
            ChartInstaller.install(norm, path);
            if(sys.FileSystem.exists(path)) sys.FileSystem.deleteFile(path);
            remove(progressBox);
            FlxG.switchState(new states.FreeplayState());
        };
        http.request();
    }

    function showProgress(name:String) 
    {
        progressBox = new FlxSpriteGroup();
        progressBox.add(new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK));
        var t = new FlxText(0,0,0,"DOWNLOADING: " + name, 32);
        t.screenCenter();
        progressBox.add(t);
        add(progressBox);
    }
}

class MainMenuState extends MusicBeatState
{
	public static var psychEngineVersion:String = ''; // This is also used for Discord RPC
	public static var curSelected:Int = 0;
	public static var curColumn:MainMenuColumn = CENTER;
	var allowMouse:Bool = true; //Turn this off to block mouse movement in menus

	var menuItems:FlxTypedGroup<FlxSprite>;
	var leftItem:FlxSprite;
	var rightItem:FlxSprite;

	//Centered/Text options
	var optionShit:Array<String> = [
		'story_mode',
		'freeplay',
		'online',
		'credits'];

	var leftOption:String = #if ACHIEVEMENTS_ALLOWED 'achievements' #else null #end;
	var rightOption:String = 'options';

	var magenta:FlxSprite;
	var camFollow:FlxObject;

	static var showOutdatedWarning:Bool = true;
	function openChartsBrowser()
	{
    	FlxG.switchState(new ChartsBrowserState());
	}
override function closeSubState()
{
    super.closeSubState();
    persistentUpdate = true;
}
	override function create()
	{
		super.create();

		#if MODS_ALLOWED
		Mods.pushGlobalMods();
		#end
		Mods.loadTopMod();

		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end

		persistentUpdate = persistentDraw = true;

		var yScroll:Float = 0.25;
		var bg:FlxSprite = new FlxSprite(-80).loadGraphic(Paths.image('menuBG'));
		bg.antialiasing = ClientPrefs.data.antialiasing;
		bg.scrollFactor.set(0, yScroll);
		bg.setGraphicSize(Std.int(bg.width * 1.175));
		bg.updateHitbox();
		bg.screenCenter();
		add(bg);
		var creatorBtn = new FlxButton(50, 460, "Creator", function()
		{
			FlxG.switchState(new CreatorMenuState());
		});
		add(creatorBtn);

		function openChartsBrowser():Void
		{
			FlxG.switchState(new ChartsBrowserState());
		}
		camFollow = new FlxObject(0, 0, 1, 1);
		add(camFollow);

		magenta = new FlxSprite(-80).loadGraphic(Paths.image('menuDesat'));
		magenta.antialiasing = ClientPrefs.data.antialiasing;
		magenta.scrollFactor.set(0, yScroll);
		magenta.setGraphicSize(Std.int(magenta.width * 1.175));
		magenta.updateHitbox();
		magenta.screenCenter();
		magenta.visible = false;
		magenta.color = 0xFFfd719b;
		add(magenta);

		menuItems = new FlxTypedGroup<FlxSprite>();
		add(menuItems);

		for (num => option in optionShit)
		{
			var item:FlxSprite = createMenuItem(option, 0, (num * 140) + 90);
			item.y += (4 - optionShit.length) * 70; // Offsets for when you have anything other than 4 items
			item.screenCenter(X);
		}

		if (leftOption != null)
			leftItem = createMenuItem(leftOption, 60, 490);
		if (rightOption != null)
		{
			rightItem = createMenuItem(rightOption, FlxG.width - 60, 490);
			rightItem.x -= rightItem.width;
		}

		var psychVer:FlxText = new FlxText(12, FlxG.height - 44, 0, "FNFast", 12);
		psychVer.scrollFactor.set();
		psychVer.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(psychVer);
		var fnfVer:FlxText = new FlxText(12, FlxG.height - 24, 0, "Friday Night Funkin' v" + Application.current.meta.get('version'), 12);
		fnfVer.scrollFactor.set();
		fnfVer.setFormat(Paths.font("vcr.ttf"), 16, FlxColor.WHITE, LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		add(fnfVer);
		changeItem();

		#if ACHIEVEMENTS_ALLOWED
		// Unlocks "Freaky on a Friday Night" achievement if it's a Friday and between 18:00 PM and 23:59 PM
		var leDate = Date.now();
		if (leDate.getDay() == 5 && leDate.getHours() >= 18)
			Achievements.unlock('friday_night_play');

		#if MODS_ALLOWED
		Achievements.reloadList();
		#end
		#end



		if (!ClientPrefs.data.seenTutorial) 
			{
				persistentUpdate = false; 
       			openSubState(new TutorialSubState());
				ClientPrefs.data.seenTutorial = true;
				ClientPrefs.saveSettings();
			}


		#if CHECK_FOR_UPDATES
		if (showOutdatedWarning && ClientPrefs.data.checkForUpdates && substates.OutdatedSubState.updateVersion != psychEngineVersion) {
			persistentUpdate = false;
			showOutdatedWarning = false;
			openSubState(new substates.OutdatedSubState());
		}
		#end

		FlxG.camera.follow(camFollow, null, 0.15);
	}

	function createMenuItem(name:String, x:Float, y:Float):FlxSprite
	{
		var menuItem:FlxSprite = new FlxSprite(x, y);
		menuItem.frames = Paths.getSparrowAtlas('mainmenu/menu_$name');
		menuItem.animation.addByPrefix('idle', '$name idle', 24, true);
		menuItem.animation.addByPrefix('selected', '$name selected', 24, true);
		menuItem.animation.play('idle');
		menuItem.updateHitbox();
		
		menuItem.antialiasing = ClientPrefs.data.antialiasing;
		menuItem.scrollFactor.set();
		menuItems.add(menuItem);
		return menuItem;
	}

	var selectedSomethin:Bool = false;

	var timeNotMoving:Float = 0;
	override function update(elapsed:Float)
	{
		if (controls == null) return;

		if (FlxG.sound.music.volume < 0.8)
			FlxG.sound.music.volume = Math.min(FlxG.sound.music.volume + 0.5 * elapsed, 0.8);

		if (!selectedSomethin)
		{
			if (controls.UI_UP_P)
				changeItem(-1);

			if (controls.UI_DOWN_P)
				changeItem(1);

			var allowMouse:Bool = allowMouse;
			if (allowMouse && ((FlxG.mouse.deltaScreenX != 0 && FlxG.mouse.deltaScreenY != 0) || FlxG.mouse.justPressed)) //FlxG.mouse.deltaScreenX/Y checks is more accurate than FlxG.mouse.justMoved
			{
				allowMouse = false;
				FlxG.mouse.visible = true;
				timeNotMoving = 0;

				var selectedItem:FlxSprite;
				switch(curColumn)
				{
					case CENTER:
						selectedItem = menuItems.members[curSelected];
					case LEFT:
						selectedItem = leftItem;
					case RIGHT:
						selectedItem = rightItem;
				}

				if(leftItem != null && FlxG.mouse.overlaps(leftItem))
				{
					allowMouse = true;
					if(selectedItem != leftItem)
					{
						curColumn = LEFT;
						changeItem();
					}
				}
				else if(rightItem != null && FlxG.mouse.overlaps(rightItem))
				{
					allowMouse = true;
					if(selectedItem != rightItem)
					{
						curColumn = RIGHT;
						changeItem();
					}
				}
				else
				{
					var dist:Float = -1;
					var distItem:Int = -1;
					for (i in 0...optionShit.length)
					{
						var memb:FlxSprite = menuItems.members[i];
						if(FlxG.mouse.overlaps(memb))
						{
							var distance:Float = Math.sqrt(Math.pow(memb.getGraphicMidpoint().x - FlxG.mouse.screenX, 2) + Math.pow(memb.getGraphicMidpoint().y - FlxG.mouse.screenY, 2));
							if (dist < 0 || distance < dist)
							{
								dist = distance;
								distItem = i;
								allowMouse = true;
							}
						}
					}

					if(distItem != -1 && selectedItem != menuItems.members[distItem])
					{
						curColumn = CENTER;
						curSelected = distItem;
						changeItem();
					}
				}
			}
			else
			{
				timeNotMoving += elapsed;
				if(timeNotMoving > 2) FlxG.mouse.visible = false;
			}

			switch(curColumn)
			{
				case CENTER:
					if(controls.UI_LEFT_P && leftOption != null)
					{
						curColumn = LEFT;
						changeItem();
					}
					else if(controls.UI_RIGHT_P && rightOption != null)
					{
						curColumn = RIGHT;
						changeItem();
					}

				case LEFT:
					if(controls.UI_RIGHT_P)
					{
						curColumn = CENTER;
						changeItem();
					}

				case RIGHT:
					if(controls.UI_LEFT_P)
					{
						curColumn = CENTER;
						changeItem();
					}
			}

			if (controls.BACK)
			{
				selectedSomethin = true;
				FlxG.mouse.visible = false;
				FlxG.sound.play(Paths.sound('cancelMenu'));
				MusicBeatState.switchState(new TitleState());
			}

			if (controls.ACCEPT || (FlxG.mouse.justPressed && allowMouse))
			{
				FlxG.sound.play(Paths.sound('confirmMenu'));
				selectedSomethin = true;


				if (ClientPrefs.data.flashing)
					FlxFlicker.flicker(magenta, 1.1, 0.15, false);

				var item:FlxSprite;
				var option:String;
				switch(curColumn)
				{
					case CENTER:
						option = optionShit[curSelected];
						item = menuItems.members[curSelected];

					case LEFT:
						option = leftOption;
						item = leftItem;

					case RIGHT:
						option = rightOption;
						item = rightItem;
				}

				FlxFlicker.flicker(item, 1, 0.06, false, false, function(flick:FlxFlicker)
				{
					switch (option)
					{
						case 'story_mode':
							MusicBeatState.switchState(new StoryMenuState());
						case 'freeplay':
							MusicBeatState.switchState(new FreeplayState());



						#if ACHIEVEMENTS_ALLOWED
						case 'achievements':
							MusicBeatState.switchState(new AchievementsMenuState());
						#end
						case 'online':
    						FlxG.switchState(new ChartsBrowserState());
						case 'credits':
							MusicBeatState.switchState(new CreditsState());
						case 'options':
							MusicBeatState.switchState(new OptionsState());
							OptionsState.onPlayState = false;
							if (PlayState.SONG != null)
							{
								PlayState.SONG.arrowSkin = null;
								PlayState.SONG.splashSkin = null;
								PlayState.stageUI = 'normal';
							}
						case 'donate':
							CoolUtil.browserLoad('https://ninja-muffin24.itch.io/funkin');
							selectedSomethin = false;
							item.visible = true;
						default:
							trace('Menu Item ${option} doesn\'t do anything');
							selectedSomethin = false;
							item.visible = true;
					}
				});
				
				for (memb in menuItems)
				{
					if(memb == item)
						continue;

					FlxTween.tween(memb, {alpha: 0}, 0.4, {ease: FlxEase.quadOut});
				}
			}
			#if desktop
			if (controls.justPressed('debug_1'))
			{
				selectedSomethin = true;
				FlxG.mouse.visible = false;
				MusicBeatState.switchState(new MasterEditorMenu());
			}
			#end
		}

		super.update(elapsed);
	}

	function changeItem(change:Int = 0)
	{
		if(change != 0) curColumn = CENTER;
		curSelected = FlxMath.wrap(curSelected + change, 0, optionShit.length - 1);
		FlxG.sound.play(Paths.sound('scrollMenu'));

		for (item in menuItems)
		{
			item.animation.play('idle');
			item.centerOffsets();
		}

		var selectedItem:FlxSprite;
		switch(curColumn)
		{
			case CENTER:
				selectedItem = menuItems.members[curSelected];
			case LEFT:
				selectedItem = leftItem;
			case RIGHT:
				selectedItem = rightItem;
		}
		selectedItem.animation.play('selected');
		selectedItem.centerOffsets();
		camFollow.y = selectedItem.getGraphicMidpoint().y;
	}
}
