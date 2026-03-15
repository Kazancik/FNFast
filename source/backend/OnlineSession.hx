package backend;


class OnlineSession
{
    // List of materials active for the current song
    public static var activeMaterials:Array<String> = [];

    public static function reset() {
        activeMaterials = [];
    }

    public static function addMaterial(name:String) {
        if(!activeMaterials.contains(name)) activeMaterials.push(name);
    }
}