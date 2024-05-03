class plru_node;

  bit       val;
  plru_node left, right;

  function new(bit val);
    val   = val;
    left  = null;
    right = null;
  endfunction : new

endclass

/* Golden Model for a given cache index */
class plru_golden;

  int height;
  int ways;
  plru_node plru_root;

  function new(ways);
    ways        = ways;
    height      = $clog2(ways);
    plru_root   = new(0);

    construt_tree(height, 0, plru_root);
  endfunction

  function automatic construct_tree(int level, ref plru_node subtree);
    /* Base case */
    if (height == level) begin
      return;
    end

    /* Recursive case, allocate left and right, call recursive constructor on it */
    subtree.left = new(0);
    subtree.right = new(0);
    construct_tree(level + 1, subtree.left);
    construct_tree(level + 1, subtree.right);

    return;
  endfunction

  function void update_plru(bit cache_hit[]);
    assert_cache_vector_ways : assert(cache_hit.size() == ways)
    else $fatal("[ASSERTION ERROR] Number of ways doesn't match the hit vector! ways = %0d, cache_hit = %0d", ways, cache_hit.size());
    assert_cache_onehot: assert($onehot(cache_hit))
    else $fatal("[ASSERTION ERROR] Cache Not One Hot cache_vector %s", $sformatf("%p", cache_hit));

    /* Traverse plru_tree updating as we go along */
    update_plru_tree(plru_root);
  endfunction

  function automatic update_plru_tree(plru_node subtree);
    /* Leaf case */
    if (subtree.left == null || subtree.right == null) begin
      return;
    end
    else if () begin
    end
  endfunction

  function bit [] evict_candidate();
    int evict_idx;
    evict_array = new[ways];

    foreach(evict_array[i]) begin
      evict_array[i] = 0;
    end

    return evict_array[evict_idx(0, plru_root)];
  endfunction

  function automatic int evict_idx(int level, plru_node subtree);
    /* Base Case */
    if (level == height)
      return subtree.val;
    end

    /* Recursive Case */
    if (subtree.val == 0)
      return evict_idx(level+1, subtree.right);
    else
      return (level / 2) + evict_idx(level+1, subtree.left);

  endfunction 

endclass
