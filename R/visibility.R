#' Set Visibility Depth
#'
#' Controls how many hops from the current focus node are rendered.
#'
#' @param viewer External pointer returned by \code{cgv_viewer}.
#' @param depth Integer number of hops (default 10).
#' @return Invisible \code{NULL}.
#' @export
cgv_set_visibility <- function(viewer, depth = 10L) {
  invisible(.Call(C_cgv_set_visibility, viewer, as.integer(depth)))
}
