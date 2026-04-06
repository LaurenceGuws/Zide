const bootstrap_contract = @import("bootstrap_contract.zig");
const gl_backend = @import("gl_backend.zig");
const metal_backend = @import("metal_backend.zig");

pub fn opsForBackend(backend: anytype) bootstrap_contract.BackendBootstrapOps {
    return switch (backend) {
        .opengl => gl_backend.bootstrapOps(),
        .metal => metal_backend.bootstrapOps(),
    };
}
