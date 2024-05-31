const std = @import("std");
const AnyWriter = std.io.AnyWriter;
const wave = @import("wave.zig");
const xml = @cImport({
    @cInclude("libxml2/libxml/parser.h");
    @cInclude("libxml2/libxml/tree.h");
    @cInclude("libxml2/libxml/xpath.h");
    @cInclude("libxml2/libxml/xpathInternals.h");
    @cInclude("libxml2/libxml/xmlmemory.h");
});

const ADMErrors = error{ XmlParseError, AdmXmlEntityError };

fn print_audio_programme_data(doc: xml.xmlDocPtr, xpath_ctx: xml.xmlXPathContextPtr, writer: AnyWriter) !void {
    if (xml.xmlXPathEvalExpression("//adm:audioProgramme[1]", xpath_ctx)) |result| {
        defer xml.xmlXPathFreeObject(result);
        if (result.*.nodesetval.*.nodeNr != 1) {
            return error.AdmXmlEntityError;
        } else {
            const audio_programme_node = result.*.nodesetval.*.nodeTab[0];
            try writer.print("Audio Programme:\n", .{});

            var this_attr = audio_programme_node.*.properties;
            while (this_attr != null) : (this_attr = this_attr.*.next) {
                const value = xml.xmlNodeListGetString(doc, this_attr.*.children, 1);
                defer xml.xmlFree.?(value);
                try writer.print(" -- {s} = {s}\n", .{ this_attr.*.name, value });
            }
        }
    }
}

pub fn print_adm_xml_summary(adm_xml: []const u8, writer: AnyWriter) !void {
    xml.xmlInitParser();
    defer xml.xmlCleanupParser();

    const doc: xml.xmlDocPtr = xml.xmlReadMemory(@ptrCast(adm_xml), @intCast(adm_xml.len), null, "utf-8", 0) orelse {
        return error.XmlParseError;
    };
    defer xml.xmlFreeDoc(doc);

    const xpath_ctx: xml.xmlXPathContextPtr = xml.xmlXPathNewContext(doc) orelse {
        @panic("xmlXPathNewContext Failed!");
    };
    defer xml.xmlXPathFreeContext(xpath_ctx);

    if (xml.xmlXPathRegisterNs(xpath_ctx, "adm", "urn:ebu:metadata-schema:ebuCore_2016") != 0) {
        @panic("xmlXPathRegisterNs Failed!");
    }

    try print_audio_programme_data(doc, xpath_ctx, writer);
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

// test "XML error from data buffer" {
//     const buffer: [*:0]const u8 = "<xa</x>";
//     const doc: ?xml.xmlDocPtr = xml.xmlReadMemory(buffer, 8, null, "utf-8", 0);
//     defer xml.xmlCleanupParser();
//     defer xml.xmlFreeDoc(doc);
// }
