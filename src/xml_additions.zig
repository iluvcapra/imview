const std = @import("std");
const xml = @cImport({
    @cInclude("libxml2/libxml/parser.h");
    @cInclude("libxml2/libxml/tree.h");
    @cInclude("libxml2/libxml/xpath.h");
    @cInclude("libxml2/libxml/xpathInternals.h");
    @cInclude("libxml2/libxml/xmlmemory.h");
});
const Allocator = std.mem.Allocator;
// const ADMError = error{ XmlParseError, AdmXmlEntityError };

pub const XPathNodeIter = struct {
    result: xml.xmlXPathObjectPtr,
    i: usize,

    pub fn init(result: xml.xmlXPathObjectPtr) @This() {
        if (result.*.type != xml.XPATH_NODESET) {
            @panic("XPathNodeIter init expression did not evaluate to a node set!");
        }

        return @This(){
            .result = result,
            .i = 0,
        };
    }

    pub fn empty(self: @This()) bool {
        return (self.*.nodesetval.*.nodeNr == 0);
    }

    pub fn next(self: *@This()) ?xml.xmlNodePtr {
        if (self.i >= self.result.*.nodesetval.*.nodeNr) {
            return null;
        } else {
            defer self.i += 1;
            return self.result.*.nodesetval.*.nodeTab[self.i];
        }
    }

    pub fn deinit(self: @This()) void {
        xml.xmlXPathFreeObject(self.result);
    }
};

/// Evaluates query against the given xpath_ctx and returns an XpathObjectPtr.
/// If node_ctx is given, this node is set as the context node for the request,
/// and then the original context node is restored at the end of the function.
/// Panics if xmlXPathEvalExpression retunrs a null.
/// The returned value must be freed by the caller with xmlXPathFreeObject()
fn XPathEvalWithContextNode(expression: []const u8, xpath_ctx: xml.xmlXPathContextPtr, node_ctx: ?xml.xmlNodePtr) xml.xmlXPathObjectPtr {
    var orig_node: ?xml.xmlNodePtr = null;
    if (node_ctx) |node| {
        orig_node = xpath_ctx.*.node;
        if (xml.xmlXPathSetContextNode(node, xpath_ctx) != 0) {
            @panic("Failed to set context node!");
        }
    }

    if (xml.xmlXPathEvalExpression(@ptrCast(expression), xpath_ctx)) |result| {
        return result;
    } else {
        @panic("xmlXPathEvalExpression returned null!");
    }

    if (orig_node) |node| {
        if (xml.xmlXPathSetContextNode(node, xpath_ctx) != 0) {
            @panic("Failed to restore original contex node!");
        }
    }
}

/// Runs an XPath query against the xpath_ctx and returns a []u8.
/// The return value must be freed by the caller.
/// If the query does not result in a string return value, this function will
/// panic.
pub fn XPathStringValue(xpath: []const u8, xpath_ctx: xml.xmlXPathContextPtr, node: ?xml.xmlNodePtr, allocator: Allocator) []const u8 {
    const result = XPathEvalWithContextNode(xpath, xpath_ctx, node);
    defer xml.xmlXPathFreeObject(result);

    switch (result.*.type) {
        xml.XPATH_STRING => {
            const str_spanned = std.mem.span(result.*.stringval);
            const retval = allocator.alloc(u8, str_spanned.len) catch {
                @panic("Failed to allocate memory for XPath string value!");
            };
            std.mem.copyForwards(u8, retval, str_spanned);

            return retval;
        },
        else => {
            @panic("XPath parameter to XPathStringValue() does not have string result!");
        },
    }
}

/// Runs an XPath query against the xpath_ctx and returns a []u8.
/// The return value must be freed by the caller.
/// If the query does not result in a string return value, this function will
/// panic.
/// The result has to be deinit'ed by the caller.
pub fn XPathNodeSetValue(xpath: []const u8, xpath_ctx: xml.xmlXPathContextPtr, node: ?xml.xmlNodePtr) XPathNodeIter {
    const result = XPathEvalWithContextNode(xpath, xpath_ctx, node);

    switch (result.*.type) {
        xml.XPATH_NODESET => {
            return XPathNodeIter.init(result);
        },
        else => {
            @panic("XPath parameter to XPathNodeSetValue() does not have nodeset result!");
        },
    }
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
