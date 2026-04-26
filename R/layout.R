#' Fruchterman-Reingold Force-Directed Layout
#'
#' Computes 3D (or 2D) node positions so that connected nodes settle at
#' approximately equal distance \code{ideal_len}, while non-adjacent nodes
#' repel each other. Implements the Fruchterman-Reingold algorithm with
#' linearly-cooling temperature, fully vectorized over nodes and edges.
#'
#' @param n_nodes Integer. Number of nodes.
#' @param edges Two-column integer matrix \code{(from, to)}, 1-based. Direction
#'   is ignored (forces are symmetric).
#' @param n_iter Integer. Number of iterations (default 300).
#' @param ideal_len Numeric. Target edge length. If \code{NULL}, defaults to
#'   \code{n_nodes^(1/dim) * 0.8}.
#' @param dim Integer, 2 or 3. Output dimensionality (default 3).
#' @param seed Optional integer for reproducible initialization.
#' @param init Optional \code{n_nodes x dim} matrix of initial positions.
#'   If \code{NULL}, uses \code{rnorm}.
#' @param cool Numeric in (0, 1]. Per-iteration temperature decay (default 0.98).
#' @param normalize Logical. If \code{TRUE}, recenters and scales output to
#'   fit in \code{[-15, 15]} (matches the demos' camera setup). Default \code{TRUE}.
#' @param verbose Logical. Print progress every 50 iterations.
#' @return Numeric matrix \code{n_nodes x dim} of node coordinates.
#' @examples
#' \dontrun{
#' edges <- cbind(c(1, 2, 3, 4), c(2, 3, 4, 1))
#' pos <- cgv_layout_fr(4, edges, n_iter = 200)
#' }
#' @importFrom stats rnorm
#' @export
cgv_layout_fr <- function(n_nodes, edges,
                          n_iter = 300L,
                          ideal_len = NULL,
                          dim = 3L,
                          seed = NULL,
                          init = NULL,
                          cool = 0.98,
                          normalize = TRUE,
                          verbose = FALSE) {
  n_nodes <- as.integer(n_nodes)
  dim <- as.integer(dim)
  n_iter <- as.integer(n_iter)
  stopifnot(n_nodes >= 1L, dim %in% c(2L, 3L), n_iter >= 0L,
            cool > 0, cool <= 1)

  if (is.null(ideal_len)) ideal_len <- n_nodes ^ (1 / dim) * 0.8
  ideal_len <- as.double(ideal_len)

  if (!is.null(seed)) set.seed(seed)
  if (is.null(init)) {
    pos <- matrix(rnorm(n_nodes * dim), ncol = dim)
  } else {
    stopifnot(is.matrix(init), nrow(init) == n_nodes, ncol(init) == dim)
    pos <- init
  }

  if (length(edges) == 0L || n_nodes < 2L) {
    if (normalize && n_nodes >= 1L) {
      pos <- sweep(pos, 2, colMeans(pos))
      m <- max(abs(pos))
      if (m > 0) pos <- pos / m * 15
    }
    return(pos)
  }

  edges <- matrix(as.integer(edges), ncol = 2)
  ef <- edges[, 1]
  et <- edges[, 2]
  stopifnot(all(ef >= 1L & ef <= n_nodes), all(et >= 1L & et <= n_nodes))

  k2 <- ideal_len * ideal_len
  temp <- ideal_len * 2
  eps <- 1e-6

  for (iter in seq_len(n_iter)) {
    # Repulsion: pairwise via outer differences (n x n x dim).
    # For each axis, dx[i,j] = pos[i] - pos[j].
    disp <- matrix(0, nrow = n_nodes, ncol = dim)
    # Pairwise squared distances
    d2 <- matrix(0, nrow = n_nodes, ncol = n_nodes)
    diffs <- vector("list", dim)
    for (a in seq_len(dim)) {
      dx <- outer(pos[, a], pos[, a], "-")  # i - j
      diffs[[a]] <- dx
      d2 <- d2 + dx * dx
    }
    # Avoid div by zero on diagonal
    d2[d2 < eps] <- eps
    # Repulsive force magnitude per pair: k^2 / d, applied along dx / d
    # force vector i from j: (dx / d) * (k^2 / d) = dx * k^2 / d^2
    inv_d2 <- k2 / d2
    diag(inv_d2) <- 0
    for (a in seq_len(dim)) {
      disp[, a] <- disp[, a] + rowSums(diffs[[a]] * inv_d2)
    }

    # Attraction along edges: f = d^2 / k, applied along (b - a) / d.
    # Vector contribution to a: + (b - a) * d / k ; to b: - (b - a) * d / k.
    delta <- pos[et, , drop = FALSE] - pos[ef, , drop = FALSE]
    d_e <- sqrt(rowSums(delta * delta))
    d_e[d_e < eps] <- eps
    coef <- d_e / ideal_len  # = (d^2 / k) / d
    contrib <- delta * coef
    # Accumulate per-node via tapply-style aggregation
    for (a in seq_len(dim)) {
      acc <- numeric(n_nodes)
      acc <- acc + tabulate_sum(ef, contrib[, a], n_nodes)
      acc <- acc - tabulate_sum(et, contrib[, a], n_nodes)
      disp[, a] <- disp[, a] + acc
    }

    # Limit per-node displacement by temperature
    dl <- sqrt(rowSums(disp * disp))
    dl[dl < eps] <- eps
    scale <- pmin(temp, dl) / dl
    pos <- pos + disp * scale

    temp <- temp * cool

    if (verbose && iter %% 50L == 0L) {
      message(sprintf("FR iter %d/%d, temp=%.4f", iter, n_iter, temp))
    }
  }

  if (normalize) {
    pos <- sweep(pos, 2, colMeans(pos))
    m <- max(abs(pos))
    if (m > 0) pos <- pos / m * 15
  }
  pos
}

