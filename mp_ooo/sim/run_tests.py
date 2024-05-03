import subprocess

benchmark_paths = [
    "../testcode/coremarks/coremark_im.elf",
    "../testcode/competition_suite/compression.elf",
    "../testcode/competition_suite/dna.elf",
    "../testcode/competition_suite/fft.elf",
    "../testcode/competition_suite/graph.elf",
    "../testcode/competition_suite/mergesort.elf",
    "../testcode/competition_suite/physics_d.elf",
    "../testcode/competition_suite/rsa_d.elf",
    "../testcode/competition_suite/sudoku.elf"
]

result_log_path = "sim/results.log"
dump_log_path = "sim/results_dump.log"

def run_tests():
    with open(dump_log_path, 'w') as dumpfile:
        with open(result_log_path, 'w') as resultfile:
            for benchmark in benchmark_paths:
                # Run the command and capture its output
                command = f"make run_top_tb PROG={benchmark}"
                output = subprocess.check_output(command, shell=True, text=True)

                # Dump Output to Logfile
                dumpfile.write(output)

                # Search for the line containing the desired string
                ipc_line = ""
                lines = output.split('\n')
                for line in lines:
                    if "IPC:" in line:
                        # Write the line to the output file
                        ipc_line = line
                        resultfile.write(f"{benchmark}\n")
                        resultfile.write(f"{line}\n")
                        break

                print(f"Completed {benchmark}")
                print(f"{ipc_line}")

if __name__ == "__main__":
    run_tests()
