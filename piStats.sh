#!/bin/bash

PISTATS_REL=1.1

### Defauts

# Default delay between continuous mode checks (in seconds).
DELAY=8

# Inter delay between stats pooling
IDELAY=0.2

# Default toggles
CPUFREQ=0
VSOC=0
VCORE=1
VERBOSE=0
TEMP=1
FAN=1
POWER=1

# Hidden toggles
GPU_SPLIT=0
PMIC=1
PMIC_VOLTAGES=1

### Arguments
CONTINUOUS=0

while getopts d:i:cqorvtfph flag
do
    case "${flag}" in
        d) DELAY=${OPTARG};;
        i) IDELAY=${OPTARG};;
        c) CONTINUOUS=$((1-CONTINUOUS));;
        q) CPUFREQ=$((1-CPUFREQ));;
        o) VSOC=$((1-VSOC));;
        r) VCORE=$((1-VCORE));;
        v) VERBOSE=$((1-VERBOSE));;
        t) TEMP=$((1-TEMP));;
        f) FAN=$((1-FAN));;
        p) POWER=$((1-POWER));;
        h) echo -e "piStats v$PISTATS_REL\n"
           echo -e "Usage: piStats [OPTIONS]...\n"
           echo -e "Options:\n"
           echo -e "-c: continuous output mode, default is summary"
           echo -e "-d <NN>: CONTINUOUS mode, delay in seconds between updates (default 8 seconds)"
           echo -e "-i <NN>: delay in seconds between stats pooling (default 0.2 seconds)"
           echo -e "-v: toggle verbose mode for summary mode"
           echo -e "-r: toggle to show ARM Core voltage (vcore)"
           echo -e "-o: toggle to show SOC voltage (vsoc)"
           echo -e "-q: toggle to show kernel cpufreq driver core clocks (requested/reported)"
           echo -e "-t: toggle to show SOC temperature"
           echo -e "-f: toggle to show Fan rpm speed"
           echo -e "-p: toggle to show ARM Core power consumption (pcore)"
           echo -e "-h: will show this help screen"
           exit
           ;;
        :) echo -e "${RED}Option -${OPTARG} requires an argument.";;
            ?) echo -e "${RED}Invalid option -${OPTARG}.";;
    esac
done

### Color codes.
GRAY='\e[1;30m'
RED='\e[1;31m'
YELLOW='\e[1;33m'
PURPLE='\e[1;35m'
CYAN='\e[0;36m'
ORANGE='\e[0;33m'
PURPLE='\e[1;35m'
RESET='\e[0m'

### System Information

