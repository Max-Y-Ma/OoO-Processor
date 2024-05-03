class fifo_golden;
  // Golden Model Variables
  fifo_type_t queue [$:`FIFO_DEPTH];
  fifo_type_t queue_rdata;
  logic queue_empty, queue_full;

  function void check(specific_txn txn);

    queue_empty = (queue.size() == '0);
    queue_full = (queue.size() == `FIFO_DEPTH);

    if (txn.rst) begin
      queue.delete();
    end
    else begin
      queue_rdata = queue[0];
      if (txn.read_write[0] && ~queue_full) begin
        queue.push_back(txn.wdata);
      end
      if (txn.read_write[1] && ~queue_empty) begin
        queue.pop_front();
      end
    end

    // Assertion Checker
    if (!txn.rst) begin
      assert_queue_empty : assert(queue_empty == txn.empty) 
      else $fatal("[ASSERTION ERROR] Incorrect Empty Flag! queue_empty = %0d, empty = %0d", queue_empty, txn.empty);

      assert_queue_full : assert(queue_full == txn.full) 
      else $fatal("[ASSERTION ERROR] Incorrect Full Flag! queue_full = %0d, full = %0d", queue_full, txn.full);

      if (txn.read_write[1] && queue_empty == 0) begin
        assert_queue_read_not_empty : assert(queue_rdata == txn.rdata)
        else $fatal("[ASSERTION ERROR] Incorrect Read Data! queue_rdata = %0d, rdata = %0d", queue_rdata, txn.rdata);
      end
    end
  endfunction : check

endclass : fifo_golden
