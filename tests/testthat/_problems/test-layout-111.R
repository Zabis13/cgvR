# Extracted from test-layout.R:111

# setup ------------------------------------------------------------------------
library(testthat)
test_env <- simulate_test_env(package = "cgvR", path = "..")
attach(test_env, warn.conflicts = FALSE)

# test -------------------------------------------------------------------------
set.seed(11)
n <- 1000L
edges <- cbind(seq_len(n), c(seq.int(2L, n), 1L))
t0 <- Sys.time()
pos <- cgv_layout_fr_bh(n, edges, n_iter = 50L, seed = 1L)
