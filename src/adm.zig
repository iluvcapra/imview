const std = @import("std");
const AnyWriter = std.io.AnyWriter;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const StringHashMap = std.hash_map.StringHashMap;

const xml_additions = @import("xml_additions.zig");
const xpath_string_value = xml_additions.xpath_string_value;
const xpath_nodeset_value = xml_additions.xpath_nodeset_value;

const wave = @import("wave.zig");
const xml = @cImport({
    @cInclude("libxml2/libxml/parser.h");
    @cInclude("libxml2/libxml/tree.h");
    @cInclude("libxml2/libxml/xpath.h");
    @cInclude("libxml2/libxml/xpathInternals.h");
    @cInclude("libxml2/libxml/xmlmemory.h");
});

const Database = struct {
    audio_programme_map: StringHashMap(AudioProgramme),
    audio_content_map: StringHashMap(AudioContent),
    audio_object_map: StringHashMap(AudioObject),
    allocator: Allocator,

    fn init(allocator: Allocator) @This() {
        const audio_programme_map = StringHashMap(AudioProgramme).init(allocator);
        const audio_content_map = StringHashMap(AudioContent).init(allocator);
        const audio_object_map = StringHashMap(AudioObject).init(allocator);

        return @This(){
            .audio_programme_map = audio_programme_map,
            .audio_content_map = audio_content_map,
            .audio_object_map = audio_object_map,
            .allocator = allocator,
        };
    }

    fn insertAudioProgramme(self: *@This(), programme: AudioProgramme) void {
        self.audio_programme_map.put(programme.audioProgrammeID, programme) catch {
            @panic("HashMap.put() failed!");
        };
    }

    fn insertAudioContent(self: *@This(), content: AudioContent) void {
        self.audio_content_map.put(content.audioContentID, content) catch {
            @panic("HashMap.put() failed!");
        };
    }

    fn insertAudioObject(self: *@This(), object: AudioObject) void {
        self.audio_object_map.put(object.audioObjectID, object) catch {
            @panic("HashMap.put() failed!");
        };
    }

    fn deinit(self: *@This()) void {
        {
            var i = self.audio_programme_map.valueIterator();
            while (i.next()) |v| {
                v.deinit();
            }
            self.audio_programme_map.deinit();
        }
        {
            var i = self.audio_content_map.valueIterator();
            while (i.next()) |v| {
                v.deinit();
            }
            self.audio_content_map.deinit();
        }
        {
            var i = self.audio_object_map.valueIterator();
            while (i.next()) |v| {
                v.deinit();
            }
            self.audio_object_map.deinit();
        }
    }
};

const AudioProgramme = struct {
    audioProgrammeID: []const u8,
    audioProgrammeName: []const u8,
    start: []const u8,
    end: []const u8,
    audioContentIDs: [][]const u8,
    allocator: Allocator,

    fn init(allocator: Allocator, xpath_ctx: xml.xmlXPathContextPtr) @This() {
        const audioProgrammeID = xpath_string_value("string(//adm:audioFormatExtended/" ++
            "adm:audioProgramme[1]/@audioProgrammeID)", xpath_ctx, null, allocator);
        if (audioProgrammeID.len == 0) {
            @panic("audioProgramme not found!");
        }
        const audioProgrammeName = xpath_string_value("string(//*/adm:audioProgramme[1]/" ++
            "@audioProgrammeName)", xpath_ctx, null, allocator);
        const start = xpath_string_value("string(//*/adm:audioProgramme[1]/@start)", xpath_ctx, null, allocator);
        const end = xpath_string_value("string(//*/adm:audioProgramme[1]/@end)", xpath_ctx, null, allocator);

        var contentIds = ArrayList([]const u8).init(allocator);
        defer contentIds.deinit();

        var acoIter = xpath_nodeset_value("//adm:audioProgramme[1]/adm:audioContentIDRef", xpath_ctx, null);

        while (acoIter.next()) |node| {
            const this_id = xpath_string_value("string(./text())", xpath_ctx, node, allocator);
            contentIds.append(this_id) catch {
                @panic("ArrayList.append() failed!");
            };
        }

        return @This(){
            .audioProgrammeID = audioProgrammeID,
            .audioProgrammeName = audioProgrammeName,
            .start = start,
            .end = end,
            .audioContentIDs = contentIds.toOwnedSlice() catch {
                @panic("Failed to allocate owned slice");
            },
            .allocator = allocator,
        };
    }

    fn deinit(self: @This()) void {
        for (self.audioContentIDs) |id| {
            self.allocator.free(id);
        }
        self.allocator.free(self.audioContentIDs);
        self.allocator.free(self.audioProgrammeID);
        self.allocator.free(self.audioProgrammeName);
        self.allocator.free(self.start);
        self.allocator.free(self.end);
    }
};

