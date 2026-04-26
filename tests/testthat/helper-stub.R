skip_if_stub <- function() {
  if (isTRUE(tryCatch(cgvR::cgv_is_stub_build(),
                      error = function(e) FALSE))) {
    testthat::skip("cgvR is a stub build (no Vulkan)")
  }
}
