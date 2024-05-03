# Issue Stage
- 1 Large Reservation Stage
  - Flexibility, doesn't constrain workload
  - Reading/logic easier
- Seperate Instruction Queue.
  - Allows easier prioritization, for example branch unit for early branch resolution
  - Easier to do super scalar issue

# x0 Gaslight
- Map x0 to P0. Reads and writes from P0 are logically nullified.

# How to Handle Branch Flushes
- On flush, RAT must be reset to the current state of the RRF.
- On flush, Free List pointers should be reset to empty.
  - The Free List contains all physical register not in the RRF

# Functional Units
- Design arbiter for execution units
- Superscalar designs might need to stall for CDB. Use a queue 

# Common Data Bus
- Arbitration between functional units writeback
- Implement multiple data buses for superscalar

# Register File
- Number of physical registers should size to the number of in-flight instructions
- SRAM physical register file for reduced area

# PC Storage
- The ROB must know the PC of every inflight instruction. This information is used in the following situations:
  - Any instruction could cause an exception, in which the “exception pc” (epc) must be known.
  - Branch and jump instructions need to know their own PC for correct frontend prediction. 
  - Jump-register instructions must know both their own PC and the PC of the following instruction in the program to verify if the Front-end predicted the correct JR target.
- This information is incredibly expensive to store. Instead of passing PCs down the pipeline, branch and jump instructions access the ROB’s “PC File” during the Register-read stage for use in the Branch Unit. Two optimizations are used:
  - Only a single PC is stored per ROB row.
  - The PC File is stored in two banks, allowing a single read-port to read two consecutive entries simultaneously (for use with JR instructions).
- Alternatively, we can use a control buffer to store all in-flight branch data. This buffer might support 4-6 in-flight branches, which minimizes area compare to ROB-based designs. 

# Stall Cases
- Free List is Full
- ROB is Full
- Issue Queue(s) are Full

# Stall Edge Cases
- Dispatch CDB Forwarding/Snoop Logic + Stall Protection
- Prioritize new speculative state write for RAT
- RAT needs to be write-through with respect to the CDB updating valid bit of same RAT entry being read

# Flush Cases: Normal Branch Resolution
- RAT: Set RAT entries to RRF entries, set all entries as valid 
- Free List: Reset pointers to full
- RRF: Contains real architectural state, no need to touch flush
- ROB: Clear all entries
- RES: Clear all entries
- PR: Nothing needed
- Reset Multiplier: Set reset signal to multiplier
- Rename Stage Pipeline Register: Send Bubble
- Execute Stage Pipline Registers: Reset Valid and Ready Signals

# Control Buffer (COB)
- Similar to the ROB, the COB is implemented as a circular queue 
- In Dispatch, enqueue branch instructions to the control buffer
  - We must stall if the control buffer is full, just like the ROB
    - For early branch resolution, the control buffer index acts as the Branch Tag
  - The control buffer index is used to commit the correct branch information
- The control buffer holds all the necessary branch information
  - Target Address
  - Branch Taken/Not Taken
  - Branch Program Counter
  - Branch Tag
- Based on the average workload, branches are around 10-20%
  - The COB should range from either 4 to 8 entries (Power of 2 Recommended)

# Early Branch Resolution
- Each instruction in Decode/Rename is given a Branch Mask. Each bit in the mask corresponds to an inflight branch that the instruction is speculated under.
  - The Branch Mask holds all valid Branch Tag indices that the instruction is dependent on.
- Each branch in Decode/Rename is also allocated a Branch Tag, and all following instructions will have the corresponding bit in the Branch Mask set until the branch is resolved by the Branch Unit.
  - Only branch instructions are responsible for having a tag and broadcasting upon a misspeculation or correct speculation.

# Early Branch Resolution: Flush Conditions
- If the branch has been correctly speculated, then the Branch Units only action is to broadcast the corresponding branch tag to all inflight instructions. Each instruction can then clear the corresponding bit in its branch mask, and that branch tag can then be allocated to a new branch in the Decode stage.
- If a branch is misspeculated, the Branch Unit must redirect the PC to the correct target, flush the Front-end and Fetch Buffer, and broadcast the misspeculated branch tag so that all dependent, inflight instructions may be killed. The PC redirect signal goes out immediately, to decrease the misprediction penalty. However, the kill signal is delayed a cycle for critical path reasons.