const AudioContent = struct {
    audioContentID: []const u8,
    audioContentName: []const u8,
    audioObjectIDs: [][]const u8,
    allocator: Allocator,

    fn add_all(xpath_ctx: xml.xmlXPathContextPtr, database: *Database) void {
        var content_iter = xpath_nodeset_value("//adm:audioFormatExtended/adm:audioContent", xpath_ctx, null);
        while (content_iter.next()) |node| {
            const id = xpath_string_value("string(./@audioContentID)", xpath_ctx, node, database.allocator);
            const name = xpath_string_value("string(./@audioContentName)", xpath_ctx, node, database.allocator);
            var obj_refs = ArrayList([]const u8).init(database.allocator);
            var obj_ref_nodes = xpath_nodeset_value("./adm:audioObjectIDRef", xpath_ctx, node);
            while (obj_ref_nodes.next()) |obj_ref_node| {
                const obj_ref = xpath_string_value("string(./text())", xpath_ctx, obj_ref_node, database.allocator);
                obj_refs.append(obj_ref) catch {
                    @panic("ArrayList append() failed!");
                };
            }
            database.insertAudioContent(@This(){
                .audioContentID = id,
                .audioContentName = name,
                .audioObjectIDs = obj_refs.toOwnedSlice() catch {
                    @panic("toOwnedSlice() failed!");
                },
                .allocator = database.allocator,
            });
        }
    }

    fn deinit(self: @This()) void {
        for (self.audioObjectIDs) |oid| {
            self.allocator.free(oid);
        }
        self.allocator.free(self.audioObjectIDs);
        self.allocator.free(self.audioContentID);
        self.allocator.free(self.audioContentName);
    }
};

const AudioObject = struct {
    audioObjectID: []const u8,
    audioObjectName: []const u8,
    start: []const u8,
    duration: []const u8,
    audioPackFormatIDs: [][]const u8,
    // audioTrackUIDs: [][]const u8,
    // audioObjectIDs: [][]const u8,
    allocator: Allocator,

    fn add_all(xpath_ctx: xml.xmlXPathContextPtr, database: *Database) void {
        var object_iter = xpath_nodeset_value("//adm:audioFormatExtended/adm:audioObject", xpath_ctx, null);
        while (object_iter.next()) |node| {
            const id = xpath_string_value("string(./@audioObjectID)", xpath_ctx, node, database.allocator);
            const name = xpath_string_value("string(./@audioObjectName)", xpath_ctx, node, database.allocator);
            const start = xpath_string_value("string(./@start)", xpath_ctx, node, database.allocator);
            const duration = xpath_string_value("string(./@duration)", xpath_ctx, node, database.allocator);
            var pfi = xpath_nodeset_value("./audioPackFormatIDRef", xpath_ctx, node);
            var pack_format_refs = ArrayList([]const u8).init(database.allocator);
            defer pack_format_refs.deinit();
            while (pfi.next()) |pfi_node| {
                const pack_format = xpath_string_value("string(./text())", xpath_ctx, pfi_node, database.allocator);
                pack_format_refs.append(pack_format) catch {
                    @panic("append() failed!");
                };
            }
            database.insertAudioObject(@This(){
                .audioObjectID = id,
                .audioObjectName = name,
                .start = start,
                .duration = duration,
                .audioPackFormatIDs = pack_format_refs.toOwnedSlice() catch {
                    @panic("append() failed!");
                },
                .allocator = database.allocator,
            });
        }
    }

    fn deinit(self: @This()) void {
        self.allocator.free(self.audioObjectID);
        self.allocator.free(self.audioObjectName);
        self.allocator.free(self.start);
        self.allocator.free(self.duration);
    }
};

pub fn print_adm_xml_summary(adm_xml: []const u8, writer: AnyWriter) !void {
    xml.xmlInitParser();
    defer xml.xmlCleanupParser();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    defer _ = gpa.deinit();

    const doc: xml.xmlDocPtr = xml.xmlReadMemory(@ptrCast(adm_xml), @intCast(adm_xml.len), null, "utf-8", 0) orelse {
        @panic("axml could not be parsed!");
    };
    defer xml.xmlFreeDoc(doc);

    const xpath_ctx: xml.xmlXPathContextPtr = xml.xmlXPathNewContext(doc) orelse {
        @panic("xmlXPathNewContext Failed!");
    };
    defer xml.xmlXPathFreeContext(xpath_ctx);

    if (xml.xmlXPathRegisterNs(xpath_ctx, "adm", "urn:ebu:metadata-schema:ebuCore_2016") != 0) {
        @panic("xmlXPathRegisterNs Failed!");
    }

    var database = Database.init(allocator);
    defer database.deinit();

    database.insertAudioProgramme(AudioProgramme.init(allocator, xpath_ctx));
    AudioContent.add_all(xpath_ctx, &database);
    AudioObject.add_all(xpath_ctx, &database);

    var programme_iter = database.audio_programme_map.valueIterator();
    while (programme_iter.next()) |programme| {
        try writer.print("AudioProgramme ({s}) \"{s}\"\n", .{ programme.audioProgrammeID, programme.audioProgrammeName });
        for (programme.audioContentIDs) |ac_id| content_blk: {
            const audio_content = database.audio_content_map.get(ac_id) orelse {
                try writer.print(" ? *{s}\n", .{ac_id});
                break :content_blk;
            };
            try writer.print(" + AudioContent ({s}) \"{s}\"\n", .{ audio_content.audioContentID, audio_content.audioContentName });
            for (audio_content.audioObjectIDs) |ao_id| object_blk: {
                const audio_object = database.audio_object_map.get(ao_id) orelse {
                    try writer.print("   ? *{s}\n", .{ao_id});
                    break :object_blk;
                };
                try writer.print("   + AudioObject ({s}) \"{s}\"\n", .{ audio_object.audioObjectID, audio_object.audioObjectName });
            }
        }
    }
}
