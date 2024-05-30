const std = @import("std");
const xml = @cImport({
    @cInclude("libxml2/libxml/parser.h");
    @cInclude("libxml2/libxml/tree.h");
});

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
