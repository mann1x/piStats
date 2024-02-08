#!/bin/bash

PISTATS_REL=1.15

### Defauts

# Default delay between continuous mode checks (in seconds).
DELAY=8

# Inter delay between stats pooling
IDELAY=0.2
IDELAYSMALL=0.1

# Default toggles
CPUFREQ=0
VSOC=0
VCORE=1
VERBOSE=0
TEMP=1
FAN=1
POWER=1
RING_OSC=1
ROSC1=0
ROSC2=0
ROSC3=0

# Hidden toggles
GPU_SPLIT=0
PMIC=1
PMIC_VOLTAGES=1
THROTTLED_CHECK=0
PRINT_HEADERS=1
PRINT_CHEADERS=0

### Arguments
CONTINUOUS=0
PRINT_COUNT=0
UPDATE_CHECK=0
linestoprint=0

### getopts
OPTERR=0

while getopts ":d:i:u:cqorvtfpjklbsxawh" flag
do
    case "${flag}" in
        d) DELAY=${OPTARG//[!0-9.]/}; check=$DELAY;
            if [[ $check  == "" ]] || [[ $check == "." ]]; then echo "Invalid value $OPTARG given to -$flag" >&2; exit 1; fi;;
        i) IDELAY=${OPTARG//[!0-9.]/}; check=$IDELAY;
            if [[ $check  == "" ]] || [[ $check == "." ]]; then echo "Invalid value $OPTARG given to -$flag" >&2; exit 1; fi;;
        u) PRINT_COUNT=1;linestoprint=${OPTARG//[!0-9]/}; check=$linestoprint;
            if [[ $check  == "" ]]; then echo "Invalid value $OPTARG given to -$flag" >&2; exit 1; fi;;
        c) CONTINUOUS=$((1-CONTINUOUS));;
        q) CPUFREQ=$((1-CPUFREQ));;
        o) VSOC=$((1-VSOC));;
        r) VCORE=$((1-VCORE));;
        v) VERBOSE=$((1-VERBOSE));;
        t) TEMP=$((1-TEMP));;
        f) FAN=$((1-FAN));;
        p) POWER=$((1-POWER));;
        j) ROSC1=$((1-ROSC1));;
        k) ROSC2=$((1-ROSC2));;
        l) ROSC3=$((1-ROSC3));;
        b) RING_OSC=$((1-RING_OSC));;
        s) PRINT_CHEADERS=$((1-PRINT_CHEADERS));;
        x) PRINT_HEADERS=$((1-PRINT_HEADERS));;
        a) THROTTLED_CHECK=$((1-THROTTLED_CHECK));;
        w) UPDATE_CHECK=$((1-UPDATE_CHECK));;
        h) echo -e "piStats v$PISTATS_REL\n"
           echo -e "Usage: piStats [OPTIONS]...\n"
           echo -e "Options:\n"
           echo -e "-c: Continuous output mode, default is Summary"
           echo -e "-d <NN>: set continuous mode delay in seconds between updates (default 8 seconds)"
           echo -e "-i <NN>: delay in seconds between stats pooling (default 0.2 seconds)"
           echo -e "-v: toggle verbose mode for summary mode and headers"
           echo -e "-r: toggle to show ARM Core voltage (vcore)"
           echo -e "-o: toggle to show SOC voltage (vsoc)"
           echo -e "-q: toggle to show kernel cpufreq driver core clocks (requested/reported)"
           echo -e "-t: toggle to show SOC temperature"
           echo -e "-f: toggle to show Fan rpm speed"
           echo -e "-p: toggle to show ARM Core power consumption (pcore)"
           echo -e "-j: toggle to show Ring Oscillator 1 in continuous mode"
           echo -e "-k: toggle to show Ring Oscillator 2 in continuous mode"
           echo -e "-l: toggle to show Ring Oscillator 3 in continuous mode"
           echo -e "-b: toggle to show Ring Oscillators in Summary mode"
           echo -e "-s: toggle to print column headers periodically in Continuous mode"
           echo -e "-a: toggle to check throttled status periodically in Continuous mode\n"
           echo -e "-x: suppress printing of all headers"
           echo -e "-u <NN>: print only <NN> times the stats in Continuous mode\n"
           echo -e "-w: check if this is the latest release and exit"
           echo -e "-h: will show this help screen\n"
           exit
           ;;
        :) echo -e "${RED}Option -$OPTARG requires an argument. " >&2
           exit 2
           ;;
            ?) echo -e "${RED}Invalid option -$OPTARG, check the supported switches with -h." >&2
           exit 3
           ;;
    esac
