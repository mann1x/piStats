# piStats
A Bash script that uses the Raspberry Pi's built-in `vcgencmd` utility to display a pleasing summary of system stats in one place.
 - CPU temperature
 - CPU, GPU (`core`, `h264`, `isp`, `v3d`), and SD card reader clock speeds
 - CPU and RAM (`sdram_c`, `sdram_i`, `sdram_p`) voltages
 - CPU and GPU memory split

As the Raspberry Pi is a low-power machine to begin with (especially its earlier iterations), the script has been optimized to use Bash's built-in functions wherever possible to prevent relatively costly externtal commands (e.g. `bc`) from skewing results.

## Usage
Running the script without any command-line arguments will display a simple overview of the temperature, CPU and GPU (`core` only) clock speeds, and CPU voltage—i.e. what most people are probably interested in.

The `-v` flag enables verbosity, which will show additional information (namely, the other GPU clock speeds, SD card reader clock speed, RAM voltages, and memory split).

The `-c` flag enters continuous mode, which will print the CPU temperature, clock speed, and voltage in columns every few seconds. This can be helpful in monitoring the performance of an overclock, for example. The delay, in seconds, may be changed through the `DELAY` variable at the top of the script.
