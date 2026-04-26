# Disable the Microsoft DirectX-to-Vulkan (dzn) ICD: it's installed by
# mesa-vulkan-drivers on Linux but always fails to init on non-WSL systems
# and spams the log. VK_LOADER_DRIVERS_DISABLE is supported by Vulkan Loader
# 1.3.234+ and is a no-op on older loaders.
Sys.setenv(VK_LOADER_DRIVERS_DISABLE = "dzn_icd.json")

# Detect stub build (no Vulkan / GLFW at install time). In that mode every
# native .Call raises an error, so we must avoid touching them.
.cgvR_stub <- isTRUE(tryCatch(cgvR::cgv_is_stub_build(),
                              error = function(e) FALSE))

# Suppress native stderr (Vulkan driver warnings from C code).
# sink(type="message") only captures R-level messages, not C fprintf(stderr).
# We use OS-level fd redirect via dup2 in C. Skipped under stub builds.
if (.Platform$OS.type == "unix" && !.cgvR_stub) {
  .cgvR_saved_fd <- .Call("C_cgv_suppress_stderr", PACKAGE = "cgvR")
}
