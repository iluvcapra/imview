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
            };
        } else if (eql(u8, &this_signature, "RF64")) {
            _ = try file.reader().readInt(u32, .little);
            try file.seekBy(12); // "WAVEd s64xx xx"
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

            return @This(){
                .file = file,
                .size = rf64_size,
                .allocator = allocator,
                .rf64_bigtable = bigtable,
            };
        } else {
            return error.NotWaveFile;
        }
    }

    pub fn next(self: @This()) !?struct { [4]u8, u64, u32 } {
        if (try self.file.getPos() >= self.size + 8) {
            return null;
        } else {
            var fourcc: [4]u8 = undefined;
            _ = try self.file.read(&fourcc);
            const size: u32 = try self.file.reader().readInt(u32, .little);
            const start: u64 = try self.file.getPos();
            const size64: i64 = @intCast(size);
            try self.file.seekBy(size64 + size % 2);
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
    const iter = try RF64ChunkListIter.init("tone.wav", gpa.allocator());
    defer iter.close();
    try std.testing.expectEqual(iter.size, 88270);
}

test "iterate chunks simple WAVE" {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const iter = try RF64ChunkListIter.init("tone.wav", gpa.allocator());
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
