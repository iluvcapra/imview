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
    allocator: std.mem.Allocator,
    rf64_bigtable: ?[]RF64BigTableEntry,
    nextpos: u64,

    pub fn init(path: []const u8, allocator: std.mem.Allocator) !@This() {
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
                .allocator = allocator,
                .rf64_bigtable = null,
                .nextpos = @intCast(try file.getPos()),
            };
        } else if (eql(u8, &this_signature, "RF64")) {
            _ = try file.reader().readInt(u32, .little);
            try file.seekBy(8); // "WAVEd s64xx xx"
            const ds64_size = try file.reader().readInt(u32, .little);
            const ds64_start = try file.getPos();
            const rf64_size = try file.reader().readInt(i64, .little);
            const data_size = try file.reader().readInt(u64, .little);
            try file.seekBy(8); // sample count
            const table_size = try file.reader().readInt(u8, .little);
            var bigtable = try allocator.alloc(RF64BigTableEntry, table_size + 1);
            bigtable[0] = RF64BigTableEntry{
                .ident = "data".*,
                .size = data_size,
            };

            for (0..table_size) |n| {
                var this_ident: [4]u8 = undefined;
                _ = try file.read(&this_ident);
                bigtable[n + 1] = RF64BigTableEntry{
                    .ident = this_ident,
                    .size = try file.reader().readInt(u64, .little),
                };
            }

            try file.seekTo(ds64_start + ds64_size);

            return @This(){
                .file = file,
                .size = rf64_size,
                .allocator = allocator,
                .rf64_bigtable = bigtable,
                .nextpos = @intCast(try file.getPos()),
            };
        } else {
            return error.NotWaveFile;
        }
    }

    /// Get the fourCC, payload start offset and payload length of the next
    /// chunk.
    pub fn next(self: *@This()) !?struct { [4]u8, u64, u64 } {
        try self.file.seekTo(self.nextpos);

        if (try self.file.getPos() >= self.size + 8) {
            return null;
        } else {
            var fourcc: [4]u8 = undefined;
            _ = try self.file.read(&fourcc);

            var size: u64 = @intCast(try self.file.reader().readInt(u32, .little));

            if (size == 0xFFFFFFFF) {
                if (self.rf64_bigtable) |bt| {
                    for (bt) |entry| {
                        if (std.mem.eql(u8, &entry.ident, &fourcc)) {
                            size = entry.size;
                            break;
                        }
                    }
                } else {
                    @panic("Invalid chunk size 0xFFFFFFFF in normal WAVE file");
                }
            }

            if (size == 0xFFFFFFFF) {
                @panic("Malformed RF64 WAVE file, missing ds64 entry");
            }

            const start: u64 = try self.file.getPos();
            const size_i64: i64 = @truncate(@as(i128, size));
            try self.file.seekBy(size_i64 + @mod(size_i64, 2));

            self.*.nextpos = start + size;
            return .{ fourcc, start, size };
        }
    }

    pub fn close(self: @This()) void {
        if (self.rf64_bigtable) |b| {
            _ = self.allocator.free(b);
        }
        self.file.close();
    }
};

test "test open WAVE" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var iter = try RF64ChunkListIter.init("test_audio/tone.wav", gpa.allocator());
    defer iter.close();

    try std.testing.expectEqual(iter.size, 88270);
}

test "iterate chunks simple WAVE" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var iter = try RF64ChunkListIter.init("test_audio/tone.wav", gpa.allocator());
    defer iter.close();

    var counter: u32 = 0;
    while (try iter.next()) |chunk| {
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

test "move around between iterations" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var iter = try RF64ChunkListIter.init("test_audio/tone.wav", gpa.allocator());
    defer iter.close();

    if (try iter.next()) |chunk1| {
        try iter.file.seekTo(chunk1[1]);
        _ = try iter.file.reader().readInt(u16, .little);
        _ = try iter.file.reader().readInt(u16, .little);
        const sample_rate = try iter.file.reader().readInt(u32, .little);
        try std.testing.expectEqual(sample_rate, 44100);
    }

    if (try iter.next()) |chunk2| {
        try std.testing.expect(eql(u8, &chunk2[0], "LIST"));
    }
}

test "move around between iterations RF64" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var iter = try RF64ChunkListIter.init("test_audio/tone64.wav", gpa.allocator());
    defer iter.close();

    if (try iter.next()) |chunk1| {
        try iter.file.seekTo(chunk1[1]);
        _ = try iter.file.reader().readInt(u16, .little);
        _ = try iter.file.reader().readInt(u16, .little);
        const sample_rate = try iter.file.reader().readInt(u32, .little);
        try std.testing.expectEqual(sample_rate, 44100);
    }

    if (try iter.next()) |chunk2| {
        try std.testing.expect(eql(u8, &chunk2[0], "LIST"));
    }
}

test "iterate chunks RF64 WAVE" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var iter = try RF64ChunkListIter.init("test_audio/tone64.wav", gpa.allocator());
    defer iter.close();

    var counter: u32 = 0;
    while (try iter.next()) |chunk| {
        switch (counter) {
            0 => {
                try std.testing.expect(eql(u8, &chunk[0], "fmt "));
                try std.testing.expectEqual(chunk[1], 56);
                try std.testing.expectEqual(chunk[2], 16);
            },
            1 => {
                try std.testing.expect(eql(u8, &chunk[0], "LIST"));
                try std.testing.expectEqual(chunk[1], 80);
                try std.testing.expectEqual(chunk[2], 26);
            },
            2 => {
                try std.testing.expect(eql(u8, &chunk[0], "data"));
                try std.testing.expectEqual(chunk[1], 114);
                try std.testing.expectEqual(chunk[2], 90112);
            },
            else => {
                try std.testing.expect(false);
            },
        }
        counter += 1;
    }
}
