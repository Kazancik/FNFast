package backend;

import sys.io.File;
import haxe.io.Bytes;
import haxe.io.BytesOutput;
import haxe.ds.List;
import haxe.zip.Writer;
import haxe.zip.Entry;
import sys.io.File;
import sys.FileSystem;
import haxe.io.Bytes;
import haxe.io.BytesOutput;
import haxe.ds.List;
import haxe.zip.Writer;
import haxe.zip.Entry;
import haxe.crypto.Crc32;
import Date;



class ChartPublisher
{
        public static function buildZip(
            chartPath:String,
            instPath:String,
            voicesPath:String,
            songName:String
        ):String
        {
            trace("ChartPublisher.buildZip: chartPath=" + chartPath + ", instPath=" + instPath + ", voicesPath=" + Std.string(voicesPath) + ", songName=" + songName);

            // sanity checks
            if (!FileSystem.exists(chartPath))
                throw "Chart file not found: " + chartPath;
            if (!FileSystem.exists(instPath))
                throw "Inst file not found: " + instPath;
            if (voicesPath != null && !FileSystem.exists(voicesPath))
                trace("Warning: voices path does not exist: " + voicesPath);

            var chartBytes:Bytes = File.getBytes(chartPath);
            var instBytes:Bytes = File.getBytes(instPath);
            var voicesBytes:Bytes = if (voicesPath != null && FileSystem.exists(voicesPath)) File.getBytes(voicesPath) else null;

            trace("Sizes => chart: " + Std.string(chartBytes.length) + ", inst: " + Std.string(instBytes.length) + ", voices: " + Std.string(voicesBytes == null ? 0 : voicesBytes.length));

            var entries = new List<Entry>();

            entries.add(makeEntry(songName + "/" + songName + "-normal.json", chartBytes));
            entries.add(makeEntry(songName + "/Inst.ogg", instBytes));

            if (voicesBytes != null)
                entries.add(makeEntry(songName + "/Voices.ogg", voicesBytes));

            // BUILD ZIP
            var output = new BytesOutput();
            var writer = new Writer(output);

            // Debug: number of entries
            var count = 0;
            for (e in entries) count++;
            trace("Writer: entries count = " + Std.string(count));

            // write and persist
            writer.write(entries);

            var zipBytes = output.getBytes();
            trace("zip length = " + Std.string(zipBytes.length) + " bytes");

            var zipPath = "publish_" + songName + ".zip";
            File.saveBytes(zipPath, zipBytes);
            trace("Saved zip to " + zipPath);

            return zipPath;
        }


    

    // -------------------------------------------------
    // CREATE ZIP ENTRY
    // -------------------------------------------------

    static function makeEntry(name:String, bytes:Bytes):Entry
    {
        return {
            fileName: name,
            fileSize: bytes.length,
            dataSize: bytes.length, // ⭐ REQUIRED
            data: bytes,
            crc32: null,
            compressed: false,
            fileTime: Date.now(),
            extraFields: null
        };
    }
}
