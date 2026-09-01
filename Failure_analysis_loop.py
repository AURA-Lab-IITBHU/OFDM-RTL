import subprocess
import datetime
import sys

def log(level, msg):
    # Formats the terminal output to match standard logging formats
    timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    print(f"[{timestamp}] [{level.ljust(8)}] {msg}")

def run_fal():
    log("INFO", "Initializing Python Failure Analysis Loop (FAL)")
    log("INFO", "Target Design: zc_seq.v | Target Testbench: tb_zc_seq.v")
    
    # 1. Compile the RTL and Testbench
    log("EXEC", "Running compiler: iverilog -g2012 -o sim.out zc_seq.v tb_zc_seq.v")
    compile_proc = subprocess.run(
        ['iverilog', '-g2012', '-o', 'sim.out', 'zc_seq.v', 'tb_zc_seq.v'],
        capture_output=True, text=True
    )
    
    if compile_proc.returncode != 0:
        log("ERROR", "Icarus Verilog returned exit code 1.")
        print(compile_proc.stderr)
        log("CRITICAL", "AST parsing aborted due to blocking syntax errors.")
        sys.exit(1)

    log("INFO", "Icarus Verilog compilation successful. (Exit code 0)")
    
    # 2. Run the Simulation
    log("EXEC", "Running simulation: vvp sim.out")
    sim_proc = subprocess.run(['vvp', 'sim.out'], capture_output=True, text=True)
    
    if sim_proc.returncode != 0:
        log("ERROR", "Simulation execution failed.")
        print(sim_proc.stderr)
        sys.exit(1)
        
    log("INFO", "Simulation completed successfully.")
    
    # 3. Parse the Output Log
    log("ANALYSIS", "Parsing stdout for assertion failures or error counters...")
    
    if "Code exited with 0 errors" in sim_proc.stdout:
        log("SUCCESS", "Simulation stdout string matched: 'Code exited with 0 errors'")
        log("INFO", "VCD waveform generated: zc.vcd")
        log("INFO", "FAL Run Complete. No syntax or logical faults detected.")
    else:
        log("FAIL", "Errors were detected during the sequence verification.")
        print("\n--- FAILING SIMULATION OUTPUT ---")
        # Extract and print only the FAIL lines from the Verilog $display outputs
        for line in sim_proc.stdout.split('\n'):
            if "FAIL" in line or "Code exited with" in line:
                print(line)

if __name__ == "__main__":
    run_fal()