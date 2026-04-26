# Extracted from test-layout.R:93

# setup ------------------------------------------------------------------------
library(testthat)
test_env <- simulate_test_env(package = "cgvR", path = "..")
attach(test_env, warn.conflicts = FALSE)

# test -------------------------------------------------------------------------
pos <- cgv_layout_fr_bh(5, matrix(integer(0), ncol = 2),
                          n_iter = 50L, seed = 1L)
