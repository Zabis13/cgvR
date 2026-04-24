/*
 * visibility.c — BFS visibility zone extraction
 *
 * Given a focus node and depth, extract the subgraph within N hops.
 * This will be called from R and from the render loop.
 */
#include "cgvR.h"
#include <string.h>

/*
 * BFS from focus_node up to max_depth in adjacency list.
 * Returns visited node IDs.
 *
 * TODO: integrate with cayleyR's C++ BFS or reimplement here for
 * tight integration with the render pipeline.
 */
