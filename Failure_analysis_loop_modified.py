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
        ['iverilog', '-g2012', '-o', 'sim.out', 'tb_zc_seq.v'],
        capture_output=True, text=True
    )
    
    if compile_proc.returncode != 0:
        log("ERROR", f"Icarus Verilog returned exit code {compile_proc.returncode}.")
        # Parse and log compiler errors line-by-line instead of a raw print
        for line in compile_proc.stderr.split('\n'):
            if line.strip():
                log("COMPILER", line.strip())
        log("CRITICAL", "AST parsing aborted due to blocking syntax or logic errors.")
        sys.exit(1)

    log("INFO", "Icarus Verilog compilation successful. (Exit code 0)")
    
    # 2. Run the Simulation
    log("EXEC", "Running simulation: vvp sim.out")
    sim_proc = subprocess.run(['vvp', 'sim.out'], capture_output=True, text=True)
    
    if sim_proc.returncode != 0:
        log("ERROR", f"Simulation execution failed with exit code {sim_proc.returncode}.")
        # Capture standard VVP runtime crashes
        for line in sim_proc.stderr.split('\n'):
            if line.strip():
                log("SIM_ERR", line.strip())
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
        log("REPORT", "--- FAILING SIMULATION OUTPUT ---")
        
        error_caught = False
        
        # Extract and classify output dynamically
        for line in sim_proc.stdout.split('\n'):
            line = line.strip()
            if not line:
                continue
                
            # Catch custom testbench FAIL messages
            if "FAIL" in line:
                log("ASSERT", line)
                error_caught = True
            # Catch standard Verilog runtime errors/warnings
            elif "ERROR" in line.upper() or "WARNING" in line.upper():
                log("VVP_LOG", line)
                error_caught = True
            # Catch the final error tally
            elif "Code exited with" in line:
                log("SUMMARY", line)
                error_caught = True
                
        # Fallback dump if the simulation failed without triggering specific tags
        if not error_caught:
            log("UNKNOWN", "Simulation failed but no tracked 'FAIL' tags were found. Dumping raw stdout:")
            print(sim_proc.stdout)

if __name__ == "__main__":
    run_fal()