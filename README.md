# MicroCore — Miniature CPU Emulator

## Overview

MicroCore is a 32-bit assembly language project that simulates a simple computer system inside a console-based application.

The project demonstrates how a basic CPU operates through the **Fetch–Decode–Execute cycle**. It implements a miniature virtual processor with its own registers, program counter, instruction register, flags, and memory.

Users will be able to enter their own assembly-like instructions, load them into virtual memory, and execute them either one instruction at a time or continuously.

The emulator is developed using **32-bit x86 MASM assembly language** and the **Irvine32 library**.

## Project Objectives

The main objectives of MicroCore are to demonstrate:

- How a CPU fetches, decodes, and executes instructions.
- How registers store temporary values during execution.
- How program memory and data memory work.
- How instructions are represented using binary/numeric encoding.
- How arithmetic, data movement, and branching instructions operate.
- How the Program Counter controls program execution.
- How different components of a computer system communicate.

## System Architecture

MicroCore is divided into three main modules, with a shared include file.

| File | Responsibility |
|---|---|
| `Main.asm` | Program entry point, user input, program loading, menu, and overall control |
| `CPU.asm` | Virtual CPU, registers, instruction decoding, and execution |
| `Memory.asm` | Program memory and data memory management |
| `Dashboard.asm` | Displays CPU registers, memory contents, and emulator status |
| `MicroCore.inc` | Shared constants, opcode definitions, and procedure prototypes |

Each module has a separate responsibility. This makes the project easier to develop, test, and integrate.

### 1. Main.asm — Program Controller

Main.asm coordinates the entire emulator.

Its responsibilities include:

- Initializing the CPU and memory.
- Accepting a program from the user.
- Parsing the user's instructions.
- Converting instructions into encoded DWORD values.
- Loading the encoded program into ProgramMemory.
- Providing the main menu.
- Handling Step, Run, and Reset operations.
- Calling the appropriate procedures from other modules.

Main.asm acts as the connection between the user and the virtual computer.

### 2. CPU.asm — Virtual Processor

CPU.asm implements the behavior of the miniature CPU.

The virtual CPU contains:

| Register | Purpose |
|---|---|
| R0–R3 | Four general-purpose registers |
| PC | Program Counter — address of the next instruction |
| IR | Instruction Register — holds the fetched instruction |
| CPUFlags | Stores CPU status flags, including the Zero Flag |
| CPUHalted | Indicates whether execution has stopped |

Its main responsibilities include:

- Fetching instructions from ProgramMemory.
- Decoding the instruction's opcode and operands.
- Executing the requested operation.
- Updating registers and flags.
- Updating the Program Counter.
- Handling conditional and unconditional jumps.
- Detecting invalid instructions and execution errors.

The CPU implements the Fetch–Decode–Execute cycle.

### 3. Memory.asm — Memory Management

Memory.asm manages the virtual computer's storage.

It contains two separate memory arrays:

**ProgramMemory**

Stores the encoded instructions that the CPU executes.

**DataMemory**

Stores values that instructions read and modify during execution.

Both arrays contain 64 DWORD entries.

Each DWORD occupies 4 bytes, giving each memory array a total capacity of 256 bytes.

Memory addresses are indexed from 0 to 63.

Main procedures:

| Procedure | Purpose |
|---|---|
| `InitializeMemory` | Clears both memory arrays |
| `ValidateAddress` | Checks whether an address is within the valid range |
| `ReadDataMemory` | Reads a value from DataMemory |
| `WriteDataMemory` | Writes a value into DataMemory |
| `ReadProgramMemory` | Retrieves an encoded instruction |
| `WriteProgramMemory` | Stores an encoded instruction |
| `LoadProgram` | Copies an entire encoded program into ProgramMemory |

Memory.asm only manages storage. It does not interpret or execute instructions.

### 4. Dashboard.asm — User Interface

Dashboard.asm provides the console-based interface.

Its responsibilities include:

- Displaying the main dashboard.
- Showing the contents of CPU registers.
- Displaying memory addresses and their values.
- Showing loaded program instructions.
- Displaying execution status.
- Obtaining the user's menu selection.

The dashboard displays information owned by the CPU and Memory modules. It does not perform instruction execution itself.

### 5. MicroCore.inc — Shared Definitions

MicroCore.inc provides definitions shared by the different assembly modules.

It contains:

- Memory size constants.
- Instruction opcode constants.
- Register and flag definitions, where shared.
- Procedure prototypes.

This ensures that all modules use consistent names, constants, and procedure interfaces.

Actual memory arrays, registers, and procedure implementations are defined in their respective `.asm` files.

---

## Memory Design

MicroCore uses two separate memory arrays:

| Property | ProgramMemory | DataMemory |
|---|---|---|
| Capacity | 64 DWORDs | 64 DWORDs |
| Entry size | 4 bytes | 4 bytes |
| Address range | 0–63 | 0–63 |
| Purpose | Stores instructions | Stores program data |