done

### Color codes.
GRAY='\e[1;30m'
RED='\e[1;31m'
YELLOW='\e[1;33m'
PURPLE='\e[1;35m'
CYAN='\e[0;36m'
ORANGE='\e[0;33m'
GREEN='\e[0;32m'
PURPLE='\e[1;35m'
RESET='\e[0m'

### System Information

modelname_tree=$(tr -d '\0' < /proc/device-tree/model)
hostname=$(/usr/bin/uname -n)
kernrel=$(/usr/bin/uname -r)
kernver=$(/usr/bin/uname -v)
modelname=${modelname_tree:10:4}
fansys=/sys/devices/platform/cooling_fan/hwmon/*
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
    if [[ ! -d "$fandev" ]]; then FAN=0; fi
fi

if ((pi4)); then
    h264block=$((1-h264block))
fi

# sudo check for CPUFREQ

if ((CPUFREQ)); then
    SUDOSTR=("")
    MYEUID=$(bash <<<'echo $EUID' 2>/dev/null)
    if [[ "$MYEUID" != "0" ]]; then
        suprompt=$(sudo -nv 2>&1)
        YESIMROOT=0
        if [[ $? -eq 0 ]]; then
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

### Headers

if ((PRINT_HEADERS)); then
    echo -e "${GRAY}piStats v$PISTATS_REL: ${YELLOW}$hostname ${ORANGE}[$modelname]"
    if ((VERBOSE)); then
        echo -e "${RESET}${GRAY}Rel: ${CYAN}$kernrel ${GRAY}Ver: ${CYAN}$kernver"
    fi
    echo -en "${RESET}"
fi

### Check for an updated release

if ((UPDATE_CHECK)); then
    last_version=$(curl --silent --connect-timeout 5 "https://api.github.com/repos/mann1x/piStats/releases/latest" |
    grep '"tag_name":' |
    sed -E 's/.*"([^"]+)".*/\1/')
#    PISTATS_REL=v1.14
    if [[ "$last_version" == "$PISTATS_REL" ]]; then
        echo -e "${GREEN}You are running the latest version${RESET}"
    elif [[ "$last_version" == "" ]]; then
        echo -e "${RED}There was an error checking for the latest release!${RESET}"
    else
        echo -e "${YELLOW}There is a new release available: ${GREEN}$last_version${RESET}"
    fi
    exit
fi

### Main

# Throttled status
function throttled_status () {
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
        if [[ $(($TSTATUS & 1 << $1)) -ne 0 ]] ; then echo -e "${RED}Alert: ${YELLOW}$2${RESET}"; fi
    done
    sleep $IDELAY
}

