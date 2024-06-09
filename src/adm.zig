const std = @import("std");
const AnyWriter = std.io.AnyWriter;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const StringHashMap = std.hash_map.StringHashMap;

const xml_additions = @import("xml_additions.zig");
const XPathStringValue = xml_additions.XPathStringValue;
const XPathNodeSetValue = xml_additions.XPathNodeSetValue;

const wave = @import("wave.zig");
const xml = @cImport({
    @cInclude("libxml2/libxml/parser.h");
    @cInclude("libxml2/libxml/tree.h");
    @cInclude("libxml2/libxml/xpath.h");
    @cInclude("libxml2/libxml/xpathInternals.h");
    @cInclude("libxml2/libxml/xmlmemory.h");
});

/// A helper to read Ref IDs from a node, returns a slice owned by `allocator`
fn extractRefs(node_expr: []const u8, xpath_ctx: xml.xmlXPathContextPtr, root_node: xml.xmlNodePtr, allocator: Allocator) [][]const u8 {
    var refs_list = ArrayList([]const u8).init(allocator);
    defer refs_list.deinit();
    var ref_nodes = XPathNodeSetValue(node_expr, xpath_ctx, root_node);
    while (ref_nodes.next()) |a_ref| {
        const ref_str = XPathStringValue("string(./text())", xpath_ctx, a_ref, allocator);
        refs_list.append(ref_str) catch {
            @panic("ArrayList.append() failed!");
        };
    }
    return refs_list.toOwnedSlice() catch {
        @panic("Failed to allocate toOwnedSlice()");
    };
}

inline fn freeStrList(x: [][]const u8, allocator: Allocator) void {
    for (x) |v| {
        allocator.free(v);
    }
    allocator.free(x);
}

const DatabaseRecordTag = enum {
    audioProgramme,
    audioContent,
    audioObject,
    audioPackFormat,
    audioChannelFormat,
    audioStreamFormat,
    // audioBlockFormat,
    audioTrackFormat,
    audioTrackUid,
};

const DatabaseRecord = union(DatabaseRecordTag) {
    audioProgramme: AudioProgramme,
    audioContent: AudioContent,
    audioObject: AudioObject,
    audioPackFormat: AudioPackFormat,
    audioChannelFormat: AudioChannelFormat,
    audioStreamFormat: AudioStreamFormat,
    audioTrackFormat: AudioTrackFormat,
    audioTrackUid: AudioTrackUID,
};

const Database2 = struct {
    entities_map: StringHashMap(DatabaseRecord),
    allocator: Allocator,

    fn init(allocator: Allocator) @This() {
        return @This(){
            .entities_map = StringHashMap(DatabaseRecord).init(allocator),
            .allocator = allocator,
        };
    }

    fn deinit(self: @This()) void {
        self.entities_map.deinit();
    }
};

