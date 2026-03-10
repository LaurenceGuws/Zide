const std = @import("std");

pub fn SyntaxTokens(comptime HighlightToken: type) type {
    return struct {
        const HighlightEvent = struct {
            pos: usize,
            is_start: bool,
            token_index: usize,
        };

        pub fn splitHighlightOverlaps(
            allocator: std.mem.Allocator,
            tokens: []HighlightToken,
        ) ![]HighlightToken {
            if (tokens.len <= 1) return tokens;

            var events = try allocator.alloc(HighlightEvent, tokens.len * 2);
            defer allocator.free(events);

            var event_count: usize = 0;
            for (tokens, 0..) |token, i| {
                if (token.end <= token.start) continue;
                events[event_count] = .{ .pos = token.start, .is_start = true, .token_index = i };
                event_count += 1;
                events[event_count] = .{ .pos = token.end, .is_start = false, .token_index = i };
                event_count += 1;
            }

            if (event_count == 0) return tokens;
            const events_slice = events[0..event_count];

            std.sort.heap(HighlightEvent, events_slice, {}, struct {
                fn lessThan(_: void, a: HighlightEvent, b: HighlightEvent) bool {
                    if (a.pos != b.pos) return a.pos < b.pos;
                    if (a.is_start != b.is_start) return b.is_start;
                    return a.token_index < b.token_index;
                }
            }.lessThan);

            var active = std.ArrayList(usize).empty;
            defer active.deinit(allocator);

            var output = std.ArrayList(HighlightToken).empty;
            errdefer output.deinit(allocator);

            var cursor_pos = events_slice[0].pos;
            var idx: usize = 0;
            while (idx < events_slice.len) {
                const pos = events_slice[idx].pos;
                if (pos > cursor_pos) {
                    if (pickBestToken(tokens, active.items)) |best_index| {
                        const best = tokens[best_index];
                        try appendHighlightSegment(&output, allocator, .{
                            .start = cursor_pos,
                            .end = pos,
                            .kind = best.kind,
                            .priority = best.priority,
                            .conceal = best.conceal,
                            .url = best.url,
                            .conceal_lines = best.conceal_lines,
                        });
                    }
                    cursor_pos = pos;
                }

                while (idx < events_slice.len and events_slice[idx].pos == pos and !events_slice[idx].is_start) : (idx += 1) {
                    removeActiveToken(&active, events_slice[idx].token_index);
                }
                while (idx < events_slice.len and events_slice[idx].pos == pos and events_slice[idx].is_start) : (idx += 1) {
                    try active.append(allocator, events_slice[idx].token_index);
                }
            }

            allocator.free(tokens);
            return output.toOwnedSlice(allocator);
        }

        fn removeActiveToken(active: *std.ArrayList(usize), token_index: usize) void {
            var i: usize = 0;
            while (i < active.items.len) : (i += 1) {
                if (active.items[i] == token_index) {
                    _ = active.swapRemove(i);
                    return;
                }
            }
        }

        fn pickBestToken(tokens: []HighlightToken, active: []const usize) ?usize {
            if (active.len == 0) return null;
            var best_index = active[0];
            for (active[1..]) |idx| {
                const candidate = tokens[idx];
                const best = tokens[best_index];
                if (candidate.priority > best.priority) {
                    best_index = idx;
                } else if (candidate.priority == best.priority and idx > best_index) {
                    best_index = idx;
                }
            }
            return best_index;
        }

        fn appendHighlightSegment(
            output: *std.ArrayList(HighlightToken),
            allocator: std.mem.Allocator,
            segment: HighlightToken,
        ) !void {
            if (segment.end <= segment.start) return;
            if (output.items.len > 0) {
                const last_index = output.items.len - 1;
                const last = output.items[last_index];
                if (last.end == segment.start and last.kind == segment.kind and last.priority == segment.priority and
                    stringOptEqual(last.conceal, segment.conceal) and stringOptEqual(last.url, segment.url) and
                    last.conceal_lines == segment.conceal_lines)
                {
                    output.items[last_index].end = segment.end;
                    return;
                }
            }
            try output.append(allocator, segment);
        }

        fn stringOptEqual(a: ?[]const u8, b: ?[]const u8) bool {
            if (a == null) return b == null;
            if (b == null) return false;
            return std.mem.eql(u8, a.?, b.?);
        }
    };
}
