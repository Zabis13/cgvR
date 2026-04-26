# Restore stderr after tests (full builds only).
if (.Platform$OS.type == "unix" && exists(".cgvR_saved_fd", inherits = FALSE)) {
  .Call("C_cgv_restore_stderr", .cgvR_saved_fd, PACKAGE = "cgvR")
}
