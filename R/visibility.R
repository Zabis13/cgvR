#' Set Visibility Depth
#'
#' Controls how many hops from the current focus node are rendered.
#'
#' @param viewer External pointer returned by \code{cgv_viewer}.
#' @param depth Integer number of hops (default 10).
#' @return No return value, called for side effects: updates the
#'   visibility depth used to filter rendered nodes by BFS distance.
#'   Returns \code{NULL} invisibly.
#' @export
cgv_set_visibility <- function(viewer, depth = 10L) {
  invisible(.Call(C_cgv_set_visibility, viewer, as.integer(depth)))
}
