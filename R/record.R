#' Start Recording the Viewer to a Video File
#'
#' Pipes raw RGB frames from the live canvas into \code{ffmpeg}, which
#' encodes them on the fly. The recording runs in the background while the
#' user keeps interacting with the viewer (mouse, keyboard).
#'
#' Requires \code{ffmpeg} on PATH. The container/codec is chosen by the
#' file extension (\code{.mp4} / \code{.mkv} / \code{.webm} / etc.).
#' Frames are captured at the requested \code{fps}; if the rendering loop
#' produces frames faster, extras are dropped.
#'
#' The recording is automatically stopped when the viewer is closed,
#' \code{cgv_record_stop()} is called, or the optional \code{duration}
#' elapses.
#'
#' @param viewer External pointer from \code{cgv_viewer()}. The window must
#'   already be running (call this from a frame callback, or after
#'   \code{cgv_run()} has built the canvas — typically by setting a
#'   \code{duration} and starting recording before \code{cgv_run()}).
#' @param file Output path; extension determines the format.
#' @param fps Frames per second (default 30).
#' @param duration Optional cap in seconds; \code{NA} = unlimited.
#' @param ffmpeg_args Optional extra ffmpeg flags spliced before the output
#'   path (e.g. \code{"-c:v libvpx-vp9 -b:v 2M"}). \code{NULL} = use defaults
#'   (libx264, yuv420p, veryfast).
#' @return Invisible \code{NULL}.
#' @export
cgv_record_start <- function(viewer, file, fps = 30L,
                             duration = NA_real_,
                             ffmpeg_args = NULL) {
  if (Sys.which("ffmpeg") == "") {
    stop("ffmpeg not found. Install with: sudo apt install ffmpeg")
  }
  fps <- as.integer(fps)
  if (length(fps) != 1L || is.na(fps) || fps <= 0L) {
    stop("fps must be a positive integer")
  }
  duration <- as.double(duration)
  if (length(duration) != 1L) stop("duration must be length 1")
  args <- if (is.null(ffmpeg_args)) NA_character_ else as.character(ffmpeg_args)

  invisible(.Call(C_cgv_record_start, viewer, as.character(file),
                  fps, duration, args))
}

#' Stop the Active Recording
#'
#' Closes the ffmpeg pipe (which finalises the output file) and frees the
#' recording state on the viewer.
#'
#' @param viewer External pointer from \code{cgv_viewer()}.
#' @return Invisibly, an integer vector \code{c(frames, fps)} reporting how
#'   many frames were written.
#' @export
cgv_record_stop <- function(viewer) {
  res <- .Call(C_cgv_record_stop, viewer)
  invisible(res)
}
