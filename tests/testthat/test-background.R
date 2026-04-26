test_that("cgv_background accepts a single color", {
  v <- cgv_viewer(320, 240, "test-bg-1", offscreen = TRUE)
  expect_no_error(cgv_background(v, "#202020"))
  expect_no_error(cgv_background(v, "white"))
  cgv_close(v)
})

test_that("cgv_background accepts 4 corner colors (gradient)", {
  v <- cgv_viewer(320, 240, "test-bg-4", offscreen = TRUE)
  corners <- c("#FF0000", "#00FF00", "#0000FF", "#FFFFFF")
  expect_no_error(cgv_background(v, corners))
  cgv_close(v)
})

test_that("cgv_background handles transparency", {
  v <- cgv_viewer(320, 240, "test-bg-alpha", offscreen = TRUE)
  expect_no_error(cgv_background(v, "#FF000080"))
  cgv_close(v)
})
