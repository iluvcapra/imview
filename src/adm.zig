const std = @import("std");
const xml = @cImport({
    @cInclude("libxml2/libxml/parser.h");
    @cInclude("libxml2/libxml/tree.h");
});

test "open xml document" {
    const buffer: [*:0]const u8 = "<x>a</x>";
    const doc: xml.xmlDocPtr = xml.xmlReadMemory(buffer, 8, null, "utf-8", 0);
    const root: ?xml.xmlNodePtr = xml.xmlDocGetRootElement(doc);
    std.debug.print("{any}", .{root});
    try std.testing.expect(root != null);
}
