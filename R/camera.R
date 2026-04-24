#' Set Camera Position and Direction
#'
#' @param viewer External pointer returned by \code{cgv_viewer}.
#' @param position Numeric vector of length 3 (x, y, z).
#' @param target Numeric vector of length 3 — look-at point.
#' @param up Numeric vector of length 3 — up direction.
#' @return Invisible \code{NULL}.
#' @export
cgv_camera <- function(viewer, position = c(0, 0, 5),
                       target = c(0, 0, 0), up = c(0, 1, 0)) {
  invisible(.Call(C_cgv_camera_set, viewer,
                  as.double(position), as.double(target), as.double(up)))
}

#' Switch Camera Mode
#'
#' @param viewer External pointer returned by \code{cgv_viewer}.
#' @param mode Character: \code{"fly"} (WASD + mouse) or \code{"orbit"}
#'   (rotate around target with Shift+drag, scroll zoom).
#' @return Invisible \code{NULL}.
#' @export
cgv_camera_mode <- function(viewer, mode = c("fly", "orbit")) {
  mode <- match.arg(mode)
  invisible(.Call(C_cgv_camera_mode, viewer, mode))
}

#' Fly Camera to a Node
#'
#' Smoothly animate the camera to center on a given node.
#' Requires that \code{cgv_set_graph} was called first (for node positions).
#'
#' @param viewer External pointer returned by \code{cgv_viewer}.
#' @param node_id Integer node identifier (1-based R index).
#' @param duration Animation duration in seconds.
#' @return Invisible \code{NULL}.
#' @export
cgv_fly_to <- function(viewer, node_id, duration = 1.0) {
  invisible(.Call(C_cgv_fly_to, viewer,
                  as.integer(node_id - 1L), as.double(duration)))
}

#' Fly Camera Along a Path
#'
#' Smoothly animate the camera along a sequence of 3D waypoints
#' using Catmull-Rom spline interpolation.
#'
#' @param viewer External pointer returned by \code{cgv_viewer}.
#' @param positions Numeric matrix with 3 columns (x, y, z), one row per waypoint.
#' @param duration Total animation duration in seconds.
#' @param loop Logical: loop the animation?
#' @return Invisible \code{NULL}.
#' @export
cgv_fly_path <- function(viewer, positions, duration = 5.0, loop = FALSE) {
  positions <- as.matrix(positions)
  if (ncol(positions) != 3L)
    stop("positions must be an n x 3 matrix")
  invisible(.Call(C_cgv_fly_path, viewer, positions,
                  as.double(duration), as.logical(loop)))
}
