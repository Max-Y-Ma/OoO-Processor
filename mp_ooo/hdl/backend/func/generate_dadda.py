#!/usr/bin/python3
import numpy as np

width = 32
length = 2*width-1

partial_wirelist = []
partial_netlist  = []
partials         = np.empty(dtype='object', shape=(width, length))
partials.fill("")

fa_wirelist      = []
fa_netlist       = []

ha_wirelist      = []
ha_netlist       = []

pass_wirelist    = []
pass_netlist     = []

# Generate partial products
for row in range(width):
  for col in range(width):
    curr_partial = f"a{col}b{row}"
    partial_wirelist.append(curr_partial)
    partials[row][col+row] = curr_partial
    if (col == width-1 and row != width-1):
      partial_netlist.append(f"assign {curr_partial} = (mul_type == 2'b0 ? (a[{col}] & b[{row}]) : ~(a[{col}] & b[{row}]))")
    elif (col != width-1 and row == width-1):
      partial_netlist.append(f"assign {curr_partial} = (mul_type == 2'b1 ? ~(a[{col}] & b[{row}]) : (a[{col}] & b[{row}]))")
    elif (col == width-1 and row == width-1):
      partial_netlist.append(f"assign {curr_partial} = (mul_type == 2'b10) ? ~(a[{col}] & b[{row}]) : (a[{col}] & b[{row}])")
    else:
      partial_netlist.append(f"assign {curr_partial} = (a[{col}] & b[{row}])")

# Generate Dadda sequence
dadda_sequence  = {}
j = 1
d = 2
while (d < width):
  dadda_sequence[j] = d
  d = int(1.5 * d)
  j += 1
j -= 1

reductions = []
reductions.append(partials)

# Perform reductions
layer = 0
next_height_offset = 0;
while (j > 0):
  reduction = np.empty(dtype='object', shape=(width, length))
  reduction.fill("")

  # print(f"\n--------------------------- REDUCTION {layer} ---------------------------\n")

  for i in range(length):
    # Calculate column height
    column = reductions[layer][:, i]
    column = column[column != ""]
    height = (column != "").sum()
    initial_height = height
    # Count the number of allocated nets in the current and next column
    curr_col_count = next_height_offset
    next_col_count = 0
    # Add full adders until either half adder or done
    fa_count = 0
    top = height - 1

    while (next_height_offset + height > dadda_sequence[j] + 1):
      # Allocate new wires to the next reduction, next column
      fa_wire = f"fa{fa_count}_layer{layer+1}_col{i}"
      fa_wirelist.append(fa_wire)

      # Allocate full adder
      adder_wires = [ column[top], column[top-1], column[top-2] ]
      fa_netlist.append(f"assign {fa_wire} = {adder_wires[0]} + {adder_wires[1]} + {adder_wires[2]}")

      # Move output wire names to next reduction layer
      reduction[next_col_count][i+1] = fa_wire + "[1]"
      reduction[curr_col_count][i]   = fa_wire + "[0]"

      fa_count += 1
      next_col_count += 1
      curr_col_count += 1
      height -= 2
      top -= 3

    # Half adder case
    ha_count = 0
    if (next_height_offset + height == dadda_sequence[j] + 1):
      # Allocate new wires to the next reduction, next column
      ha_wire = f"ha_layer{layer+1}_col{i}"
      ha_wirelist.append(ha_wire)

      # Allocate half adder
      adder_wires = [ column[top], column[top-1] ]
      ha_netlist.append(f"assign {ha_wire} = {adder_wires[0]} + {adder_wires[1]}")

      # Move output wire names to next reduction layer
      reduction[next_col_count][i+1] = ha_wire + "[1]"
      reduction[curr_col_count][i]   = ha_wire + "[0]"

      ha_count       += 1
      next_col_count += 1
      curr_col_count += 1
      height         -= 1
      top            -= 2

    # Copy remaining wires into the next reduction layer
    for remaining in range(top+1):
      passthrough_prev      = column[remaining];
      passthrough_wire      = f"pass_layer{layer+1}_col{i}_{remaining}"
      pass_wirelist.append(passthrough_wire)
      pass_netlist.append(f"assign {passthrough_wire} = {passthrough_prev}")
      reduction[curr_col_count][i] = passthrough_wire;
      curr_col_count += 1

    # print(f"\n-------------- COL {i} --------------\n")
    # print(column)
    # print(f"Height: {initial_height}")
    # print(f"Height Offset: {next_height_offset}")
    # print(f"FA Count: {fa_count}")
    # print(f"HA Count: {ha_count}")
    # print(f"Passthroughs: {top+1}")

    next_height_offset = next_col_count;

  # for row in reduction:
  #   if ((row != "").sum() > 0):
  #     print (row)

  reductions.append(reduction)
  layer += 1
  j-=1

# Combine last two rows into their vectors
sum1 = np.flip(reductions[-1][0])
sum2 = np.flip(reductions[-1][1])

sum1_vector = "{ "
sum2_vector = "{ "

for element in sum1[:-1]:
  if (element == ""):
    sum1_vector +=  "1'b0, "
  else:
    sum1_vector += (element + ", ")

if (sum1[-1] == ""):
  sum1_vector += "1'b0 }"
else:
  sum1_vector += sum1[-1] + " }"

for element in sum2[:-1]:
  if (element == ""):
    sum2_vector +=  "1'b0, "
  else:
    sum2_vector += (element + ", ")

if (sum2[-1] == ""):
  sum2_vector += "1'b0 }"
else:
  sum2_vector += sum2[-1] + " }"

# Create the sign vector
sign_vector = np.empty(dtype=object, shape=(2*width))
sign_vector.fill("1'b0")
sign_vector[2*width-1] = "mul_type == 2'b00 ? 1'b0 : 1'b1"
sign_vector[width]     = "mul_type == 2'b01 ? 1'b1 : 1'b0"
sign_vector[width-1]   = "mul_type == 2'b10 ? 1'b1 : 1'b0"
sign_vector            = np.flip(sign_vector)

# Output wirelist and netlist
f = open(f"multiplier_combinational.sv", "w")

f.write(
f'''/* Generated by generate_daddy.py, do not change. */
module multiplier_combinational (
  input logic [{width-1}:0]    a,
  input logic [{width-1}:0]    b,
  input logic [1:0]  mul_type,
  output logic [{2*width-1}:0] p
);

''')

f.write("logic " + ", ".join([wire for wire in partial_wirelist]) + ";\n")
f.write("logic " + ", ".join([wire for wire in pass_wirelist]) + ";\n")
f.write("logic [1:0] " + ", ".join([wire for wire in fa_wirelist]) + ";\n")
f.write("logic [1:0] " + ", ".join([wire for wire in ha_wirelist]) + ";\n")

for net in partial_netlist:
  f.write(net + ";\n")

for net in pass_netlist:
  f.write(net + ";\n")

for net in fa_netlist:
  f.write(net + ";\n")

for net in ha_netlist:
  f.write(net + ";\n")

f.write("assign p = " + sum1_vector + " + " + sum2_vector + " + { " + ", ".join([sign for sign in sign_vector]) + " };\n")

f.write(f"endmodule : multiplier_combinational\n")

f.close()