# Bit Vector: Free List and Entry List
- The Free List is implemented as a bit-vector. A priority decoder can then be used to find the first free register. BOOM uses a cascading priority decoder to allocate multiple registers per cycle.
- The Free List also sets aside a new “Allocation List”, initialized to zero. As new physical registers are allocated, the Allocation List for each branch is updated to track all of the physical registers that have been allocated after the branch. If a misspeculation occurs, its Allocation List is added back to the Free List by OR’ing the branch’s Allocation List with the Free List. 

# Flush Cases: Early Branch Resolution
- ✅ RAT: Copy RAT for each branch in Dispatch, holds speculative state before the branch, restore respective branch's RAT upon mispredict.
- ✅ Free List: Copy Free List for each branch in Dispatch, holds speculative state before the branch, keep the same read pointer, update the write pointer and data when commiting instructions from ROB. Then restore the respecitive branch's Free List upon mispredict.
  - Simple (Possibly Naive) Solution: Store read pointer for each branch in Decode/Rename, restore respective branch's read pointer upon mispredict.
- ✅ Entry List: Copy Entry List for each branch in Dispatch, holds speculative state before the branch, keep the same read pointer, update the write pointer and data when commiting instructions from ROB. Then restore respective branch's Entry List upon mispredict.
- ✅ RRF: Contains real architectural state, no need to touch flush
- ✅ ROB: Only Clear mispeculated instructions, uses branch mask and branch tag
- ✅ RES: Only Clear mispeculated instructions, uses branch mask and branch tag
- ✅ PR: Nothing needed
- ✅ Reset Multiplier: Only Clear mispeculated instructions, uses branch mask and branch tag
- ✅ Rename Stage Pipeline Register: Only Clear mispeculated instructions, uses branch mask and branch tag
- ✅ Execute Stage Pipline Registers: Only Clear mispeculated instructions, uses branch mask and branch tag

# Early Branch Resolution Checkpoints
- ✅ Integrate Control Order Buffer (COB)
- ✅ Normal Flush w/ Branch Mask and Branch Tag Logic
- ✅ Copies of RAT and Free List Support

# Mask and Tag TODO:
- ✅ Add branch mask to the meta data information
- ✅ Add branch mask to rob entries and cob entries
- ✅ Add global branch bus interface
  - ✅ Broadcast ~ Branch
  - ✅ Clean ~ Correct Prediction
  - ✅ Kill ~ Misprediction
  - ✅ Tag ~ COB_index (Sent from Backend)
- ✅ Global Branch Mask logic in Dispatch
  - ✅ COB_index can be used as the branch tag
  - ✅ Synchronously update in dispatch stage
    - ✅ Branches don't need to have their own tag in their mask
    - ✅ Clear/kill global branch mask from branch bus interface
  - ✅ Instruction masks can be initalized to this global branch mask 
- ✅ Widespread branch mask clean/kill logic from branch bus interface
  - ✅ Broadcast signal will be driven by the frontend
  - ✅ ROB clean/kill Logic
    - ✅ Reset ROB write pointer to stored rob_index + 1 
  - ✅ COB clean/kill Logic
    - ✅ Reset COB write pointer to mispredicted branch tag/cob_index + 1 
  - ✅ Reservation Station clean/kill Logic
    - ✅ Store copy of Entry List in COB and Restore on branch kill
  - ✅ Store Station clean/kill Logic
  - ✅ Rename Stage Pipeline Register clean/kill Logic 
  - ✅ Dispatch Stage Pipeline Register clean/kill Logic 
  - ✅ Execute Stage Pipline Register clean/kill Logic
  - ✅ Multiplier clean/kill Logic
  - ✅ Memory Unit clean/kill Logic

# Lint Notes
- Changed Mthreshold to 65565 in lint
