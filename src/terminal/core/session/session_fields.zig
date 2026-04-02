const runtime_fields = @import("runtime_fields.zig");
const interaction_fields = @import("interaction_fields.zig");
const publication_fields = @import("publication_fields.zig");
const control_fields = @import("control_fields.zig");

pub const Fields = struct {
    runtime: runtime_fields.Fields,
    interaction: interaction_fields.Fields,
    publication: publication_fields.Fields,
    control: control_fields.Fields,
};
