# Suppress native stderr (Vulkan driver warnings from C code).
# sink(type="message") only captures R-level messages, not C fprintf(stderr).
# We use OS-level fd redirect via dup2 in C.
if (.Platform$OS.type == "unix") {
  .cgvR_saved_fd <- .Call("C_cgv_suppress_stderr", PACKAGE = "cgvR")
}