ProgramMemory and DataMemory use separate address spaces.

For example, the instruction:

`LOAD R0, 10`

reads the value stored at DataMemory address 10 and places it into R0.

The instruction:

`STORE R0, 10`

writes the value currently held in R0 into DataMemory address 10.

The CPU retrieves instructions from ProgramMemory using the Program Counter.

## Instruction Set

The planned instruction set contains 13 instructions.

| Instruction | Purpose |
|---|---|
| `LOADI RD, immediate` | Loads a constant value into a register |
| `MOV RD, RS` | Copies one register's value into another |
| `ADD RD, RS` | Adds two register values |
| `SUB RD, RS` | Subtracts one register value from another |
| `MUL RD, RS` | Multiplies two register values |
| `DIV RD, RS` | Divides one register value by another |
| `LOAD RD, address` | Reads from data memory into a register |
| `STORE RS, address` | Writes a register value into data memory |
| `CMP RD, RS` | Compares two register values |
| `JMP address` | Unconditionally jumps to an instruction address |
| `JZ address` | Jumps if the Zero Flag is set |
| `JNZ address` | Jumps if the Zero Flag is not set |
| `HALT` | Stops program execution |

`RD` and `RS` represent destination and source registers, respectively.

The exact behavior of arithmetic flags and division will follow the CPU module's implementation.

## Instruction Encoding

The emulator does not directly execute the textual instructions entered by the user.

Instead, the parser converts each instruction into a 32-bit encoded DWORD.

The planned instruction format is:

| Bits | Field | Size |
|---|---|---|
| 31–24 | Opcode | 8 bits |
| 23–20 | Destination register | 4 bits |
| 19–16 | Source register | 4 bits |
| 15–0 | Immediate value or address | 16 bits |

For example, the parser identifies the instruction name, determines its opcode, extracts its register operands, and converts its immediate value or address into a numeric representation.

The resulting DWORD is stored in ProgramMemory.

The CPU then fetches and decodes that DWORD to determine what operation to execute.

## Fetch–Decode–Execute Cycle

The CPU operates using the following sequence:

**1. Fetch**

The CPU uses the Program Counter (PC) to retrieve an encoded instruction from ProgramMemory.

The instruction is placed into the Instruction Register (IR).

**2. Decode**

The CPU extracts the opcode, register fields, and operand from IR.

It determines which instruction needs to be executed.

**3. Execute**

The CPU performs the requested operation.

Depending on the instruction, it may:

- Modify a register.
- Read or write DataMemory.
- Update CPU flags.
- Change the Program Counter.
- Stop execution.

The cycle repeats until the CPU executes HALT or encounters an execution error.

## Example Program

A simple example program:

```asm
LOADI R0, 10
LOADI R1, 20
ADD R0, R1
STORE R0, 10
HALT
```

Expected operations:

1. R0 receives 10.
2. R1 receives 20.
3. R0 becomes 30.
4. The value 30 is stored at DataMemory address 10.
5. The CPU halts.

Expected final state:

| Component | Value |
|---|---|
| R0 | 30 |
| R1 | 20 |
| DataMemory[10] | 30 |
| CPUHalted | 1 |

## Program Execution Modes

The planned interface supports:

- **Step:** Executes exactly one virtual instruction.
- **Run:** Continues executing instructions until HALT or an error.
- **Reset:** Resets the CPU and memory to their initial state.

## Project Structure

```text
MicroCore/
│
├── .gitignore
├── MicroCore.sln
│
└── MicroCore/
    ├── Main.asm
    ├── CPU.asm
    ├── Memory.asm
    ├── Dashboard.asm
    ├── MicroCore.inc
    ├── MicroCore.vcxproj
    └── MicroCore.vcxproj.filters
```

## Technologies

- 32-bit x86 Assembly Language
- Microsoft Macro Assembler (MASM)
- Irvine32 Assembly Library
- Microsoft Visual Studio

The project is designed for a 32-bit (x86) build configuration.

## Development Status

The project is being developed in three modules:

- **CPU Module:** Implements the virtual processor and instruction execution.
- **Memory Module:** Implements program and data memory management.
- **Dashboard and Main Module:** Implements user interaction, instruction parsing, and integration.

The memory initialization and memory management procedures are being implemented as part of the Memory module. CPU execution and the complete user interface are separate development tasks.

## Limitations and Scope

- The emulator uses a fixed capacity of 64 program instructions and 64 data entries.
- Each memory entry is a 32-bit DWORD.
- The virtual CPU has four general-purpose registers.
- The instruction set is intentionally limited to demonstrate fundamental CPU operations.
- The project operates in memory and does not require external program files or services.
- The emulator simulates a CPU; it does not execute native x86 instructions supplied by the user.

## Purpose of the Project

MicroCore is an educational project designed to demonstrate fundamental computer organization and architecture concepts through a working assembly-language emulator.

By implementing the CPU, memory, instruction set, and execution cycle, the project provides a practical understanding of how a simplified computer system operates internally.
