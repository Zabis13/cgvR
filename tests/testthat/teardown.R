# Restore stderr after tests
if (.Platform$OS.type == "unix") {
  .Call("C_cgv_restore_stderr", .cgvR_saved_fd, PACKAGE = "cgvR")
}
