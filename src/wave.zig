/// Basic WAVE file reading/writing operations
///
const std = @import("std");
const File = std.fs.File;
const cwd = std.fs.cwd;
const eql = std.mem.eql;

const WaveErrors = error{NotWaveFile};

const RF64BigTableEntry = struct {
    ident: [4]u8,
    size: u64,
};

const RF64ChunkListIter = struct {
    file: File,
    size: i64,
    rf64_bigtable: []RF64BigTableEntry,

    pub fn init(path: []const u8) !@This() {
        const file = try cwd().openFile(path, .{});
        errdefer file.close();

        var this_signature: [4]u8 = undefined;
        var this_size: i64 = undefined;

        try file.seekTo(0);
        _ = try file.read(&this_signature);
        if (eql(u8, &this_signature, "RIFF")) {
            this_size = try file.reader().readInt(u32, .little);
            try file.seekBy(4);
            return @This(){
                .file = file,
                .size = @intCast(this_size),
                .rf64_bigtable = &.{},
            };
        } else if (eql(u8, &this_signature, "RF64")) {
            @panic("Continue RF64");
        } else {
            return error.NotWaveFile;
        }
    }

    pub fn next(self: @This()) !?struct { [4]u8, u64, u32 } {
        if (try self.file.getPos() >= self.size + 8) {
            return null;
        } else {
            var fourcc: [4]u8 = undefined;
            var start: u64 = undefined;
            var size: u32 = undefined;
            _ = try self.file.read(&fourcc);
            size = try self.file.reader().readInt(u32, .little);
            start = try self.file.getPos();
            const size64: i64 = @intCast(size);
            try self.file.seekBy(size64 + size % 2);
            return .{ fourcc, start, size };
        }
    }

    pub fn close(self: @This()) void {
        self.file.close();
    }
};

test "test open WAVE" {
    const iter = try RF64ChunkListIter.init("tone.wav");
    defer iter.close();
    try std.testing.expectEqual(iter.size, 88270);
}

test "iterate chunks simple WAVE" {
    const iter = try RF64ChunkListIter.init("tone.wav");
    defer iter.close();
    var counter: u32 = 0;
    while (try iter.next()) |chunk| {
        // std.debug.print("A Chunk {s}, size: {}, at: {}\n", chunk);
        switch (counter) {
            0 => {
                try std.testing.expect(eql(u8, &chunk[0], "fmt "));
                try std.testing.expectEqual(chunk[1], 20);
                try std.testing.expectEqual(chunk[2], 16);
            },
            1 => {
                try std.testing.expect(eql(u8, &chunk[0], "LIST"));
                try std.testing.expectEqual(chunk[1], 44);
                try std.testing.expectEqual(chunk[2], 26);
            },
            2 => {
                try std.testing.expect(eql(u8, &chunk[0], "data"));
                try std.testing.expectEqual(chunk[1], 78);
                try std.testing.expectEqual(chunk[2], 88200);
            },
            else => {
                try std.testing.expect(false);
            },
        }
        counter += 1;
    }
}