# Check command-line flag for continuous mode...
if ((CONTINUOUS)); then

    if ((PRINT_HEADERS)); then echo -e "${GRAY}entering continuous mode refresh every $DELAY seconds...${RESET}"; fi

    disprows="$(tput lines)"
    cntrows=0
    totalrows=1

    function print_cheaders {
        echo -en "${PURPLE}"
        if ((TEMP)); then echo -en "temp    "; fi
        echo -en "clock   "
        if ((CPUFREQ)); then echo -en "cpufreq      "; fi
        if ((FAN)); then echo -en "fan     "; fi
        if ((PCORE)); then echo -en "pcore     "; fi
        if ((VCORE)); then echo -en "vcore     "; fi
        if ((VSOC)); then echo -en "vsoc      "; fi
        arr_odata=( )
        if ((ROSC1)); then arr_odata+=('1'); echo -en "r1clk   r1volt   r1temp  "; fi
        if ((ROSC2)); then arr_odata+=('2'); echo -en "r2clk   r2volt   r2temp  "; fi
        if ((ROSC3)); then arr_odata+=('3'); echo -en "r3clk   r3volt   r3temp  "; fi

        echo -e "${RESET}"
    }

    while true; do

        if ( [[ $cntrows -eq 0 ]] && ((PRINT_HEADERS)) ) || ( [[ $cntrows -gt $(($disprows-1)) ]] &&
            ( ((THROTTLED_CHECK)) || ((PRINT_CHEADERS)) ) ); then

            if ((THROTTLED_CHECK)) || [[ $cntrows -eq 0 ]]; then throttled_status; fi

            if ((PRINT_CHEADERS)) || [[ $cntrows -eq 0 ]]; then print_cheaders; fi

            cntrows=0
            disprows="$(tput lines)"
        fi

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

        if ((ROSC1)) || ((ROSC2)) || ((ROSC3)); then
            roscvals=""
            for SRC in "${arr_odata[@]}"; do
                ovalue=$(vcgencmd read_ring_osc "${SRC}")
                    REGEX_OVALUE=".*\(${SRC}\)=(.*)MHz \(@(.*)V\) \((.*)'C\)"
                    if [[ $ovalue =~ $REGEX_OVALUE ]]; then
                    ring_clock=${BASH_REMATCH[1]};
                    ring_volt=${BASH_REMATCH[2]};
                    ring_temp=${BASH_REMATCH[3]};
                fi
                    roscvals+=$(printf "%-7s %-8s %-8s" "$ring_clock" "$ring_volt" "$ring_temp")
                sleep $IDELAY;
            done
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
            fanrpm=$(cat $fansys/fan1_input 2>/dev/null)
            sleep $IDELAY
        fi

        if ((TEMP)); then printf "%-7s " "$temp"; fi
        printf "%-7s " "$arm_clock"
        if ((CPUFREQ)); then printf "%-12s " "$scaling_freq/$cpuinfo_freq"; fi
        if ((FAN)); then printf "%-7s " "$fanrpm"; fi
        if ((PCORE)); then printf "%-9s " "$core_power"; fi
        if ((VCORE)); then printf "%-9s " "$core_voltage"; fi
        if ((VSOC)); then printf "%-9s " "$core_uncached"; fi

        if ((ROSC1)) || ((ROSC2)) || ((ROSC3)); then echo -ne $roscvals; fi

        echo -en "\n"

        ((cntrows++))
        ((totalrows++))

        if ((PRINT_COUNT)) && [[ $totalrows -gt $linestoprint ]]; then exit; fi
        sleep $DELAY
    done

# ...otherwise, print stats once.