modelname_tree=$(tr -d '\0' < /proc/device-tree/model)
hostname=$(/usr/bin/uname -n)
kernrel=$(/usr/bin/uname -r)
kernver=$(/usr/bin/uname -v)
modelname=${modelname_tree:10:4}
fansys=/sys/devices/platform/cooling_fan/hwmon/*/fan1_input
fandev=/sys/devices/platform/cooling_fan/

# Detection of Pi 4 &  5
pi4=0
pi5=0
hevcblock=0
h264block=0

REGEX_MODEL='^Raspberry (.*)$'
REGEX_PI4='^(Pi 4).*$'
REGEX_PI5='^(Pi 5).*$'
if [[ $modelname_tree =~ $REGEX_MODEL ]]; then modelname=${BASH_REMATCH[1]}; fi
if [[ $modelname =~ $REGEX_PI4 ]]; then pi4=1; fi
if [[ $modelname =~ $REGEX_PI5 ]]; then pi5=1; fi

PCORE=0
if ((pi5)); then
    hevcblock=$((1-hevcblock))
    if ((POWER)) && ((PMIC)) then PCORE=1; fi
    if [ ! -d "$fandev" ]; then FAN=0; fi
fi

if ((pi4)); then
    h264block=$((1-h264block))
fi

# sudo check for CPUFREQ

if ((CPUFREQ)); then
    SUDOSTR=("")
    MYEUID=$(bash <<<'echo $EUID' 2>/dev/null)
    if [ "$MYEUID" != "0" ]; then
        suprompt=$(sudo -nv 2>&1)
        YESIMROOT=0
        if [ $? -eq 0 ]; then
            # Success exit code of sudo-command is 0
            YESIMROOT=1
            SUDOSTR=("sudo -n ")
        elif echo $suprompt | grep -q '^sudo:'; then
            echo -e "${RESET}${RED}Warning:${YELLOW} kernel clocks (cpufreq) disabled, you must run with sudo${RESET}"
        else
            echo -e "${RESET}${RED}Warning:${YELLOW} kernel clocks (cpufreq) disabled, you need sudo permissions${RESET}"
        fi
        if ! ((YESIMROOT)) then CPUFREQ=0; fi
    else
        YESIMROOT=1
    fi
fi

# Print out

echo -e "${GRAY}piStats v$PISTATS_REL: ${YELLOW}$hostname ${ORANGE}[$modelname]"
if ((VERBOSE)); then
    echo -e "${RESET}${GRAY}Rel: ${CYAN}$kernrel ${GRAY}Ver: ${CYAN}$kernver"
fi
echo -en "${RESET}"

### Main

# Throttled status
TSTATUS=$(vcgencmd get_throttled | cut -d "=" -f 2)
IFS=","
for TBITMAP in \
        00,"currently under-voltage" \
        01,"ARM frequency currently capped" \
        02,"currently throttled" \
        03,"soft temperature limit reached" \
        16,"under-voltage has occurred since last reboot" \
        17,"ARM frequency capping has occurred since last reboot" \
        18,"throttling has occurred since last reboot" \
        19,"soft temperature reached since last reboot"
do set -- $TBITMAP
    if [ $(($TSTATUS & 1 << $1)) -ne 0 ] ; then echo -e "${RED}Alert: ${YELLOW}$2"; fi
done
sleep $IDELAY

# Check command-line flag for continuous mode...
if ((CONTINUOUS)); then
    echo -e "${GRAY}entering continuous mode refresh every $DELAY seconds..."

    echo -en "${PURPLE}"
    if ((TEMP)); then echo -en "temp    "; fi
    echo -en "clock   "
    if ((CPUFREQ)); then echo -en "cpufreq      "; fi
    if ((FAN)); then echo -en "fan     "; fi
    if ((PCORE)); then echo -en "pcore     "; fi
    if ((VCORE)); then echo -en "vcore     "; fi
    if ((VSOC)); then echo -en "vsoc     "; fi
    echo -e "${RESET}"

    while true; do
        if ((CPUFREQ)); then
            scaling_freq=$(bash -c "${SUDOSTR}cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null")
            scaling_freq=$((${scaling_freq#*=} / 1000))
            cpuinfo_freq=$(bash -c "${SUDOSTR}cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_cur_freq 2>/dev/null")
            cpuinfo_freq=$((${cpuinfo_freq#*=} / 1000))
        fi

        if ((TEMP)); then
            temp=$(vcgencmd measure_temp); temp=${temp:5:4}
            sleep $IDELAY
        fi

        arm_clock=$(vcgencmd measure_clock arm); arm_clock=$((${arm_clock#*=} / 1000000))
        sleep $IDELAY

        if ((PCORE)); then
            pmic_corev=$(vcgencmd pmic_read_adc vdd_core_v);
            pmic_corea=$(vcgencmd pmic_read_adc vdd_core_a);
            REGEX_PCOREV='VDD_CORE_V volt.*=(.*)[AV].*'
            REGEX_PCOREA='VDD_CORE_A current.*=(.*)[AV].*'
            if [[ $pmic_corev =~ $REGEX_PCOREV ]]; then pcore_voltage=${BASH_REMATCH[1]}; fi
            if [[ $pmic_corea =~ $REGEX_PCOREA ]]; then pcore_current=${BASH_REMATCH[1]}; fi
            core_power=$(echo "$pcore_voltage $pcore_current" | awk '{printf "%.4f", $1*$2}')
        fi

        if ((VCORE)); then
            core_voltage=$(vcgencmd measure_volts core); core_voltage=${core_voltage:5:6};
            sleep $IDELAY
        fi

        if ((VSOC)); then core_uncached=$(vcgencmd measure_volts uncached); core_uncached=${core_uncached:5:6}; fi
        if ((VCORE)) || ((VSOC)); then sleep $IDELAY; fi

        if ((FAN)); then
            fanrpm=$(cat $fansys 2>/dev/null)
            sleep $IDELAY
        fi

        if ((TEMP)); then printf "%-7s " "$temp"; fi
        printf "%-7s " "$arm_clock"
        if ((CPUFREQ)); then printf "%-12s " "$scaling_freq/$cpuinfo_freq"; fi
        if ((FAN)); then printf "%-7s " "$fanrpm"; fi
        if ((PCORE)); then printf "%-9s " "$core_power"; fi
        if ((VCORE)); then printf "%-9s " "$core_voltage"; fi
        if ((VSOC)); then printf "%-9s " "$core_uncached"; fi
        echo -en "\n"

        sleep $DELAY
    done

# ...otherwise, print stats once.

else

    # Pi5 PMIC Reset bit
    if ((pi5)) && ((PMIC)); then pmic_reset=$(hexdump -s 0 -n 1 -e '1/1 "%08x" "\n"' < /proc/device-tree/chosen/power/power_reset); fi

    # Kernel scaling scheduler clocks
    if ((CPUFREQ)); then
        sleep $IDELAY
        scaling_freq=$(bash -c "${SUDOSTR}cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null")
        scaling_freq=$((${scaling_freq#*=} / 1000))
        cpuinfo_freq=$(bash -c "${SUDOSTR}cat /sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_cur_freq 2>/dev/null")
        cpuinfo_freq=$((${cpuinfo_freq#*=} / 1000))
        sleep $IDELAY
    fi

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
    arr_clocks=( 'arm' 'core' )
    if ((h264block)) then arr_clocks+=('h264'); fi
    if ((hevcblock)) then arr_clocks+=('hevc'); fi
    for SRC in "${arr_clocks[@]}"; do
        sleep $IDELAY
        clock=$(vcgencmd measure_clock $SRC)
        eval "$SRC"_clock=$((${clock#*=} / 1000000))
    done

    # Core voltage.
    sleep $IDELAY
    core_voltage=$(vcgencmd measure_volts core); core_voltage=${core_voltage:5:6}

    if ((pi5)) && ((FAN)); then
        # Fan rpm.
        sleep $IDELAY
        fanrpm=$(cat $fansys 2>/dev/null)
    fi

    # Check command-line flag for additional verbosity.
    if ((VERBOSE)); then
        # SOC voltage.
        if ((pi4)) || ((pi5)); then
           sleep $IDELAY
           soc_voltage=$(vcgencmd measure_volts uncached); soc_voltage=${soc_voltage:5:6}
        fi

        arr_gclocks=( 'isp' 'v3d' )
        if ((h264block)) then arr_gclocks+=('h264'); fi
        if ((hevcblock)) then arr_gclocks+=('hevc'); fi
        # Additional GPU clock speeds.
        for SRC in "${arr_gclocks[@]}"; do
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

        # Clocks min/max
        if ((hevcblock)); then
            hevc_clock_max=$(vcgencmd get_config hevc_freq); hevc_clock_max=${hevc_clock_max:10:4};
            hevc_clock_min=$(vcgencmd get_config hevc_freq_min); hevc_clock_min=${hevc_clock_min:14:4};
        fi
        if ((h264block)); then
            h264_clock_max=$(vcgencmd get_config h264_freq); h264_clock_max=${h264_clock_max:10:4};
            h264_clock_min=$(vcgencmd get_config h264_freq_min); h264_clock_min=${h264_clock_min:14:4};
        fi

        isp_clock_max=$(vcgencmd get_config isp_freq); isp_clock_max=${isp_clock_max:9:4};
        isp_clock_min=$(vcgencmd get_config isp_freq_min); isp_clock_min=${isp_clock_min:13:4};
        v3d_clock_max=$(vcgencmd get_config v3d_freq); v3d_clock_max=${v3d_clock_max:9:4};
        v3d_clock_min=$(vcgencmd get_config v3d_freq_min); v3d_clock_min=${v3d_clock_min:13:4};

        over_voltage=$(vcgencmd get_config over_voltage); over_voltage=${over_voltage:13:1};
        over_voltage_delta=$(vcgencmd get_config over_voltage_delta); over_voltage_delta=${over_voltage_delta:19:5};
        over_voltage_delta=$((${over_voltage_delta#*=} / 1000))
        over_voltage_min=$(vcgencmd get_config over_voltage_min); over_voltage_min=${over_voltage_min:17:1};
    fi

    arm_clock_max=$(vcgencmd get_config arm_freq); arm_clock_max=${arm_clock_max:9:4};
    arm_clock_min=$(vcgencmd get_config arm_freq_min); arm_clock_min=${arm_clock_min:13:4};
    core_clock_max=$(vcgencmd get_config core_freq); core_clock_max=${core_clock_max:10:4};
    core_clock_min=$(vcgencmd get_config core_freq_min); core_clock_min=${core_clock_min:14:4};

    # Final output.

    echo -e "\n${PURPLE}temp${RESET}"
    if ((TEMP)); then printf "%s C" "$temp"; fi
    if ((FAN)); then printf " (%s rpm)" "$fanrpm"; fi

    echo -en "\n"

    echo -e "\n${PURPLE}clocks                ${GRAY}min            max${RESET}"
    printf "${GRAY}cpu:${RESET}  %-10s      %-10s     %-10s\n" "$arm_clock MHz" "$arm_clock_min MHz" "$arm_clock_max MHz"
    printf "${GRAY}gpu:${RESET}  %-10s      %-10s     %-10s\n" "$core_clock MHz" "$core_clock_min MHz" "$core_clock_max MHz"

    if ((VERBOSE)); then
        if ((hevcblock)); then printf "${GRAY}hevc:${RESET} %-10s      %-10s     %-10s\n" "$hevc_clock MHz" "$hevc_clock_min MHz" "$hevc_clock_max MHz"; fi
        if ((h264block)); then printf "${GRAY}h264:${RESET} %-10s      %-10s     %-10s\n" "$h264_clock MHz" "$h264_clock_min MHz" "$h264_clock_max MHz"; fi

        printf "${GRAY}isp:${RESET}  %-10s      %-10s     %-10s\n" "$isp_clock MHz" "$isp_clock_min MHz" "$isp_clock_max MHz"
        printf "${GRAY}v3d:${RESET}  %-10s      %-10s     %-10s\n" "$v3d_clock MHz" "$v3d_clock_min MHz" "$v3d_clock_max MHz"
        printf "${GRAY}sd${RESET}    %-10s\n" "$sd_clock MHz"

        if ((CPUFREQ)); then
            echo -e "${GRAY}kern:${RESET} $scaling_freq/$cpuinfo_freq MHz"
        fi
    fi

    echo -e "\n${PURPLE}voltages${RESET}"
    if ((VCORE)); then printf "${GRAY}core:${RESET} %-11s " "$core_voltage V"; fi

    if ((VERBOSE)); then

        printf "${GRAY}mem (core - i/o - phy):${RESET} %-8s - %-8s - %-8s\n" "$sdram_c_voltage V" "$sdram_i_voltage V" "$sdram_p_voltage V"

        if ((pi4)) || ((pi5)); then printf "${GRAY}soc:${RESET}  %-11s\n" "$soc_voltage V"; fi

        if [ "$over_voltage_delta" != "0" ] || [ "$over_voltage" != "0" ] || [ "$over_voltage_min" != "0" ]; then
            echo -e "\n${PURPLE}over voltage${RESET}"
            printf "${GRAY}%-7s${RESET}  %-8s\n" "delta:" "$over_voltage_delta mV"
            printf "${GRAY}%-7s${RESET}  %-8s\n" "static:" "$over_voltage"
            printf "${GRAY}%-7s${RESET}  %-8s\n" "min:" "$over_voltage_min"
        fi

        if ( ((pi4)) || ((pi5)) ) && ((PMIC)); then

            printf "\n${PURPLE}pmic\n"

            if ((pi5)); then printf "${GRAY}power_reset:${RESET} %-8s\n" "$pmic_reset"; fi

            if ( ((pi4)) || ((pi5)) ) && ((PMIC_VOLTAGES)); then
                #RTC Battery

                rtc_show=0;
                    pmic_input=$(vcgencmd pmic_read_adc batt_v);
                    REGEX_PMIC='BATT_V volt.*=([0-9.]{4}).*[AV].*'
                    if [[ $pmic_input =~ $REGEX_PMIC ]]; then rtc_voltage=${BASH_REMATCH[1]}; rtc_show=1; fi
                if ((rtc_show)); then
                    printf "${GRAY}rtc battery:${RESET} "
                    if [[ $rtc_voltage < 2.60 ]]; then
                        if [[ $rtc_voltage < 2.50 ]]; then
                            echo -ne "${RED}"     # Depleted battery
                        else
                            echo -ne "${YELLOW}"  # Low Battery
                        fi
                    fi

                    printf "%-12s${RESET}\n" "$rtc_voltage V"
                fi;

                #External 5V power supply

                ext5v_show=0;
                    pmic_input=$(vcgencmd pmic_read_adc ext5v_v);
                    REGEX_PMIC='EXT5V_V volt.*=([0-9.]{4}).*[AV].*'
                    if [[ $pmic_input =~ $REGEX_PMIC ]]; then ext5v_voltage=${BASH_REMATCH[1]}; ext5v_show=1; fi
                if ((ext5v_show)); then
                    printf "${GRAY}ext 5V:${RESET}    "
                    if [[ $ext5v_voltage < 4.90 ]]; then
                        if [[ $ext5v_voltage < 4.80 ]]; then
                            echo -ne "${RED}"     # Very Low
                        else
                            echo -ne "${YELLOW}"  # Low
                        fi
                    fi

                    printf "  %-11s${RESET}\n" "$ext5v_voltage V"
                fi

                # PMIC Voltages

                arr_pdata=( 'VDD_CORE' 'DDR_VDDQ' 'DDR_VDD2' 'DDR_VDDQ' 'HDMI' )

                for SRC in "${arr_pdata[@]}"; do
                    label=$(echo $SRC | tr '[:upper:]' '[:lower:]')
                    volt=$(vcgencmd pmic_read_adc "${label}_v")
                    current=$(vcgencmd pmic_read_adc "${label}_a")
                    REGEX_VOLT="${SRC}_V volt.*=(.*)[AV].*"
                    REGEX_CURRENT="${SRC}_A current.*=(.*)[AV].*"
                    #echo "${label}_v volt=$volt RE=$REGEX_VOLT"
                    if [[ $volt =~ $REGEX_VOLT ]]; then pmic_voltage=${BASH_REMATCH[1]}; fi
                    if [[ $current =~ $REGEX_CURRENT ]]; then pmic_current=${BASH_REMATCH[1]}; fi
                    pmic_power=$(echo "$pmic_voltage $pmic_current" | awk '{printf "%.4f", $1*$2}')
                    printf "${GRAY}%-10s${RESET}   %-11s %-11s (%-11s)\n" "$label:" "${pmic_voltage:0:6} V" "${pmic_current:0:6} A" "${pmic_power:0:6} Watt"
                done
                fi

        fi

        if ((GPU_SPLIT)); then
            echo -e "\n${PURPLE}memory split gpu (obsolete)${RESET}"
            echo -e "${GRAY}cpu:${RESET} $arm_mem MB"
            echo -e "${GRAY}gpu:${RESET} $gpu_mem MB"
        fi

    else
        echo -ne "\n";
    fi

    echo -ne "\n";

fi