# Light-weight input-validation tests. Do not create a viewer (no Vulkan/display
# required), so these run on CRAN.

test_that("cgv_fly_path rejects non-3-column matrix", {
  # Validation happens in R before .Call, so no viewer needed.
  # Pass NULL viewer — the ncol check fires first.
  expect_error(cgv_fly_path(NULL, matrix(1:4, ncol = 2)),
               "n x 3 matrix")
  expect_error(cgv_fly_path(NULL, matrix(1:5, ncol = 1)),
               "n x 3 matrix")
})

test_that("cgv_camera_mode rejects unknown mode", {
  expect_error(cgv_camera_mode(NULL, "spin"))
  expect_error(cgv_camera_mode(NULL, ""))
})

test_that("cgv_background rejects color vector of wrong length", {
  expect_error(cgv_background(NULL, c("red", "blue")),
               "length 1 or 4")
  expect_error(cgv_background(NULL, c("red", "blue", "green")),
               "length 1 or 4")
  expect_error(cgv_background(NULL, character(0)),
               "length 1 or 4")
})

test_that("cgv_background rejects invalid color names", {
  # grDevices::col2rgb errors on unknown names before reaching .Call.
  expect_error(cgv_background(NULL, "not-a-color"))
})
