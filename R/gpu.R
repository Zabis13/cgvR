# GPU infrastructure for cgvR via ggmlR (Vulkan backend)

# Package-level environment for GPU state
.gpu_env <- new.env(parent = emptyenv())
.gpu_env$backend <- NULL
.gpu_env$initialized <- FALSE

#' Check if Vulkan GPU is Available
#'
#' Checks whether ggmlR is installed and a Vulkan device is present.
#'
#' @return Logical
#' @export
#' @examples
#' cgv_gpu_available()
cgv_gpu_available <- function() {
  if (!requireNamespace("ggmlR", quietly = TRUE)) return(FALSE)
  ggmlR::ggml_vulkan_available() && ggmlR::ggml_vulkan_device_count() > 0L
}

#' Initialize Vulkan GPU Backend
#'
#' Lazily initializes the Vulkan backend via ggmlR. Safe to call multiple times.
#'
#' @param device Integer, Vulkan device index (0-based).
#' @param force Logical, force re-initialization.
#' @return Invisible backend pointer.
#' @export
#' @examples
#' \donttest{
#' if (cgv_gpu_available()) {
#'   cgv_gpu_init()
#' }
#' }
cgv_gpu_init <- function(device = 0L, force = FALSE) {
  if (.gpu_env$initialized && !force) return(invisible(.gpu_env$backend))

  if (!cgv_gpu_available()) {
    stop("GPU not available: ggmlR not installed or no Vulkan device found")
  }

  if (!is.null(.gpu_env$backend)) {
    try(ggmlR::ggml_vulkan_free(.gpu_env$backend), silent = TRUE)
  }

  .gpu_env$backend <- ggmlR::ggml_vulkan_init(as.integer(device))
  .gpu_env$initialized <- TRUE

  invisible(.gpu_env$backend)
}

#' Get GPU Status
#'
#' Prints Vulkan availability, device info, and backend status.
#'
#' @return Invisible list with status details.
#' @export
#' @examples
#' cgv_gpu_status()
cgv_gpu_status <- function() {
  if (!requireNamespace("ggmlR", quietly = TRUE)) {
    cat("ggmlR: NOT INSTALLED\n")
    return(invisible(list(available = FALSE)))
  }

  vulkan_ok <- ggmlR::ggml_vulkan_available()
  if (!vulkan_ok) {
    cat("Vulkan: NOT AVAILABLE\n")
    return(invisible(list(available = FALSE, vulkan = FALSE)))
  }

  n_devices <- ggmlR::ggml_vulkan_device_count()
  cat("Vulkan: AVAILABLE\n")
  cat("Devices:", n_devices, "\n")

  devices <- list()
  if (n_devices > 0L) {
    dev_list <- ggmlR::ggml_vulkan_list_devices()
    for (d in dev_list) {
      cat(sprintf("  [%d] %s (%.2f GB free / %.2f GB total)\n",
                  d$index, d$name,
                  d$free_memory / 1e9, d$total_memory / 1e9))
    }
    devices <- dev_list
  }

  cat("Backend initialized:", .gpu_env$initialized, "\n")

  invisible(list(
    available = TRUE,
    vulkan = TRUE,
    n_devices = n_devices,
    devices = devices,
    initialized = .gpu_env$initialized
  ))
}

#' Free GPU Backend
#'
#' Releases Vulkan backend resources.
#'
#' @return Invisible NULL.
#' @export
cgv_gpu_free <- function() {
  if (!is.null(.gpu_env$backend)) {
    try(ggmlR::ggml_vulkan_free(.gpu_env$backend), silent = TRUE)
    .gpu_env$backend <- NULL
    .gpu_env$initialized <- FALSE
  }
  invisible(NULL)
}

#' Get Backend Pointer (internal)
#'
#' Returns the initialized backend, auto-initializing if needed.
#'
#' @return Backend pointer
#' @keywords internal
.get_gpu_backend <- function() {
  if (!.gpu_env$initialized) cgv_gpu_init()
  .gpu_env$backend
}
