test_that("cgv_gpu_available returns logical", {
  result <- cgv_gpu_available()
  expect_type(result, "logical")
  expect_length(result, 1)
})

test_that("cgv_gpu_status runs without error", {
  expect_no_error(invisible(capture.output(cgv_gpu_status())))
})

test_that("cgv_gpu_init and cgv_gpu_free work", {
  skip_if_not(cgv_gpu_available(), "No Vulkan GPU available")

  backend <- cgv_gpu_init()
  expect_false(is.null(backend))

  # calling again returns same backend (lazy init)
  backend2 <- cgv_gpu_init()
  expect_identical(backend, backend2)

  # force re-init
  backend3 <- cgv_gpu_init(force = TRUE)
  expect_false(is.null(backend3))

  # free
  expect_no_error(cgv_gpu_free())

  # free again is safe
  expect_no_error(cgv_gpu_free())
})
