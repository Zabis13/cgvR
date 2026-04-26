library(testthat)
library(cgvR)

# Tests requiring a real display + Vulkan device (window creation, camera,
# graph upload, recording). Skipped on CRAN since CRAN build machines are
# headless and lack a usable Vulkan ICD; also skipped when cgvR was installed
# in stub mode (no Vulkan support). Run locally via devtools::test() with
# NOT_CRAN=true and a full build.
heavy <- c(
  "viewer",
  "camera",
  "graph",
  "background",
  "record"
)

on_cran <- !identical(Sys.getenv("NOT_CRAN"), "true")

test_dir <- if (dir.exists("testthat")) "testthat" else "tests/testthat"

if (on_cran) {
  message("--- RUNNING LIGHT TESTS ONLY ---")

  all_tests <- list.files(test_dir, pattern = "^test-.*\\.R$")
  all_names <- sub("^test-(.*)\\.R$", "\\1", all_tests)

  light_tests <- setdiff(all_names, heavy)
  message("Tests to run: ", paste(light_tests, collapse = ", "))

  if (length(light_tests) == 0) {
    test_check("cgvR")
  } else {
    filter_regex <- paste(light_tests, collapse = "|")
    test_check("cgvR", filter = filter_regex)
  }
} else {
  test_check("cgvR")
}
