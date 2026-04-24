test_that("cgv_viewer creates and closes viewer", {
  v <- cgv_viewer(640, 480, "test")
  expect_true(inherits(v, "externalptr"))

  # close
  expect_no_error(cgv_close(v))
})

test_that("cgv_close on NULL pointer does not crash", {
  v <- cgv_viewer(320, 240, "test2")
  cgv_close(v)
  # second close should be safe (pointer already cleared)
  expect_no_error(cgv_close(v))
})

test_that("cgv_set_visibility works", {
  v <- cgv_viewer(320, 240, "test-vis")
  expect_no_error(cgv_set_visibility(v, 5L))
  expect_no_error(cgv_set_visibility(v, 20L))
  cgv_close(v)
})