else

    if ((PRINT_HEADERS)); then throttled_status; fi

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
        fanrpm=$(cat $fansys/fan1_input 2>/dev/null)
    fi

    # Check command-line flag for additional verbosity.
    if ((VERBOSE)); then
        # SOC voltage.
        if ((pi4)) || ((pi5)); then
           sleep $IDELAY
           soc_voltage=$(vcgencmd measure_volts uncached); soc_voltage=${soc_voltage:5:6}
        fi

        # PMIC temperature.
        if ( ((pi4)) || ((pi5)) ) && ((PMIC)); then
           sleep $IDELAYSMALL
           pmic_temp=$(vcgencmd measure_temp pmic); pmic_temp=${pmic_temp:5:4}
        fi

        # Additional clock speeds and clock settings.
        arr_gclocks=( 'isp' 'v3d' 'sdram')

        if ((h264block)) then arr_gclocks+=('h264'); fi
        if ((hevcblock)) then arr_gclocks+=('hevc'); fi

        for SRC in "${arr_gclocks[@]}"; do
            if [[ SRC != 'sdram' ]]; then
                clock=$(vcgencmd measure_clock $SRC)
                eval "$SRC"_clock=$((${clock#*=} / 1000000))
            fi

            eval "$SRC"_clock_min=$(vcgencmd get_config "${SRC}_freq_min" | cut -d "=" -f 2)
            if [[ "$SRC"_clock_min == "0" ]]; then "$SRC"_clock_min = "N/A"; fi

            this_clock_min=$(vcgencmd get_config "${SRC}_freq_min" | cut -d "=" -f 2)
            if [[ "$this_clock_min" == "0" ]]; then
                eval "$SRC"_clock_min="N/A"
            else
                eval "$SRC"_clock_min='"${this_clock_min} MHz"'
            fi
            this_clock_max=$(vcgencmd get_config "${SRC}_freq" | cut -d "=" -f 2)
            if [[ "$this_clock_max" == "0" ]]; then
                eval "$SRC"_clock_max="N/A"
            else
                eval "$SRC"_clock_max='"${this_clock_max} MHz"'
            fi
            sleep $IDELAYSMALL
        done

        # Additional SDRAM voltages.
        for SRC in sdram_c sdram_i sdram_p; do
            voltage=$(vcgencmd measure_volts $SRC)
            eval "$SRC"_voltage=${voltage:5:4}
        done

        # SD card clock speed.
        sd_clock=$(($(sudo awk 'NR==2 { printf $3 }' /sys/kernel/debug/mmc0/ios) / 1000000))

        # Shared memory split between the CPU and GPU (adds to 1G).
        for SRC in arm gpu; do
            mem=$(vcgencmd get_mem $SRC)
            eval "$SRC"_mem=${mem//[!0-9]/}
        done

        # OverVoltage
        over_voltage=$(vcgencmd get_config over_voltage | cut -d "=" -f 2);
        over_voltage_delta=$(vcgencmd get_config over_voltage_delta | cut -d "=" -f 2);
        over_voltage_delta=$((${over_voltage_delta#*=} / 1000))
        over_voltage_min=$(vcgencmd get_config over_voltage_min | cut -d "=" -f 2);

        # Pi5 PMIC Reset bit
        if ((pi5)) && ((PMIC)); then pmic_reset=$(hexdump -s 0 -n 1 -e '1/1 "%08x" "\n"' < /proc/device-tree/chosen/power/power_reset); fi

    fi

    if ((pi5)) && ((FAN)); then
        # Fan rpm.
        fanpwm=$(cat $fansys/pwm1 2>/dev/null)
        fanperc=$((fanpwm * 100 / 255))
        sleep $IDELAYSMALL
    fi


    # CPU and Core clock settings
    arm_clock_max=$(vcgencmd get_config arm_freq | cut -d "=" -f 2)
    arm_clock_min=$(vcgencmd get_config arm_freq_min | cut -d "=" -f 2);
    core_clock_max=$(vcgencmd get_config core_freq | cut -d "=" -f 2);
    core_clock_min=$(vcgencmd get_config core_freq_min | cut -d "=" -f 2);

    # Final output.

    printf "${PURPLE}temp${RESET}"
    if ((FAN)); then printf "                  ${PURPLE}fan            fan pwm${RESET}\n"; fi

    if ((TEMP)); then
        printf "${GRAY}cpu:${RESET}  "

        # Different colors for high temperatures to alert user.
        if [[ 70 < $temp ]]; then
            if [[ $temp > 80 ]]; then
                echo -ne "${RED}"     # Very High
            else
                echo -ne "${YELLOW}"  # High
            fi
        fi
        printf "%-10s${RESET}" "$temp C";
        if ((FAN)); then printf "      %-4s rpm       %-3s ${GRAY}[%-2s %%]${RESET}" "$fanrpm" "$fanpwm" "$fanperc"; fi
    fi

    echo -en "\n"

    echo -e "\n${PURPLE}clocks                ${GRAY}min            max${RESET}"
    printf "${GRAY}cpu:${RESET}  %-10s      %-10s     %-10s\n" "$arm_clock MHz" "$arm_clock_min MHz" "$arm_clock_max MHz"
    printf "${GRAY}gpu:${RESET}  %-10s      %-10s     %-10s\n" "$core_clock MHz" "$core_clock_min MHz" "$core_clock_max MHz"

    if ((VERBOSE)); then
        if ((hevcblock)); then printf "${GRAY}hevc:${RESET} %-10s      %-10s     %-10s\n" "$hevc_clock MHz" "$hevc_clock_min" "$hevc_clock_max"; fi
        if ((h264block)); then printf "${GRAY}h264:${RESET} %-10s      %-10s     %-10s\n" "$h264_clock MHz" "$h264_clock_min" "$h264_clock_max"; fi

        printf "${GRAY}isp:${RESET}  %-10s      %-10s     %-10s\n" "$isp_clock MHz" "$isp_clock_min" "$isp_clock_max"
        printf "${GRAY}v3d:${RESET}  %-10s      %-10s     %-10s\n" "$v3d_clock MHz" "$v3d_clock_min" "$v3d_clock_max"
        printf "${GRAY}ram:${RESET}  %-10s      %-10s     %-10s\n" "" "$sdram_clock_min" "$sdram_clock_max"
        printf "${GRAY}sd:${RESET}   %-10s\n"                      "$sd_clock MHz"

        if ((CPUFREQ)); then
            echo -e "${GRAY}kern:${RESET} $scaling_freq/$cpuinfo_freq MHz"
        fi
    fi

    printf "\n${PURPLE}voltages${RESET}"

        if ( [[ "$over_voltage_delta" != "0" ]] || [[ "$over_voltage" != "0" ]] || [[ "$over_voltage_min" != "0" ]] ) && ((VERBOSE)); then
            printf "${YELLOW}          OC ${GRAY}(ov [set] [min] [delta]): ${GRAY}[${ORANGE}%s${GRAY}]${RESET}  ${GRAY}[${ORANGE}%s${GRAY}] ${GRAY}[${GREEN}%s${GRAY}]${RESET}\n" "$over_voltage" "$over_voltage_min" "$over_voltage_delta mV"
    else
        printf "\n"
        fi

    if ((VCORE)); then printf "${GRAY}core:${RESET} %-11s " "$core_voltage V"; fi

    if ((VERBOSE)); then

        printf "${GRAY}   mem ([core] [i/o] [phy]):${RESET} ${GRAY}[${RESET}%-4s${GRAY}]${RESET} ${GRAY}[${RESET}%-4s${GRAY}]${RESET} ${GRAY}[${RESET}%-4s${GRAY}]${RESET}\n" "$sdram_c_voltage V" "$sdram_i_voltage V" "$sdram_p_voltage V"

        if ((pi4)) || ((pi5)); then printf "${GRAY}soc:${RESET}  %-11s\n" "$soc_voltage V"; fi

        if ((RING_OSC)); then

            printf "\n${PURPLE}ring oscillators         ${GRAY}volt        temp${RESET}\n"

            arr_odata=( '1' '2' '3')
            for SRC in "${arr_odata[@]}"; do
                sleep $IDELAY;
                ovalue=$(vcgencmd read_ring_osc "${SRC}")
                    REGEX_OVALUE=".*\(${SRC}\)=(.*)MHz \(@(.*)V\) \((.*)'C\)"
                    if [[ $ovalue =~ $REGEX_OVALUE ]]; then
                    ring_clock=${BASH_REMATCH[1]};
                    ring_volt=${BASH_REMATCH[2]};
                    ring_temp=${BASH_REMATCH[3]};
                    printf "${GRAY}ring_osc%s:${RESET}  %-10s   %-11s %-11s\n" "$SRC" "$ring_clock MHz" "$ring_volt V" "$ring_temp C"
                fi
            done

        fi

        if ( ((pi4)) || ((pi5)) ) && ((PMIC)); then

            printf "\n${PURPLE}pmic\n"

            if ((pi5)); then

                printf "${GRAY}temp:${RESET}        "

                # Different colors for high temperatures to alert user.
                if [[ 70 < $pmic_temp ]]; then
                    if [[ $pmic_temp > 80 ]]; then
                        echo -ne "${RED}"     # Depleted battery
                    else
                        echo -ne "${YELLOW}"  # Low Battery
                    fi
                fi
                printf "%-8s${RESET}\n" "$pmic_temp C";
            fi

            if ((pi5)) && ((PMIC)) && [[ "$pmic_reset" != "00000000" ]]; then printf "${GRAY}power_reset:${RESET} %-8s\n" "$pmic_reset"; fi

            if ( ((pi4)) || ((pi5)) ) && ((PMIC_VOLTAGES)); then

                # RTC Battery

                rtc_show=0;
                    pmic_input=$(vcgencmd pmic_read_adc batt_v);
                    REGEX_PMIC='BATT_V volt.*=([0-9.]{4}).*[AV].*'
                    if [[ $pmic_input =~ $REGEX_PMIC ]]; then rtc_voltage=${BASH_REMATCH[1]}; rtc_show=1; fi
                if ((rtc_show)); then
                    rtc_chargingv=$(($(cat /sys/devices/platform/soc/soc:rpi_rtc/rtc/rtc0/charging_voltage) / 1000))

                    printf "${GRAY}rtc battery:${RESET} "
                    if [[ $rtc_voltage < 2.80 ]]; then
                        if [[ $rtc_voltage < 2.60 ]]; then
                            echo -ne "${RED}"     # Depleted battery
                        else
                            echo -ne "${YELLOW}"  # Low Battery
                        fi
                    fi

                    printf "%-11s${RESET} " "$rtc_voltage V"

                    if [[ $rtc_chargingv -gt 0 ]]; then
                        echo -e "${ORANGE}(charging at $rtc_chargingv mV)${RESET}"
                    else
                        echo -e "${GRAY}(charging disabled)${RESET}"
                    fi
                fi

                # External 5V power supply

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

                # PMIC Voltages & Currents

                pmic_totalp=0

                arr_pdata=( 'VDD_CORE' 'DDR_VDD2' 'DDR_VDDQ' 'HDMI' '3V3_SYS' '1V8_SYS' '1V1_SYS' '3V3_DAC' '3V3_ADC' '3V7_WL_SW' '0V8_AON' '0V8_SW' )
                for SRC in "${arr_pdata[@]}"; do
                    label=$(echo $SRC | tr '[:upper:]' '[:lower:]')
                    volt=$(vcgencmd pmic_read_adc "${label}_v")
                    current=$(vcgencmd pmic_read_adc "${label}_a")
                    REGEX_VOLT="${SRC}_V volt.*=(.*)[AV].*"
                    REGEX_CURRENT="${SRC}_A current.*=(.*)[AV].*"
                    if [[ $volt =~ $REGEX_VOLT ]]; then pmic_voltage=${BASH_REMATCH[1]}; fi
                    if [[ $current =~ $REGEX_CURRENT ]]; then pmic_current=${BASH_REMATCH[1]}; fi
                    pmic_power=$(echo "$pmic_voltage $pmic_current" | awk '{printf "%.4f", $1*$2}')
                    pmic_totalp=$(echo $pmic_totalp + $pmic_power | bc)
                    printf "${GRAY}%-10s${RESET}   %-11s %-11s (%-11s)\n" "$label:" "${pmic_voltage:0:6} V" "${pmic_current:0:6} A" "${pmic_power:0:6} Watt"
                done

                printf "${GRAY}total:${RESET}       %-11s${RESET}\n" "$pmic_totalp Watt"
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