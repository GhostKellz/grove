const std = @import("std");

const Person = struct {
    name: []const u8,
    age: u8,
};

pub fn main() void {
    const people = [_]Person{
        .{ .name = "Eleanor", .age = 32 },
        .{ .name = "Chidi", .age = 31 },
        .{ .name = "Tahani", .age = 30 },
        .{ .name = "Jason", .age = 27 },
    };

    var sum: usize = 0;
    for (people) |person| {
        sum += person.age;
        std.debug.print("{s} is {d} years old\n", .{ person.name, person.age });
    }

    const average = @as(f64, @floatFromInt(sum)) / @as(f64, people.len);
    std.debug.print("Average age: {d:.2}\n", .{average});
}
