# Tests for cgv_layout_fr — pure R, no viewer needed.

test_that("cgv_layout_fr returns matrix of correct shape", {
  edges <- cbind(c(1, 2, 3), c(2, 3, 1))
  pos <- cgv_layout_fr(3, edges, n_iter = 50L, seed = 1L)
  expect_true(is.matrix(pos))
  expect_equal(nrow(pos), 3)
  expect_equal(ncol(pos), 3)

  pos2 <- cgv_layout_fr(3, edges, n_iter = 50L, seed = 1L, dim = 2L)
  expect_equal(ncol(pos2), 2)
})

test_that("cgv_layout_fr is reproducible with same seed", {
  edges <- cbind(c(1, 2, 3, 4), c(2, 3, 4, 1))
  p1 <- cgv_layout_fr(4, edges, n_iter = 100L, seed = 7L)
  p2 <- cgv_layout_fr(4, edges, n_iter = 100L, seed = 7L)
  expect_equal(p1, p2)
})

test_that("cgv_layout_fr equalizes edge lengths on a triangle", {
  # 3-node cycle: all three edges should converge to ~ same length.
  edges <- cbind(c(1, 2, 3), c(2, 3, 1))
  pos <- cgv_layout_fr(3, edges, n_iter = 500L, seed = 1L)

  d <- function(a, b) sqrt(sum((pos[a, ] - pos[b, ])^2))
  lens <- c(d(1, 2), d(2, 3), d(3, 1))
  cv <- sd(lens) / mean(lens)  # coefficient of variation
  expect_lt(cv, 0.05)
})

test_that("cgv_layout_fr equalizes edge lengths on a 4-cycle", {
  edges <- cbind(c(1, 2, 3, 4), c(2, 3, 4, 1))
  pos <- cgv_layout_fr(4, edges, n_iter = 500L, seed = 2L)

  d <- function(a, b) sqrt(sum((pos[a, ] - pos[b, ])^2))
  lens <- c(d(1, 2), d(2, 3), d(3, 4), d(4, 1))
  cv <- sd(lens) / mean(lens)
  expect_lt(cv, 0.10)
})

test_that("cgv_layout_fr handles isolated nodes (no edges)", {
  pos <- cgv_layout_fr(5, matrix(integer(0), ncol = 2),
                       n_iter = 50L, seed = 1L)
  expect_equal(dim(pos), c(5, 3))
  expect_true(all(is.finite(pos)))
})

test_that("cgv_layout_fr normalizes output into [-15, 15]", {
  edges <- cbind(c(1, 2, 3, 4), c(2, 3, 4, 1))
  pos <- cgv_layout_fr(4, edges, n_iter = 100L, seed = 1L, normalize = TRUE)
  expect_lte(max(abs(pos)), 15 + 1e-9)
  # Centered
  expect_equal(colMeans(pos), c(0, 0, 0), tolerance = 1e-9)
})

test_that("cgv_layout_fr accepts custom init", {
  edges <- cbind(c(1, 2), c(2, 3))
  init <- matrix(c(0, 1, 2, 0, 0, 0, 0, 0, 0), nrow = 3)
  pos <- cgv_layout_fr(3, edges, n_iter = 0L, init = init, normalize = FALSE)
  expect_equal(pos, init)
})

# ── Barnes-Hut variant ─────────────────────────────────

test_that("cgv_layout_fr_bh returns matrix of correct shape", {
  skip_if_stub()
  edges <- cbind(c(1, 2, 3), c(2, 3, 1))
  pos <- cgv_layout_fr_bh(3, edges, n_iter = 50L, seed = 1L)
  expect_true(is.matrix(pos))
  expect_equal(dim(pos), c(3L, 3L))
  expect_true(all(is.finite(pos)))
})

test_that("cgv_layout_fr_bh is reproducible with same seed", {
  skip_if_stub()
  edges <- cbind(c(1, 2, 3, 4), c(2, 3, 4, 1))
  p1 <- cgv_layout_fr_bh(4, edges, n_iter = 100L, seed = 7L)
  p2 <- cgv_layout_fr_bh(4, edges, n_iter = 100L, seed = 7L)
  expect_equal(p1, p2)
})

test_that("cgv_layout_fr_bh equalizes edge lengths on a 4-cycle", {
  skip_if_stub()
  edges <- cbind(c(1, 2, 3, 4), c(2, 3, 4, 1))
  pos <- cgv_layout_fr_bh(4, edges, n_iter = 500L, seed = 2L)

  d <- function(a, b) sqrt(sum((pos[a, ] - pos[b, ])^2))
  lens <- c(d(1, 2), d(2, 3), d(3, 4), d(4, 1))
  cv <- sd(lens) / mean(lens)
  expect_lt(cv, 0.10)
})

test_that("cgv_layout_fr_bh handles isolated nodes (no edges)", {
  skip_if_stub()
  pos <- cgv_layout_fr_bh(5, matrix(integer(0), ncol = 2),
                          n_iter = 50L, seed = 1L)
  expect_equal(dim(pos), c(5L, 3L))
  expect_true(all(is.finite(pos)))
})

test_that("cgv_layout_fr_bh normalizes output into [-15, 15]", {
  skip_if_stub()
  edges <- cbind(c(1, 2, 3, 4), c(2, 3, 4, 1))
  pos <- cgv_layout_fr_bh(4, edges, n_iter = 100L, seed = 1L, normalize = TRUE)
  expect_lte(max(abs(pos)), 15 + 1e-9)
  expect_equal(colMeans(pos), c(0, 0, 0), tolerance = 1e-9)
})

test_that("cgv_layout_fr_bh handles many nodes quickly", {
  skip_if_stub()
  # Sanity-check: 1000 nodes should run in a few seconds at most.
  set.seed(11)
  n <- 1000L
  edges <- cbind(seq_len(n), c(seq.int(2L, n), 1L))
  t0 <- Sys.time()
  pos <- cgv_layout_fr_bh(n, edges, n_iter = 50L, seed = 1L)
  dt <- as.numeric(Sys.time() - t0, units = "secs")
  expect_equal(dim(pos), c(n, 3L))
  expect_true(all(is.finite(pos)))
  expect_lt(dt, 10)  # generous bound
})
