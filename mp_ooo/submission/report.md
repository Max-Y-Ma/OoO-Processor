# CP1 Progress Report

# Block Diagram
- The block diagram was constructed from a high-level perspective. The specific signals are not included because they are very subject to change. The major blocks and pipeline stages are of value in this initial block diagram.

## Participation
- **Max**: Tasked with implementing the out-of-order backend, which will be modeled by the explicit register renaming datapath. Max will also implement advanced features such as a pipelined Wallace tree multiplier and early branch resolution.
- **Larry**: Tasked with implementing the in-order frontend, which includes the fetch stage and instruction queue. Larry will also implement advanced features such as a branch predictor.
- **Josh**: Tasked with implementing the memory hierarchy, which includes both instruction and data caches. Josh will also implement advanced features such as a pipelined, non-blocking cache and a prefetcher.

## Verification
- The main testing strategy involves using constrained random stimulus along with functional coverage. This is mainly achieved through UVM testbenches found in `hvl/modules`, organized into a `test_suite` in the provided Makefile.
  - For more information on the Makefile, run `make info`.
- Directed tests and RVFI will also be utilized to verify individual modules and the entire processor design, respectively.

## Timing and Energy
- The current fetch stage design doesn't entail much logic; hence, a maximum frequency is not needed at this point.

## Roadmap
- Specific roles are outlined in `Participation`. While these modules and roles are flexible, the primary timeline is as follows:
  - Larry will predominantly handle CP1, focusing on the basic fetch stage.
  - Max will play a significant role in CP2, as it requires a functional backend.
  - Josh will have a more prominent role in CP3, focusing on the memory modules and cache hierarchy setup.

## Specific Issues
- Ensuring instructions of older/highest priority are issued first is crucial. Establishing a priority queue during the issue stage in the backend is necessary.
- Developing an effective branch predictor is essential to avoid the significant penalty of branch misprediction. This will likely involve a combination of BTB and various history/prediction structures.
- Addressing memory bottlenecks is imperative. Implementing a pipelined read-only i-cache will assist the fetch stage. Coupling this with prefetching will help reduce the number of stalls in the frontend.

# CP2 Progress Report

## Participation
- Max worked on a majority of the backend data structures and organization. 
- Larry helped complete the CDB writeback logic and integrate RVFI signals into the backend.
- Josh worked on a `magic frontend` to help test the backend in `top_tb.sv`.

## Functionality
- The added functionality for this checkpoint includes all the backend data structures need for ERR. This includes the RAT, Free List, RRF, Physical Register File, Reservation Station, and ROB. Proper rename, dispatch, and issue logic was developed and should carry over to future development. The execution stage was design to support pipelined execution units for future advanced multipliers or floating point units. A single CDB was implemented and proper arbitration and stall logic was designed. 

## Verification
- The backend was verified by using both a `magic queue` and `magic frontend`. The queue was used to manual check CDB commit signals and any misc logic. The frontend was hooked up to `cpu.sv` and allowed testing with RVFI and `run_top_tb`. All the given test programs were able to run to completion passing both RVFI and `spike`.

## Timing
- Running `synth` on the backend gives an fmax of `500 MHz` with total area `92820`.

## Roadmap
- For future development, the following tasks will need to be completed:
  - Handling all possible backend hazards
  - Integrating branch resolution and flush logic
  - Seperate load/store unit with address generation unit

# CP3 Progress Report

## Participation
- Max worked on a normal branch resolution and a simple load/store unit
- Larry helped integrate a bmem random testbench
- Josh worked on the icache and dcache as well as cachline adaptor + arbitration

## Functionality
- The added functionality for this checkpoint includes basically running `coremark.elf` on bmem/competition memory. We also got a head start on the `advanced features` which we have listed below. 

## Advanced Features
- Early Branch Resolution
- Pipelined Multiplier
- Synopsys Divider IP
- Branch Predictor
  - Branch Target Buffer (BTB)
  - Return Address Stack (RAS)
  - Two-bit Saturating Counter
- Caches
  - Pipelined Cache
  - Non-Blocking Cache
- Memory System
  - Two-wide Fetch
  - Load/Store Disambiguation
- SuperScalar
- C-Extension

## Verification
- The main verification was just running `make run_top_tb PROG=../testcode/coremark.elf` and `make spike ELF=bin/coremark.elf`

## Timing
- Running `synth` on the backend gives an fmax of `500 MHz` with total area `189620`.

## Roadmap
- For future development, the advanced features list should be `COMPLETED :)`