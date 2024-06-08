const std = @import("std");
const process = std.process;
const eql = std.mem.eql;

pub const adm = @import("adm.zig");
pub const wave = @import("wave.zig");

const Mode = enum {
    print_programme,
    print_tracks,

    fn fromArg(arg: []const u8) ?@This() {
        if (std.mem.startsWith(u8, arg, "program")) {
            return @This().print_programme;
        } else if (std.mem.startsWith(u8, arg, "track")) {
            return @This().print_tracks;
        } else {
            return null;
        }
    }
};

fn usage() void {
    std.debug.print(
        \\imview program [file ...]
        \\
    , .{});
}

fn processPositionalArg(mode: Mode, file: []const u8, allocator: std.mem.Allocator) !void {
    const adm_xml = try wave.read_chunk(file, "axml", allocator) orelse {
        std.debug.print("{s} is not an ADM WAVE file, skipping.", .{file});
        return;
    };
    defer allocator.free(adm_xml);
    const chna_data = try wave.read_chunk(file, "chna", allocator) orelse {
        std.debug.print("{s} is not an ADM WAVE file, skipping.", .{file});
        return;
    };
    defer allocator.free(chna_data);

    const writer = std.io.getStdOut().writer().any();
    switch (mode) {
        Mode.print_programme => {
            try adm.printProgrammeTree(adm_xml, chna_data, writer, allocator);
        },
        Mode.print_tracks => {
            try adm.printTrackList(adm_xml, chna_data, writer, allocator);
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
                    std.debug.print("Unrecognized mode \"{s}\". Aborting.\n", .{arg});
                    usage();
                    std.process.abort();
                }
            },
            else => {
                try processPositionalArg(mode, arg, allocator);
            },
        }
    }
}

test {
    std.testing.refAllDecls(@This());
}
