test_that("package loads", {
  expect_true(require(cgvR, quietly = TRUE))
})

test_that("all exported functions exist", {
  expect_true(is.function(cgv_viewer))
  expect_true(is.function(cgv_close))
  expect_true(is.function(cgv_run))
  expect_true(is.function(cgv_set_graph))
  expect_true(is.function(cgv_set_visibility))
  expect_true(is.function(cgv_highlight_path))
  expect_true(is.function(cgv_camera))
  expect_true(is.function(cgv_fly_to))
  expect_true(is.function(cgv_fly_path))
  expect_true(is.function(cgv_camera_mode))
  expect_true(is.function(cgv_clear_path))
  expect_true(is.function(cgv_background))
})

test_that("NAMESPACE exports match implementations", {
  exported <- getNamespaceExports("cgvR")
  cgv_exports <- grep("^cgv_", exported, value = TRUE)
  for (fn in cgv_exports) {
    expect_true(is.function(get(fn, envir = asNamespace("cgvR"))),
                info = fn)
  }
})
