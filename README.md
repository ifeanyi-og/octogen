# octogen

BME070 BME Capstone Final Working Design

Authors: Arion Frakulli, Ifeanyi Oguamanam
Contributors: Harini Vishwanathan, Belinda Serafine

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

After evry checkout from github, run the following script in your powershell as administrator to perform autobuilds and generate Vivado project files

```
vivado -mode batch -source .\scripts\create_project.tcl
```

This will build the project around the HDL source files and block diagrams tracked in this git repository.