**Implementation of Text Encryption on FPGA using Pipelined AES-128 Architecture in SystemVerilog**

An end-to-end hardware implementation of a ten-stage fully pipelined AES-128 encryption core designed in SystemVerilog and deployed on the Intel DE10-Lite FPGA (MAX10 10M50DAF484C7G). This repository includes an iterative reference architecture for performance benchmarking, Python pre-processing scripts for PKCS-7 padding, and hardware verification drivers for on-board display output.
 Key Features

* Fully Pipelined Core: 10 dedicated round stages separated by pipeline registers, delivering 1 block (128-bit) per clock cycle after initial fill latency.


* High Throughput: Achieves 6.4 Gbps throughput at 50 MHz (11x performance increase over iterative baseline).


* **Combinational Key Expansion**: Instantaneous round-key generation for all 11 subkeys.


* **In-Order Tracking**: Propagates valid flags and 32-bit block-index tags through parallel registers to maintain block ordering.


* **Host Pre-Processor**: Python tool converts arbitrary text files into UTF-8, applies PKCS-7 padding, and formats them into Intel Hex ROM files for BRAM loading.


* **On-Chip Hardware Verification**: Direct output inspection via six on-board 7-segment displays.



---

## Performance & Resource Summary

Synthesized using **Intel Quartus Prime Lite Edition 24.1** for the **Intel MAX10 FPGA (10M50DAF484C7G)** at 50 MHz:

| Metric | Iterative Baseline | Pipelined Architecture | Ratio / Scale |
| --- | --- | --- | --- |
| **Logic Elements (LEs)** | 3,989 | 35,494 | **8.89x** |
| **Registers (Flip-Flops)** | 262 | 1,725 | **6.58x** |
| **Maximum Frequency ($F_{max}$)** | 92.07 MHz | 98.71 MHz | **1.07x** |
| **Throughput (@ 50 MHz)** | 581 Mbps

 | **6.4 Gbps**<br> | **11.01x**<br> |
| **Core Dynamic Power** | 6.05 mW | 103.53 mW | **17.11x** |
| **Total Thermal Dissipation** | 131.23 mW | 204.30 mW | **1.55x** |

---

## Directory Structure

```text
├── rtl/
│   ├── aes_sbox.sv            # 256-entry forward substitution lookup table
│   ├── aes_subbytes.sv        # 16-byte parallel S-Box substitution engine
│   ├── aes_shiftrows.sv       # Row cyclic permutation module
│   ├── aes_mixcolumns.sv      # GF(2^8) Galois field matrix multiplication
│   ├── aes_addroundkey.sv     # Bitwise 128-bit XOR stage
│   ├── aes_key_expansion.sv   # Combinational key expansion generator
│   ├── aes_pipeline_stage.sv  # Registered single pipeline round
│   ├── aes_pipeline_top.sv    # Top-level 10-stage chained pipeline core
│   └── de10_aes_top.sv        # FPGA top-level wrapper with BRAM & 7-seg logic
├── tb/
│   ├── tb_aes128_encrypt.sv   # Iterative testbench (NIST vectors)
│   └── tb_aes128_pipeline.sv  # Pipelined testbench with streaming block vectors
├── tools/
│   └── gen_plaintext_hex.py   # Python script for PKCS-7 padding & hex formatting
├── constraints/
│   └── de10_lite.sdc          # 50 MHz timing constraints file
└── README.md

```

---

## Setup & Execution Guide

### 1. Host-Side Text Pre-Processing

Prepare an input text file and generate the BRAM initialization file:

```bash
python tools/gen_plaintext_hex.py input.txt plaintext.hex

```

*Note: Update the `BLOCK_COUNT` parameter in `rtl/de10_aes_top.sv` with the value reported by the Python script.*

### 2. Functional Simulation (ModelSim)

Compile and run the testbench against NIST FIPS-197 Known Answer Test (KAT) vectors:

```bash
vlib work
vlog -sv rtl/*.sv tb/tb_aes128_pipeline.sv
vsim -c tb_aes128_pipeline -do "run -all; quit"

```

### 3. FPGA Synthesis & Programming

1. Launch **Intel Quartus Prime Lite Edition**.


2. Open the project and select target device **`10M50DAF484C7G`**.


3. Run **Full Compilation** (`Analysis & Synthesis` $\rightarrow$ `Fitter` $\rightarrow$ `Assembler` $\rightarrow$ `Timing Analyzer`).
4. Connect the Intel DE10-Lite via **USB-Blaster II**.
5. Open **Programmer**, select the generated `.sof` file, and click **Start**.

### 4. Hardware Verification

* Press **`KEY[0]`** on the board to reset the core.
* Press **`KEY[1]`** to trigger sequential pipeline block loading.
* Observe real-time encrypted ciphertext chunks displayed on the six on-board 7-segment displays.




