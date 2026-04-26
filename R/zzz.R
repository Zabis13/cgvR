.onAttach <- function(libname, pkgname) {
  marker <- system.file("STUB_BUILD", package = pkgname)
  if (nzchar(marker) && file.exists(marker)) {
    reason <- tryCatch(readLines(marker, warn = FALSE)[1L], error = function(e) "")
    msg <- "cgvR was installed in STUB mode (no Vulkan support)."
    if (length(reason) && nzchar(reason)) {
      msg <- paste0(msg, "\nReason: ", reason)
    }
    msg <- paste0(msg,
      "\nNative rendering APIs (cgv_viewer, cgv_run, ...) will raise an error.",
      "\nInstall the Vulkan SDK + GLFW3 and reinstall cgvR for full functionality.")
    packageStartupMessage(msg)
  }
}

#' Is this a stub build?
#'
#' Returns \code{TRUE} when cgvR was installed without native rendering
#' support (no Vulkan / GLFW found at install time). In that case all
#' rendering functions raise an error; pure-R helpers like
#' \code{\link{cgv_layout_fr}} still work.
#'
#' @return Logical scalar.
#' @export
cgv_is_stub_build <- function() {
  marker <- system.file("STUB_BUILD", package = "cgvR")
  nzchar(marker) && file.exists(marker)
}
