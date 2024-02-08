# piStats
A Bash script that uses the Raspberry Pi's built-in `vcgencmd` utility to display a pleasing summary of system stats in one place.
 - CPU temperature
 - CPU PWM Fan rpm (only Pi 5)
 - CPU, GPU (`core`, `h264`, `hevc`, `isp`, `v3d`), and SD card reader clock speeds
 - CPU and RAM (`mem_core`, `mem_io`, `mem_phy`) voltages
 - SOC (`uncached`) voltage (only for Pi 4 & Pi 5)
 - CPU and GPU memory split
 - Throttle status alerts
 - PMIC bit status (only for Pi 5)

As the Raspberry Pi is a low-power machine to begin with (especially its earlier iterations), the script has been optimized to use Bash's built-in functions wherever possible to prevent relatively costly external commands (e.g. `bc`) from skewing results.

The original script has been improved and expanded in features and compatibility.
It should work on all Raspberry Pi up to the actual latest, Pi 5.

## Usage
Running the script without any command-line arguments will display a simple overview of the temperature (Summary mode), CPU and GPU (`core` only) clock speeds, and CPU voltage—i.e. what most people are probably interested in.

- `-c`: continuous mode switch, which will print the CPU temperature, clock speed, and voltage in columns every few seconds. This can be helpful in monitoring the performance of an overclock, for example. The default delay, in seconds, may be changed through the `DELAY` variable at the top of the script or specified via the `-d` flag.

- `-d <NN>`: continuous mode, delay in seconds between updates (default 8 seconds).

- `-i <NN>`: continuous mode, delay in seconds between stats pooling (default 0.2 seconds).

- `-v`: enables verbosity, which will show additional information (namely, the other GPU clock speeds, SD card reader clock speed, RAM voltages, etc) in Summary mode and the headers.

- `-r`: toggle to show ARM Core voltage (vcore).

- `-o`: toggle to SOC voltage (vsoc).

- `-q`: toggle to kernel cpufreq driver core clocks (requested/reported).

- `-t`: toggle to SOC temperature.

- `-f`: toggle to Fan rpm speed.

- `-p`: toggle to show ARM Core power consumption (pcore).

- `-j`: toggle to show Ring Oscillator 1 in continuous mode.

- `-k`: toggle to show Ring Oscillator 2 in continuous mode.

- `-l`: toggle to show Ring Oscillator 3 in continuous mode.

- `-b`: toggle to show Ring Oscillators in Summary mode.

- `-s`: toggle to print column headers periodically in Continuous mode.

- `-a`: toggle to check throttled status periodically in Continuous mode.

- `-x`: suppress printing of all headers.

- `-u <NN>`: print only <NN> times the stats in Continuous mode.

- `-w`: check if you are running the latest release and exit.

- `-h`: prints a short summary of the command-line switches.

The default values and toggle states can be modified directly inside the script; 0 to disable, 1 to enable.

Some options are hidden and can be toggled only inside the script: 

- `PMIC`: toggle all queries to the PMIC.

- `PMIC_VOLTAGES`: toggle show PMIC voltage in Summary mode.

- `GPU_SPLIT`: toggle show GPU split in Summary mode.

- `IDELAYSMALL`: smaller delay between stats pooling for some stats in Summary mode, to avoid becoming too slow.

## Changelog

v1.16
   - Fixed bug with update release check

v1.15
   - Fixed bug with print column headers
   - Fixed bug with PWM Fan values without verbose mode
   - Fixed a bug with OV values and improved display
   - Added a switch to check for the latest release on Github

v1.14
   - Fixed over voltage values display
   - Added switch to suppress printing of all headers
   - Added switch to print column headers every screen periodically in continuous mode
   - Added switch to check throttled status every screen periodically in continuous mode
   - Fixed command line arguments handling
   - Added switch to cycle a number of times and exit

v1.13
   - Fixed missing VSOC in Continuous mode
   - Fixed formatting of Ring Oscillators in Continuous mode

v1.12
   - Fixed min and max clocks showing "N/A" when not available

v1.11
   - Added battery charging status
   - Made Summary layout more compact
   - Fixed temperature toggle in Summary mode
   - Added all PMIC voltages and total power consumption
   - Added PMIC temperature
   - Hidden PMIC power reset bits if off
   - Memory min and max clocks
   - Added PWM value and percentage for fan
   . Added Ring Oscillators section in Summary mode
   - Added toggles for each Ring Oscillator in Continuous mode

v1.1
   - First release with new features
   - Support for Pi5 and PMIC
