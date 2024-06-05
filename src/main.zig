const std = @import("std");
const process = std.process;
const eql = std.mem.eql;

pub const adm = @import("adm.zig");
pub const wave = @import("wave.zig");

const Mode = enum {
    print_programme,
    print_tracks,

    fn fromArg(arg: []const u8) ?@This() {
        if (std.mem.startsWith(u8, arg, "pro")) {
            return @This().print_programme;
        } else if (std.mem.startsWith(u8, arg, "tr")) {
            return @This().print_tracks;
        } else {
            return null;
        }
    }
};

fn processArg(mode: Mode, file: []const u8, allocator: std.mem.Allocator) !void {
    switch (mode) {
        Mode.print_programme => {
            if (try wave.read_chunk(file, "axml", allocator)) |adm_xml| {
                defer allocator.free(adm_xml);
                try adm.print_adm_xml_summary(adm_xml, std.io.getStdOut().writer().any());
            } else {
                std.debug.print("File {s} not an ADM file. Skipping.\n", .{file});
            }
        },
        Mode.print_tracks => {
            std.debug.print("`tracks` mode not implemented.\n", .{});
        },
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var args_iter = try process.argsWithAllocator(allocator);
    defer args_iter.deinit();

    var mode: Mode = undefined;
    for (0..128) |arg_index| {
        const arg = args_iter.next() orelse {
            break;
        };
        switch (arg_index) {
            0 => {},
            1 => {
                if (Mode.fromArg(arg)) |m| {
                    mode = m;
                } else {
                    std.debug.print("Unrecognized mode \"{s}\", panicking.\n", .{arg});
                    @panic("Invalid mode error!");
                }
            },
            else => {
                try processArg(mode, arg, allocator);
            },
        }
    }
}

test {
    std.testing.refAllDecls(@This());
}
