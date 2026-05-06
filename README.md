# OCT-Gen: FPGA-Accelerated OCT Image Processing

BME070 BME Capstone Design

__Authors:__ Arion Frakulli, Ifeanyi Oguamanam 

__Project Contributors:__ Harini Vishwanathan, Belinda Serafine

This repository hosts the HDL used to design an FPGA-accelerated OCT pipeline, capable of producing 3D renderings from the output of a Fourier-based interferometer signal. This implementation attempts to maintain the methods and proceses defined in [ _Real-time processing for Fourier domain optical coherence tomography using a field programmable gate array_, 2008](https://pubs.aip.org/aip/rsi/article-abstract/79/11/114301/351260/Real-time-processing-for-Fourier-domain-optical) with optimizations when necessary.

Key features of this project include the modular factory-line setup, determinstic DSP operations, in-line calibration, and fixed pipeline latency.

### Requirements
1. Kintex 7 development baord hosting the xc7k325tffg676-2 chip
2. AMD Vivado Enterprise License

### Setup

1. Cloning the repository

Clone the repository in your Git extension of choice, or run the following script in your terminal
```
git clone git@github.com:ifeanyi-og/octogen.git
```

2. Autobuild Project

Run the following script to perform autobuilds and generate Vivado project files and locate memory block initializations.

```
vivado -mode batch -source .\scripts\create_project.tcl
```

This will build the project around the HDL source files and initializations tracked in this git repository.

3. Project Structure

```
octogen_top.v
|-- eth_io_top.v
|   |-- udp_complete.v
|   |-- (files from Alex Forencich's Verilog UDP stack)
|
|-- udp_processing_top.v
|   |-- packet_rx_handler.v
|   |-- cal_loader.v
|   |-- pingpong_buffer.v
|   |-- packet_tx_handler.v
|
|-- disp_comp.v
    |-- bg_sub.vhd
    |-- k_lin.vhd
    |-- disp_comp.vhd
    |-- fft_wrapper.vhd
    |-- top_select.v
    |-- mag_calc.vhd
    |-- log_compress_map.vhd
```

Find additional documentation on each module 
Find Alex Forencich's UDP stack [here](https://github.com/alexforencich/verilog-ethernet)

### Motivation and Results
![motivation](/docs/motivation_poster.png)


