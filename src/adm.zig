const std = @import("std");
const AnyWriter = std.io.AnyWriter;
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;

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

const AdmAudioProgramme = struct {
    audioProgrammeID: []const u8,
    audioProgrammeName: []const u8,
    start: []const u8,
    end: []const u8,
    audioContentIDs: []AdmAudioContent,
    allocator: Allocator,

    fn init(allocator: Allocator, xpath_ctx: xml.xmlXPathContextPtr) @This() {
        const audioProgrammeID = xpath_string_value("string(//adm:audioFormatExtended/adm:audioProgramme[1]/@audioProgrammeID)", xpath_ctx, null, allocator);
        if (audioProgrammeID.len == 0) {
            @panic("audioProgramme not found!");
        }
        const audioProgrammeName = xpath_string_value("string(//*/adm:audioProgramme[1]/@audioProgrammeName)", xpath_ctx, null, allocator);
        const start = xpath_string_value("string(//*/adm:audioProgramme[1]/@start)", xpath_ctx, null, allocator);
        const end = xpath_string_value("string(//*/adm:audioProgramme[1]/@end)", xpath_ctx, null, allocator);

        var contentIds = ArrayList(AdmAudioContent).init(allocator);
        defer contentIds.deinit();

        var acoIter = xpath_nodeset_value("//adm:audioProgramme[1]/adm:audioContentIDRef", xpath_ctx, null);

        while (acoIter.next()) |node| {
            const this_id = xpath_string_value("string(./text())", xpath_ctx, node, allocator);
            const audio_content = AdmAudioContent.init(allocator, xpath_ctx, this_id);
            contentIds.append(audio_content) catch {
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

    fn print(self: @This(), writer: AnyWriter) !void {
        try writer.print("Audio Programme ID : {s}\n", .{self.audioProgrammeID});
        try writer.print(" - Programme Name  : {s}\n", .{self.audioProgrammeName});
        try writer.print(" - Start           : {s}\n", .{self.start});
        try writer.print(" - End             : {s}\n", .{self.end});

        try writer.print(" - ContentIDs      : ", .{});
        for (self.audioContentIDs) |element| {
            try writer.print("{s} (\"{s}\"), ", .{ element.audioContentID, element.audioContentName });
        }
        try writer.print("\n", .{});
    }

    fn deinit(self: *@This()) void {
        for (self.audioContentIDs) |id| {
            id.deinit();
        }
        self.allocator.free(self.audioContentIDs);
        self.allocator.free(self.audioProgrammeID);
        self.allocator.free(self.audioProgrammeName);
        self.allocator.free(self.start);
        self.allocator.free(self.end);
    }
};

const AdmAudioContent = struct {
    audioContentID: []const u8,
    audioContentName: []const u8,
    allocator: Allocator,

    fn init(allocator: Allocator, xpath_ctx: xml.xmlXPathContextPtr, id: []const u8) @This() {
        const expr = std.fmt.allocPrintZ(allocator, "//adm:audioFormatExtended/adm:audioContent[@audioContentID = \"{s}\"]", .{id}) catch {
            @panic("Out of memory!");
        };
        defer allocator.free(expr);

        const name_expr = std.fmt.allocPrintZ(allocator, "string({s}/@audioContentName)", .{expr}) catch {
            @panic("Out of memory!");
        };
        defer allocator.free(name_expr);

        const name = xpath_string_value(name_expr, xpath_ctx, null, allocator);

        return @This(){
            .audioContentID = id,
            .audioContentName = name,
            .allocator = allocator,
        };
    }

    fn print(self: @This(), writer: AnyWriter) !void {
        try writer.print("Audio Content ID : {s}\n", .{self.audioContentID});
    }

    fn deinit(self: @This()) void {
        self.allocator.free(self.audioContentID);
        self.allocator.free(self.audioContentName);
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

    var programme = AdmAudioProgramme.init(allocator, xpath_ctx);
    defer programme.deinit();

    try programme.print(writer);
}

test "parse XML from data buffer" {
    const buffer: [*:0]const u8 = "<x>a</x>";
    const doc: xml.xmlDocPtr = xml.xmlReadMemory(buffer, 8, null, "utf-8", 0);
    defer xml.xmlCleanupParser();
    defer xml.xmlFreeDoc(doc);

    const root: ?xml.xmlNodePtr = xml.xmlDocGetRootElement(doc);

    try std.testing.expect(root != null);
    if (root) |r| {
        try std.testing.expect(std.mem.eql(u8, std.mem.span(r.*.name), "x"));
    }
}
