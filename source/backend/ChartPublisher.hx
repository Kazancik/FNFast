package backend;

import sys.io.File;
import sys.FileSystem;
import haxe.io.Bytes;
import haxe.io.BytesOutput;
import haxe.ds.List;
import haxe.zip.Writer;
import haxe.zip.Entry;

class ChartPublisher
{
    /**
     * Builds the ZIP for publishing. 
     * Supports both local .ogg files and SoundCloud links.
     */
    public static function buildZip(
        songName:String,
        chartPath:String,
        instPath:String,    // Local path (or null if using link)
        voicesPath:String,  // Local path (or null if using link)
        ?scInst:String,     // SoundCloud link for Instrumental
        ?scVoices:String    // SoundCloud link for Voices
    ):String
    {
        var normalized = ChartUtil.normalizeSong(songName);

        var outDir = "export/";
        if (!FileSystem.exists(outDir))
            FileSystem.createDirectory(outDir);

        var entries = new List<Entry>();

        // 1. PACK CHART JSON
        if (FileSystem.exists(chartPath))
            entries.add(makeEntry(normalized + ".json", File.getBytes(chartPath)));

        // 2. INSTRUMENTAL LOGIC (Link preferred over File)
        if (scInst != null && scInst.length > 5) 
        {
            entries.add(makeEntry("inst_source.txt", Bytes.ofString(scInst)));
            trace("Packed Inst Link");
        } 
        else if (instPath != null && FileSystem.exists(instPath)) 
        {
            entries.add(makeEntry("Inst.ogg", File.getBytes(instPath)));
            trace("Packed Local Inst File");
        }

        // 3. VOICES LOGIC (Link preferred over File)
        if (scVoices != null && scVoices.length > 5) 
        {
            entries.add(makeEntry("voices_source.txt", Bytes.ofString(scVoices)));
            trace("Packed Voices Link");
        } 
        else if (voicesPath != null && FileSystem.exists(voicesPath)) 
        {
            entries.add(makeEntry("Voices.ogg", File.getBytes(voicesPath)));
            trace("Packed Local Voices File");
        }

        // 4. GENERATE ZIP
        var output = new BytesOutput();
        var writer = new Writer(output);
        writer.write(entries);

        var zipBytes = output.getBytes();
        var finalPath = outDir + normalized + ".zip";
        
        File.saveBytes(finalPath, zipBytes);
        trace("Successfully built publish package: " + finalPath);

        return finalPath;
    }

    static function makeEntry(name:String, bytes:Bytes):Entry
    {
        return {
            fileName: name,
            fileSize: bytes.length,
            dataSize: bytes.length, 
            data: bytes,
            crc32: haxe.crypto.Crc32.make(bytes),
            compressed: false,
            fileTime: Date.now(),
            extraFields: null
        };
    }
}