const Database = struct {
    audio_programme_map: StringHashMap(AudioProgramme),
    audio_content_map: StringHashMap(AudioContent),
    audio_object_map: StringHashMap(AudioObject),
    audio_pack_format_map: StringHashMap(AudioPackFormat),
    audio_channel_format_map: StringHashMap(AudioChannelFormat),
    audio_stream_format_map: StringHashMap(AudioStreamFormat),
    audio_track_format_map: StringHashMap(AudioTrackFormat),
    audio_track_uid_map: StringHashMap(AudioTrackUID),
    chna_record_map: StringHashMap(ChnaEntry),
    audio_channel_to_stream_format_map: StringHashMap([]const u8),
    stream_format_to_audio_track_map: StringHashMap([]const u8),
    audio_track_uid_to_format_map: StringHashMap([]const u8),
    audio_track_format_to_stream_map: StringHashMap([]const u8),
    audio_pack_to_object_map: StringHashMap([]const u8),
    audio_object_to_content_map: StringHashMap([]const u8),
    track_uid_list: [][]u8,
    allocator: Allocator,

    fn init(allocator: Allocator) @This() {
        return @This(){
            .audio_programme_map = StringHashMap(AudioProgramme).init(allocator),
            .audio_content_map = StringHashMap(AudioContent).init(allocator),
            .audio_object_map = StringHashMap(AudioObject).init(allocator),
            .audio_pack_format_map = StringHashMap(AudioPackFormat).init(allocator),
            .audio_channel_format_map = StringHashMap(AudioChannelFormat).init(allocator),
            .audio_stream_format_map = StringHashMap(AudioStreamFormat).init(allocator),
            .audio_track_format_map = StringHashMap(AudioTrackFormat).init(allocator),
            .audio_track_uid_map = StringHashMap(AudioTrackUID).init(allocator),
            .chna_record_map = StringHashMap(ChnaEntry).init(allocator),
            .audio_channel_to_stream_format_map = StringHashMap([]const u8).init(allocator),
            .stream_format_to_audio_track_map = StringHashMap([]const u8).init(allocator),
            .audio_track_uid_to_format_map = StringHashMap([]const u8).init(allocator),
            .audio_track_format_to_stream_map = StringHashMap([]const u8).init(allocator),
            .audio_pack_to_object_map = StringHashMap([]const u8).init(allocator),
            .audio_object_to_content_map = StringHashMap([]const u8).init(allocator),
            .track_uid_list = allocator.alloc([]u8, 0) catch {
                @panic("Alloc failed!");
            },
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
        for (content.audioObjectIDs) |object_id| {
            self.audio_object_to_content_map.put(object_id, content.audioContentID) catch {
                @panic("");
            };
        }
    }

    fn insertAudioObject(self: *@This(), object: AudioObject) void {
        self.audio_object_map.put(object.audioObjectID, object) catch {
            @panic("HashMap.put() failed!");
        };
        for (object.audioPackFormatIDs) |pack_id| {
            self.audio_pack_to_object_map.put(pack_id, object.audioObjectID) catch {
                @panic("");
            };
        }
    }

    fn insertAudioPackFormat(self: *@This(), pack_format: AudioPackFormat) void {
        self.audio_pack_format_map.put(pack_format.audioPackFormatID, pack_format) catch {
            @panic("HashMap.put() failed!");
        };
    }

    fn insertAudioChannelFormat(self: *@This(), channel_format: AudioChannelFormat) void {
        self.audio_channel_format_map.put(channel_format.audioChannelFormatID, channel_format) catch {
            @panic("HashMap.put() failed!");
        };
    }

    fn insertAudioStreamFormat(self: *@This(), stream_format: AudioStreamFormat) void {
        self.audio_stream_format_map.put(stream_format.audioStreamFormatID, stream_format) catch {
            @panic("HashMap.put() failed!");
        };

        if (stream_format.audioChannelFormatID) |chan_id| {
            self.audio_channel_to_stream_format_map.put(chan_id, stream_format.audioStreamFormatID) catch {
                @panic("HashMap.put() failed!");
            };
        }

        for (stream_format.audioTrackFormatIDs) |track_id| {
            self.stream_format_to_audio_track_map.put(stream_format.audioStreamFormatID, track_id) catch {
                @panic("HashMap.put() failed!");
            };
            self.audio_track_format_to_stream_map.put(track_id, stream_format.audioStreamFormatID) catch {
                @panic("HashMap.put() failed!");
            };
        }
    }

    fn insertAudioTrackFormat(self: *@This(), track_format: AudioTrackFormat) void {
        self.audio_track_format_map.put(track_format.audioTrackFormatID, track_format) catch {
            @panic("HashMap.put() failed!");
        };
    }

    fn insertAudioTrackUID(self: *@This(), audio_track_uid: AudioTrackUID) void {
        self.audio_track_uid_map.put(audio_track_uid.audioTrackUID, audio_track_uid) catch {
            @panic("HashMap.put() failed!");
        };
    }

    fn createTrackTable(self: *@This(), track_count: u16) void {
        self.allocator.free(self.track_uid_list);
        self.track_uid_list = self.allocator.alloc([]u8, track_count) catch {
            @panic("");
        };
    }

    fn insertChnaEntry(self: *@This(), chna_entry: ChnaEntry) void {
        self.chna_record_map.put(chna_entry.track_ref, chna_entry) catch {
            @panic("HashMap.put() failed!");
        };
        self.audio_track_uid_to_format_map.put(chna_entry.track_uid, chna_entry.track_ref) catch {
            @panic("HashMap.put() failed!");
        };
    }

    fn freeMap(comptime T: type, m: *StringHashMap(T)) void {
        var i = m.valueIterator();
        while (i.next()) |v| {
            v.deinit();
        }
        m.deinit();
    }

    fn deinit(self: *@This()) void {
        freeMap(AudioProgramme, &self.audio_programme_map);
        freeMap(AudioContent, &self.audio_content_map);
        freeMap(AudioObject, &self.audio_object_map);
        freeMap(AudioPackFormat, &self.audio_pack_format_map);
        freeMap(AudioChannelFormat, &self.audio_channel_format_map);
        freeMap(AudioStreamFormat, &self.audio_stream_format_map);
        freeMap(AudioTrackFormat, &self.audio_track_format_map);
        freeMap(AudioTrackUID, &self.audio_track_uid_map);
        freeMap(ChnaEntry, &self.chna_record_map);

        self.allocator.free(self.track_uid_list);

        self.audio_channel_to_stream_format_map.deinit();
        self.stream_format_to_audio_track_map.deinit();
        self.audio_track_uid_to_format_map.deinit();
        self.audio_track_format_to_stream_map.deinit();
        self.audio_pack_to_object_map.deinit();
        self.audio_object_to_content_map.deinit();
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
        const audioProgrammeID = XPathStringValue("string(//adm:audioFormatExtended/" ++
            "adm:audioProgramme[1]/@audioProgrammeID)", xpath_ctx, null, allocator);
        if (audioProgrammeID.len == 0) {
            @panic("audioProgramme not found!");
        }
        const audioProgrammeName = XPathStringValue("string(//*/adm:audioProgramme[1]/" ++
            "@audioProgrammeName)", xpath_ctx, null, allocator);
        const start = XPathStringValue("string(//*/adm:audioProgramme[1]/@start)", xpath_ctx, null, allocator);
        const end = XPathStringValue("string(//*/adm:audioProgramme[1]/@end)", xpath_ctx, null, allocator);

        var contentIds = ArrayList([]const u8).init(allocator);
        defer contentIds.deinit();

        var acoIter = XPathNodeSetValue("//adm:audioProgramme[1]/adm:audioContentIDRef", xpath_ctx, null);

        while (acoIter.next()) |node| {
            const this_id = XPathStringValue("string(./text())", xpath_ctx, node, allocator);
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
        freeStrList(self.audioContentIDs, self.allocator);
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

    fn addAll(xpath_ctx: xml.xmlXPathContextPtr, database: *Database) void {
        var content_iter = XPathNodeSetValue("//adm:audioFormatExtended/adm:audioContent", xpath_ctx, null);
        while (content_iter.next()) |node| {
            const id = XPathStringValue("string(./@audioContentID)", xpath_ctx, node, database.allocator);
            const name = XPathStringValue("string(./@audioContentName)", xpath_ctx, node, database.allocator);
            const obj_refs = extractRefs("./adm:audioObjectIDRef", xpath_ctx, node, database.allocator);

            database.insertAudioContent(@This(){
                .audioContentID = id,
                .audioContentName = name,
                .audioObjectIDs = obj_refs,
                .allocator = database.allocator,
            });
        }
    }

    fn deinit(self: @This()) void {
        freeStrList(self.audioObjectIDs, self.allocator);
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
    audioTrackUIDs: [][]const u8,
    // audioObjectIDs: [][]const u8,
    allocator: Allocator,

    fn addAll(xpath_ctx: xml.xmlXPathContextPtr, database: *Database) void {
        var object_iter = XPathNodeSetValue("//adm:audioFormatExtended/adm:audioObject", xpath_ctx, null);
        while (object_iter.next()) |node| {
            const id = XPathStringValue("string(./@audioObjectID)", xpath_ctx, node, database.allocator);
            const name = XPathStringValue("string(./@audioObjectName)", xpath_ctx, node, database.allocator);
            const start = XPathStringValue("string(./@start)", xpath_ctx, node, database.allocator);
            const duration = XPathStringValue("string(./@duration)", xpath_ctx, node, database.allocator);
            const pack_format_refs = extractRefs("./adm:audioPackFormatIDRef", xpath_ctx, node, database.allocator);
            const track_uid_refs = extractRefs("./adm:audioTrackUIDRef", xpath_ctx, node, database.allocator);

            database.insertAudioObject(@This(){
                .audioObjectID = id,
                .audioObjectName = name,
                .start = start,
                .duration = duration,
                .audioPackFormatIDs = pack_format_refs,
                .audioTrackUIDs = track_uid_refs,
                .allocator = database.allocator,
            });
        }
    }

    fn deinit(self: @This()) void {
        self.allocator.free(self.audioObjectID);
        self.allocator.free(self.audioObjectName);
        self.allocator.free(self.start);
        self.allocator.free(self.duration);
        freeStrList(self.audioPackFormatIDs, self.allocator);
        freeStrList(self.audioTrackUIDs, self.allocator);
    }
};

const AudioPackFormat = struct {
    audioPackFormatID: []const u8,
    audioPackFormatName: []const u8,
    typeLabel: []const u8,
    typeDefinition: []const u8,
    audioChannelFormatIDs: [][]const u8,
    // audioPackFormatIDs: [][]const u8,
    allocator: Allocator,

    fn addAll(xpath_ctx: xml.xmlXPathContextPtr, database: *Database) void {
        var object_iter = XPathNodeSetValue("//adm:audioFormatExtended/adm:audioPackFormat", xpath_ctx, null);
        while (object_iter.next()) |node| {
            const id = XPathStringValue("string(./@audioPackFormatID)", xpath_ctx, node, database.allocator);
            const name = XPathStringValue("string(./@audioPackFormatName)", xpath_ctx, node, database.allocator);
            const label = XPathStringValue("string(./@typeLabel)", xpath_ctx, node, database.allocator);
            const definition = XPathStringValue("string(./@typeDefinition)", xpath_ctx, node, database.allocator);
            const channel_refs = extractRefs("./adm:audioChannelFormatIDRef", xpath_ctx, node, database.allocator);

            database.insertAudioPackFormat(@This(){
                .audioPackFormatID = id,
                .audioPackFormatName = name,
                .typeLabel = label,
                .typeDefinition = definition,
                .audioChannelFormatIDs = channel_refs,
                .allocator = database.allocator,
            });
        }
    }

    fn deinit(self: @This()) void {
        self.allocator.free(self.audioPackFormatID);
        self.allocator.free(self.audioPackFormatName);
        self.allocator.free(self.typeLabel);
        self.allocator.free(self.typeDefinition);
        freeStrList(self.audioChannelFormatIDs, self.allocator);
    }
};

const AudioChannelFormat = struct {
    audioChannelFormatID: []const u8,
    audioChannelFormatName: []const u8,
    typeLabel: []const u8,
    typeDefinition: []const u8,
    allocator: Allocator,

    fn addAll(xpath_ctx: xml.xmlXPathContextPtr, database: *Database) void {
        var object_iter = XPathNodeSetValue("//adm:audioFormatExtended/adm:audioChannelFormat", xpath_ctx, null);
        while (object_iter.next()) |node| {
            const id = XPathStringValue("string(./@audioChannelFormatID)", xpath_ctx, node, database.allocator);
            const name = XPathStringValue("string(./@audioChannelFormatName)", xpath_ctx, node, database.allocator);
            const label = XPathStringValue("string(./@typeLabel)", xpath_ctx, node, database.allocator);
            const definition = XPathStringValue("string(./@typeDefinition)", xpath_ctx, node, database.allocator);

            database.insertAudioChannelFormat(@This(){
                .audioChannelFormatID = id,
                .audioChannelFormatName = name,
                .typeLabel = label,
                .typeDefinition = definition,
                .allocator = database.allocator,
            });
        }
    }

    fn deinit(self: @This()) void {
        self.allocator.free(self.audioChannelFormatID);
        self.allocator.free(self.audioChannelFormatName);
        self.allocator.free(self.typeLabel);
        self.allocator.free(self.typeDefinition);
    }
};

const AudioStreamFormat = struct {
    audioStreamFormatID: []const u8,
    //audioStreamFormatName: []const u8,
    audioChannelFormatID: ?[]const u8,
    audioTrackFormatIDs: [][]const u8,
    audioPackFormatID: ?[]const u8,
    allocator: Allocator,

    fn addAll(xpath_ctx: xml.xmlXPathContextPtr, database: *Database) void {
        var object_iter = XPathNodeSetValue("//adm:audioFormatExtended/adm:audioStreamFormat", xpath_ctx, null);

        while (object_iter.next()) |node| {
            const id = XPathStringValue("string(./@audioStreamFormatID)", xpath_ctx, node, database.allocator);

            var get_chan_fmt = XPathNodeSetValue("./adm:audioChannelFormatIDRef", xpath_ctx, node);
            var chan_fmt_id: ?[]const u8 = null;

            if (get_chan_fmt.next()) |chan_fmt_node| {
                chan_fmt_id = XPathStringValue("string(.)", xpath_ctx, chan_fmt_node, database.allocator);
            }

            var get_pack_fmt = XPathNodeSetValue("./adm:audioPackFormatIDRef", xpath_ctx, node);
            var pack_fmt_id: ?[]const u8 = null;

            if (get_pack_fmt.next()) |pack_fmt_node| {
                pack_fmt_id = XPathStringValue("string(.)", xpath_ctx, pack_fmt_node, database.allocator);
            }
            const track_format_uid_refs = extractRefs("./adm:audioTrackFormatIDRef", xpath_ctx, node, database.allocator);

            database.insertAudioStreamFormat(@This(){
                .audioStreamFormatID = id,
                .audioChannelFormatID = chan_fmt_id,
                .audioTrackFormatIDs = track_format_uid_refs,
                .audioPackFormatID = pack_fmt_id,
                .allocator = database.allocator,
            });
        }
    }

    fn deinit(self: @This()) void {
        self.allocator.free(self.audioStreamFormatID);
        if (self.audioChannelFormatID) |r| {
            self.allocator.free(r);
        }
        if (self.audioPackFormatID) |r| {
            self.allocator.free(r);
        }
        freeStrList(self.audioTrackFormatIDs, self.allocator);
    }
};

const AudioTrackFormat = struct {
    audioTrackFormatID: []const u8,
    audioStreamFormatID: []const u8,
    allocator: Allocator,

    fn addAll(xpath_ctx: xml.xmlXPathContextPtr, database: *Database) void {
        var object_iter = XPathNodeSetValue("//adm:audioFormatExtended/adm:audioTrackFormat", xpath_ctx, null);
        while (object_iter.next()) |node| {
            const id = XPathStringValue("string(./@audioTrackFormatID)", xpath_ctx, node, database.allocator);
            const stream = XPathStringValue("string(./adm:audioStreamFormatIDRef/text())", xpath_ctx, node, database.allocator);

            database.insertAudioTrackFormat(@This(){
                .audioTrackFormatID = id,
                .audioStreamFormatID = stream,
                .allocator = database.allocator,
            });
        }
    }

    fn deinit(self: @This()) void {
        self.allocator.free(self.audioTrackFormatID);
        self.allocator.free(self.audioStreamFormatID);
    }
};

const AudioTrackUID = struct {
    audioTrackUID: []const u8,
    audioTrackFormatID: ?[]const u8,
    sampleRate: f32,
    bitDepth: u8,
    allocator: Allocator,

    fn addAll(xpath_ctx: xml.xmlXPathContextPtr, database: *Database) void {
        var object_iter = XPathNodeSetValue("//adm:audioFormatExtended/adm:audioTrackUID", xpath_ctx, null);
        while (object_iter.next()) |node| {
            const id = XPathStringValue("string(./@UID)", xpath_ctx, node, database.allocator);
            const track = XPathStringValue("string(./adm:audioTrackFormatIDRef/text())", xpath_ctx, node, database.allocator);

            const bit_depth_s = XPathStringValue("string(./@bitDepth)", xpath_ctx, node, database.allocator);
            defer database.allocator.free(bit_depth_s);
            const sample_rate_s = XPathStringValue("string(./@sampleRate)", xpath_ctx, node, database.allocator);
            defer database.allocator.free(sample_rate_s);

            const sample_rate = std.fmt.parseFloat(f32, sample_rate_s) catch {
                @panic("AudioTrackUID sample rate cannot be parsed");
            };

            const bit_depth = std.fmt.parseInt(u8, bit_depth_s, 10) catch {
                @panic("AudioTrackUID bit depth cannot be parsed");
            };

            database.insertAudioTrackUID(@This(){
                .audioTrackUID = id,
                .audioTrackFormatID = track,
                .sampleRate = sample_rate,
                .bitDepth = bit_depth,
                .allocator = database.allocator,
            });
        }
    }

    fn deinit(self: @This()) void {
        self.allocator.free(self.audioTrackUID);
        if (self.audioTrackFormatID) |v| {
            self.allocator.free(v);
        }
    }
};

const ChnaEntry = struct {
    track_index: u16,
    track_uid: []const u8,
    track_ref: []const u8,
    pack_ref: []const u8,
    allocator: Allocator,

    fn addAll(chna_data: []const u8, database: *Database) void {
        const track_count = std.mem.readInt(u16, chna_data[0..2], std.builtin.Endian.little);
        database.createTrackTable(track_count);
        const entry_count = @divFloor(chna_data.len - 4, 40);
        for (0..entry_count) |entry_index| {
            const entry_offset = entry_index * 40 + 4;
            const struct_data = chna_data[entry_offset..(entry_offset + 40)];
            const track_index = std.mem.readInt(u16, struct_data[0..2], std.builtin.Endian.little);

            if (track_index == 0) {
                continue;
            } else {
                const track_uid: []u8 = database.allocator.alloc(u8, 12) catch {
                    @panic("Alloc failed");
                };
                std.mem.copyForwards(u8, track_uid, struct_data[2..14]);

                const track_ref: []u8 = database.allocator.alloc(u8, 14) catch {
                    @panic("Alloc failed");
                };
                std.mem.copyForwards(u8, track_ref, struct_data[14..28]);

                const pack_ref: []u8 = database.allocator.alloc(u8, 11) catch {
                    @panic("Alloc failed");
                };
                std.mem.copyForwards(u8, pack_ref, struct_data[28..39]);

                database.insertChnaEntry(@This(){
                    .track_index = track_index,
                    .track_uid = track_uid,
                    .track_ref = track_ref,
                    .pack_ref = pack_ref,
                    .allocator = database.allocator,
                });

                database.track_uid_list[track_index - 1] = track_uid;
            }
        }
    }

    fn deinit(self: @This()) void {
        self.allocator.free(self.track_uid);
        self.allocator.free(self.track_ref);
        self.allocator.free(self.pack_ref);
    }
};

pub fn compileADM(xml_data: []const u8, chna_data: []const u8, allocator: Allocator) Database {
    xml.xmlInitParser();
    defer xml.xmlCleanupParser();

    const doc: xml.xmlDocPtr = xml.xmlReadMemory(@ptrCast(xml_data), @intCast(xml_data.len), null, "utf-8", 0) orelse {
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

    database.insertAudioProgramme(AudioProgramme.init(allocator, xpath_ctx));
    AudioContent.addAll(xpath_ctx, &database);
    AudioObject.addAll(xpath_ctx, &database);
    AudioPackFormat.addAll(xpath_ctx, &database);
    AudioChannelFormat.addAll(xpath_ctx, &database);
    AudioStreamFormat.addAll(xpath_ctx, &database);
    AudioTrackFormat.addAll(xpath_ctx, &database);
    AudioTrackUID.addAll(xpath_ctx, &database);
    ChnaEntry.addAll(chna_data, &database);

    return database;
}

pub fn printProgrammeTree(adm_xml: []const u8, chna_data: []const u8, writer: AnyWriter, allocator: Allocator) !void {
    var database = compileADM(adm_xml, chna_data, allocator);
    defer database.deinit();

    var programme_iter = database.audio_programme_map.valueIterator();
    while (programme_iter.next()) |programme| {
        try writer.print("AudioProgramme ({s}) \"{s}\"\n", .{ programme.audioProgrammeID, programme.audioProgrammeName });
        for (programme.audioContentIDs) |ac_id| content_blk: {
            const audio_content = database.audio_content_map.get(ac_id) orelse {
                try writer.print(" ? *{s}\n", .{ac_id});
                break :content_blk;
            };
            try writer.print(" + AudioContent ({s}) \"{s}\"\n", .{ audio_content.audioContentID, audio_content.audioContentName });
            for (audio_content.audioObjectIDs) |ao_id| obj_blk: {
                const audio_object = database.audio_object_map.get(ao_id) orelse {
                    try writer.print("   ? *{s}\n", .{ao_id});
                    break :obj_blk;
                };
                try writer.print("   + AudioObject ({s}) \"{s}\" (AudioTrackUID count {})\n", .{ audio_object.audioObjectID, audio_object.audioObjectName, audio_object.audioTrackUIDs.len });
                for (audio_object.audioPackFormatIDs) |ap_id| {
                    const audio_pack = database.audio_pack_format_map.get(ap_id) orelse {
                        try writer.print("     ? *{s}\n", .{ap_id});
                        break;
                    };
                    try writer.print("     + AudioPackFormat ({s}) \"{s}\" (type: \"{s}\")\n", .{ audio_pack.audioPackFormatID, audio_pack.audioPackFormatName, audio_pack.typeDefinition });
                    for (audio_pack.audioChannelFormatIDs) |chn_id| chn_blk: {
                        const audio_channel = database.audio_channel_format_map.get(chn_id) orelse {
                            try writer.print("       ? *{s}\n", .{chn_id});
                            break :chn_blk;
                        };

                        try writer.print("       + AudioChannelFormat ({s}) \"{s}\"\n", .{ audio_channel.audioChannelFormatID, audio_channel.audioChannelFormatName });

                        if (database.audio_channel_to_stream_format_map.get(chn_id)) |stream_id| {
                            try writer.print("         -> AudioStreamFormat ({s})\n", .{stream_id});
                            if (database.stream_format_to_audio_track_map.get(stream_id)) |track_id| {
                                if (database.audio_track_format_map.get(track_id)) |track_format| {
                                    try writer.print("         -> AudioTrackFormat ({s})\n", .{track_format.audioTrackFormatID});
                                    if (database.chna_record_map.get(track_format.audioTrackFormatID)) |chna| {
                                        try writer.print("         => AudioTrackUID ({s}) [index {}]\n", .{ chna.track_uid, chna.track_index });
                                    } else {}
                                } else {
                                    try writer.print("         ? *{s}\n", .{track_id});
                                }
                            } else {
                                try writer.print("         !! No AudioTrackFormat\n", .{});
                            }
                        } else {
                            try writer.print("         !! No AudioStreamFormat\n", .{});
                        }
                    }
                }
            }
        }
    }
}

pub fn printTrackList(adm_xml: []const u8, chna_data: []const u8, writer: AnyWriter, allocator: Allocator) !void {
    var database = compileADM(adm_xml, chna_data, allocator);
    defer database.deinit();

    for (1.., database.track_uid_list) |track_index, track_uid| {
        var content_name: ?[]const u8 = null;
        var object_name: ?[]const u8 = null;
        var pack_type: ?[]const u8 = null;
        var channel_format_name: ?[]const u8 = null;

        if (database.audio_track_uid_to_format_map.get(track_uid)) |track_format_id| {
            if (database.audio_track_format_to_stream_map.get(track_format_id)) |stream_format_id| {
                if (database.audio_stream_format_map.get(stream_format_id)) |stream_format| {
                    if (stream_format.audioChannelFormatID) |chan_id| {
                        if (database.audio_channel_format_map.get(chan_id)) |channel_format| {
                            channel_format_name = channel_format.audioChannelFormatName;
                        }
                    }
                    if (stream_format.audioPackFormatID) |pack_id| {
                        if (database.audio_pack_format_map.get(pack_id)) |pack_format| {
                            pack_type = pack_format.typeDefinition;
                        }
                        if (database.audio_pack_to_object_map.get(pack_id)) |object_id| {
                            if (database.audio_object_map.get(object_id)) |object| {
                                object_name = object.audioObjectName;
                            }
                            if (database.audio_object_to_content_map.get(object_id)) |content_id| {
                                if (database.audio_content_map.get(content_id)) |content| {
                                    content_name = content.audioContentName;
                                }
                            }
                        }
                    }
                }
            }
        }

        try writer.print("Trk {} {s} ", .{
            track_index,
            track_uid,
        });

        if (content_name) |val| {
            try writer.print("\"{s}\" ", .{val});
        } else {
            try writer.print("? ", .{});
        }

        if (object_name) |val| {
            try writer.print("\"{s}\" ", .{val});
        } else {
            try writer.print("? ", .{});
        }

        if (pack_type) |val| {
            try writer.print("\"{s}\" ", .{val});
        } else {
            try writer.print("? ", .{});
        }

        if (channel_format_name) |val| {
            try writer.print("\"{s}\" ", .{val});
        } else {
            try writer.print("? ", .{});
        }

        try writer.print("\n", .{});
    }
}
