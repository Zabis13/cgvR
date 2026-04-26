# Extracted from test-layout.R:68

# setup ------------------------------------------------------------------------
library(testthat)
test_env <- simulate_test_env(package = "cgvR", path = "..")
attach(test_env, warn.conflicts = FALSE)

# test -------------------------------------------------------------------------
edges <- cbind(c(1, 2, 3), c(2, 3, 1))
pos <- cgv_layout_fr_bh(3, edges, n_iter = 50L, seed = 1L)
