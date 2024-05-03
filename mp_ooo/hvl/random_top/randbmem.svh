class randbmem;

rand bit [4:0] rand_bmem_delay;
rand bit [31:0] rand_load_access;
rand bit [3:0] rand_request_index;

constraint rand_bmem_delay_t {
  rand_bmem_delay inside {5'd0, 5'd1};
}

constraint rand_load_access_t {
  rand_load_access[1:0] == 2'b00;
  rand_load_access[9:8] == 2'b00;
  rand_load_access[17:16] == 2'b00;
  rand_load_access[25:24] == 2'b00;
}

endclass
