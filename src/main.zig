const std = @import("std");
pub const adm = @import("adm.zig");
pub const wave = @import("wave.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var allocator = gpa.allocator();
    if (try wave.read_chunk("test_audio/adm.wav", "axml", allocator)) |adm_xml| {
        defer allocator.free(adm_xml);
        try adm.print_adm_xml_summary(adm_xml, std.io.getStdOut().writer().any());
    }
}

test {
    std.testing.refAllDecls(@This());
}