#' Barnes-Hut Fruchterman-Reingold Layout (3D, fast)
#'
#' Same energy model as \code{cgv_layout_fr} but with O(n log n) repulsion
#' approximated through an octree. Suitable for large graphs (10^4+ nodes).
#'
#' @param n_nodes Integer. Number of nodes.
#' @param edges Two-column integer matrix \code{(from, to)}, 1-based.
#' @param n_iter Integer. Number of iterations (default 200).
#' @param ideal_len Numeric target edge length. If \code{NULL},
#'   defaults to \code{n_nodes^(1/3) * 0.8}.
#' @param theta Barnes-Hut opening angle (default 1.0). Larger = faster, less accurate.
#' @param cool Per-iteration temperature decay (default 0.98).
#' @param min_dist Minimum distance clamp for repulsion / edge attraction
#'   (default 0.01). Avoids division-by-zero when nodes coincide.
#' @param seed Optional integer for reproducible initialization.
#' @param init Optional \code{n_nodes x 3} matrix of initial positions.
#'   If \code{NULL}, uses \code{rnorm}.
#' @param normalize Logical. If \code{TRUE}, recenters and scales output to
#'   \code{[-15, 15]}. Default \code{TRUE}.
#' @return Numeric matrix \code{n_nodes x 3} of node coordinates.
#' @importFrom stats rnorm
#' @export
cgv_layout_fr_bh <- function(n_nodes, edges,
                             n_iter = 200L,
                             ideal_len = NULL,
                             theta = 1.0,
                             cool = 0.98,
                             min_dist = 0.01,
                             seed = NULL,
                             init = NULL,
                             normalize = TRUE) {
  n_nodes <- as.integer(n_nodes)
  n_iter  <- as.integer(n_iter)
  stopifnot(n_nodes >= 1L, n_iter >= 0L,
            theta > 0, cool > 0, cool <= 1, min_dist > 0)

  if (is.null(ideal_len)) ideal_len <- n_nodes ^ (1 / 3) * 0.8
  ideal_len <- as.double(ideal_len)

  if (!is.null(seed)) set.seed(seed)
  if (is.null(init)) {
    pos <- matrix(rnorm(n_nodes * 3), ncol = 3)
  } else {
    stopifnot(is.matrix(init), nrow(init) == n_nodes, ncol(init) == 3)
    pos <- init
  }
  pos <- matrix(as.double(pos), ncol = 3)

  if (length(edges) == 0L) {
    edges_i <- matrix(integer(0), ncol = 2)
  } else {
    edges_i <- matrix(as.integer(edges), ncol = 2)
    stopifnot(all(edges_i >= 1L & edges_i <= n_nodes))
  }

  out <- .Call(C_cgv_layout_fr_bh, pos, edges_i,
               n_iter, ideal_len, as.double(theta), as.double(cool),
               as.double(min_dist))

  if (normalize && n_nodes >= 1L) {
    out <- sweep(out, 2, colMeans(out))
    m <- max(abs(out))
    if (m > 0) out <- out / m * 15
  }
  out
}

# Helper: sum values per integer index in [1, n]. Vectorized via tapply.
tabulate_sum <- function(idx, vals, n) {
  out <- numeric(n)
  s <- .rowsum_fast(vals, idx, n)
  out[s$idx] <- s$sum
  out
}

# Group-sum without coercing to data.frame; uses base::rowsum.
.rowsum_fast <- function(vals, idx, n) {
  r <- rowsum(vals, idx, reorder = FALSE)
  list(idx = as.integer(rownames(r)), sum = as.numeric(r))
}
