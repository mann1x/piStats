#!/bin/bash
# Delay between continuous mode checks (in seconds).
DELAY=4

# In case you want to permanently enable verbose OR continuous mode:
# set -- "-v"
# set -- "-c"

# Color codes.
GRAY='\e[1;30m'
RED='\e[1;31m'
YELLOW='\e[1;33m'
PURPLE='\e[1;35m'
RESET='\e[0m'

# Check command-line flag for continuous mode...
if [ "$1" == '-c' ]; then
    echo -e "${GRAY}entering continuous mode..."
    sleep 0.3
    echo -e "${PURPLE}temp    clock   volt${RESET}"
    while true; do
        temp=$(vcgencmd measure_temp); temp=${temp:5:4}
	arm_clock=$(vcgencmd measure_clock arm); arm_clock=$((${arm_clock#*=} / 1000000))
	core_voltage=$(vcgencmd measure_volts core); core_voltage=${core_voltage:5:6}
        printf "%-7s %-7s %s\n" "$temp" "$arm_clock" "$core_voltage"
        sleep $DELAY
    done
# ...otherwise, print stats once.
else
    # CPU temperature.
    temp=$(vcgencmd measure_temp); temp=${temp:5:4}
    # Different colors for high temperatures to alert user.
    if [[ 70 < $temp ]]; then
        if [[ $temp > 80 ]]; then
            temp="${RED}$temp"     # 80+ C
        else
            temp="${YELLOW}$temp"  # 70-80 C
        fi
    fi

    # Clock speeds.
    for SRC in arm core; do
        clock=$(vcgencmd measure_clock $SRC)
        eval "$SRC"_clock=$((${clock#*=} / 1000000))
    done
    # Check if the current CPU clock speed matches its maximum (i.e. full load) to alert user.
    # Disabled for performance reasons: can spike voltage/clock speed and skew printed stats.
    #if [ "$arm_clock" == "$(($(sudo cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq) / 1000))" ]; then
    #     MAX="${GRAY}(max)"
    #fi

    # Core voltage.
    core_voltage=$(vcgencmd measure_volts core); core_voltage=${core_voltage:5:6}

    # Check command-line flag for additional verbosity.
    if [ "$1" == '-v' ]; then
        # Additional GPU clock speeds.
        for SRC in h264 isp v3d; do
            clock=$(vcgencmd measure_clock $SRC)
            eval "$SRC"_clock=$((${clock#*=} / 1000000))
        done

        # Additional SDRAM voltages.
        for SRC in sdram_c sdram_i sdram_p; do
            voltage=$(vcgencmd measure_volts $SRC)
            eval "$SRC"_voltage=${voltage:5:6}
        done

        # SD card clock speed.
        sd_clock=$(($(sudo awk 'NR==2 { printf $3 }' /sys/kernel/debug/mmc0/ios) / 1000000))

        # Shared memory split between the CPU and GPU (adds to 1G).
        for SRC in arm gpu; do
            mem=$(vcgencmd get_mem $SRC)
            eval "$SRC"_mem=${mem//[!0-9]/}
        done
    fi

# Final output.
echo -e "${PURPLE}temp${RESET}
$temp C

${PURPLE}clocks
${GRAY}cpu:${RESET}  $arm_clock MHz $MAX
${GRAY}gpu:${RESET}  $core_clock MHz"

if [ "$1" == '-v' ]; then
echo -e "${GRAY}h264:${RESET} $h264_clock MHz
${GRAY}isp:${RESET}  $isp_clock MHz
${GRAY}v3d:${RESET}  $v3d_clock MHz
${GRAY}sd:${RESET}   $sd_clock MHz"
fi

echo -e "
${PURPLE}voltage
${GRAY}core:${RESET}    $core_voltage V"

if [ "$1" == '-v' ]; then
echo -e "${GRAY}sdram_c:${RESET} $sdram_c_voltage V
${GRAY}sdram_i:${RESET} $sdram_i_voltage V
${GRAY}sdram_p:${RESET} $sdram_p_voltage V

${PURPLE}memory split
${GRAY}cpu:${RESET} $arm_mem MB
${GRAY}gpu:${RESET} $gpu_mem MB"
fi

fi
