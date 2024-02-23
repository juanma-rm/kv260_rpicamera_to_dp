Alternative 1 (make)
    - Configure "Makefile" file to set up the general test configuration
    - Run "make" from terminal
    - Run "make clean" to clean generated files

Alternative 2 (cocotb-test)
    - Configure "test_*" function located at this file to configure the general test configuration
    - Run "SIM=questa pytest -o log_cli=True" from terminal
    - Run "cocotb-clean -r" to clean generated files