#' Create a 3D Cayley Graph Viewer
#'
#' Opens a Vulkan-powered 3D window for interactive graph visualization.
#'
#' @param width Window width in pixels.
#' @param height Window height in pixels.
#' @param title Window title.
#' @param offscreen If \code{TRUE}, creates the viewer without a window
#'   surface (headless mode). Useful for automated tests and CI where no
#'   display is available.
#' @return An external pointer to the viewer object (invisibly).
#' @export
cgv_viewer <- function(width = 1280L, height = 720L, title = "cgvR", offscreen = FALSE) {
  .Call(C_cgv_viewer_create, as.integer(width), as.integer(height), title, as.logical(offscreen))
}

#' Set Background Color
#'
#' Set the panel background to a solid color or a 4-corner gradient.
#'
#' @param viewer External pointer returned by \code{cgv_viewer}.
#' @param color A single color string (e.g. \code{"#FFFFFF"}, \code{"white"}),
#'   or a character vector of 4 colors for corners (top-left, top-right,
#'   bottom-left, bottom-right).
#' @return Invisible \code{NULL}.
#' @export
cgv_background <- function(viewer, color) {
  rgba <- grDevices::col2rgb(color, alpha = TRUE)  # 4 x length(color)
  if (ncol(rgba) == 1L) {
    mat <- matrix(as.integer(rgba[, 1]), nrow = 1L, ncol = 4L)
  } else if (ncol(rgba) == 4L) {
    mat <- matrix(as.integer(t(rgba)), nrow = 4L, ncol = 4L, byrow = TRUE)
  } else {
    stop("color must be length 1 or 4")
  }
  invisible(.Call(C_cgv_set_background, viewer, mat))
}

#' Close the Viewer
#'
#' @param viewer External pointer returned by \code{cgv_viewer}.
#' @export
cgv_close <- function(viewer) {
  invisible(.Call(C_cgv_viewer_close, viewer))
}

#' Run the Viewer Event Loop
#'
#' Starts the rendering loop.
#'
#' @param viewer External pointer returned by \code{cgv_viewer}.
#' @param n_frames Maximum number of frames to render. \code{0} (default) means
#'   run until the window is closed (interactive mode). A positive value renders
#'   exactly that many frames and returns — useful for smoke tests and scripted
#'   rendering on machines with a display.
#' @export
cgv_run <- function(viewer, n_frames = 0L) {
  invisible(.Call(C_cgv_run, viewer, as.integer(n_frames)))
}
