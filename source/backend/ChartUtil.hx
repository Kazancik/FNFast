package backend;

class ChartUtil
{
    public static function normalizeSong(name:String):String
    {
        var s = name.toLowerCase();
        s = StringTools.replace(s, " ", "-");

        var out = "";

        for (i in 0...s.length)
        {
            var c = s.charAt(i);

            if (
                (c >= "a" && c <= "z") ||
                (c >= "0" && c <= "9") ||
                c == "-"
            )
                out += c;
        }

        return out;
    }
}
