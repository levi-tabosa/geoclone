const std = @import("std");
// const tvt = @import("tvt");

extern fn printSlice(n: [*c]const u8, len: usize) void;

fn print(str: []const u8) void {
    printSlice(str.ptr, str.len);
}

pub fn main() void {
    print("hello world!");
}
