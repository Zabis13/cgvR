# Extracted from test-layout.R:83

# setup ------------------------------------------------------------------------
library(testthat)
test_env <- simulate_test_env(package = "cgvR", path = "..")
attach(test_env, warn.conflicts = FALSE)

# test -------------------------------------------------------------------------
edges <- cbind(c(1, 2, 3, 4), c(2, 3, 4, 1))
pos <- cgv_layout_fr_bh(4, edges, n_iter = 500L, seed = 2L)
