#! /vendor/bin/sh
# Copyright (c) 2012-2013, 2016-2017, The Linux Foundation. All rights reserved.
# mod by <<VenoM>>
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#     * Redistributions of source code must retain the above copyright
#       notice, this list of conditions and the following disclaimer.
#     * Redistributions in binary form must reproduce the above copyright
#       notice, this list of conditions and the following disclaimer in the
#       documentation and/or other materials provided with the distribution.
#     * Neither the name of The Linux Foundation nor
#       the names of its contributors may be used to endorse or promote
#       products derived from this software without specific prior written
#       permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NON-INFRINGEMENT ARE DISCLAIMED.  IN NO EVENT SHALL THE COPYRIGHT OWNER OR
# CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
# EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
# OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
# OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

# Read adj series and set adj threshold for PPR and ALMK.
# This is required since adj values change from framework to framework.
adj_series=`cat /sys/module/lowmemorykiller/parameters/adj`
adj_1="${adj_series#*,}"
set_almk_ppr_adj="${adj_1%%,*}"

# PPR and ALMK should not act on HOME adj and below.
# Normalized ADJ for HOME is 6. Hence multiply by 6
# ADJ score represented as INT in LMK params, actual score can be in decimal
# Hence add 6 considering a worst case of 0.9 conversion to INT (0.9*6).
# For uLMK + Memcg, this will be set as 6 since adj is zero.
set_almk_ppr_adj=$(((set_almk_ppr_adj * 6) + 6))
echo $set_almk_ppr_adj > /sys/module/lowmemorykiller/parameters/adj_max_shift
echo $set_almk_ppr_adj > /sys/module/process_reclaim/parameters/min_score_adj

# Set Memory parameters.
#
# Set per_process_reclaim tuning parameters
# All targets will use vmpressure range 50-70,
# All targets will use 512 pages swap size.
#
# Set Low memory killer minfree parameters
# 64 bit will use Google default LMK series.
#
# Set ALMK parameters (usually above the highest minfree values)
# vmpressure_file_min threshold is always set slightly higher
# than LMK minfree's last bin value for all targets. It is calculated as
# vmpressure_file_min = (last bin - second last bin ) + last bin
#
# Set allocstall_threshold to 0 for all targets.
#
# Calculate vmpressure_file_min as below & set for 64 bit:
# vmpressure_file_min = last_lmk_bin + (last_lmk_bin - last_but_one_lmk_bin)
echo "18432,23040,27648,32256,55296,80640" > /sys/module/lowmemorykiller/parameters/minfree

echo 1 > /sys/module/process_reclaim/parameters/enable_process_reclaim
echo 70 > /sys/module/process_reclaim/parameters/pressure_max
echo 10 > /sys/module/process_reclaim/parameters/pressure_min
echo 30 > /sys/module/process_reclaim/parameters/swap_opt_eff
echo 1024 > /sys/module/process_reclaim/parameters/per_swap_size
echo 0 > /sys/module/vmpressure/parameters/allocstall_threshold
echo 100 > /proc/sys/vm/swappiness

minfree_series=`cat /sys/module/lowmemorykiller/parameters/minfree`
minfree_1="${minfree_series#*,}" ; rem_minfree_1="${minfree_1%%,*}"
minfree_2="${minfree_1#*,}" ; rem_minfree_2="${minfree_2%%,*}"
minfree_3="${minfree_2#*,}" ; rem_minfree_3="${minfree_3%%,*}"
minfree_4="${minfree_3#*,}" ; rem_minfree_4="${minfree_4%%,*}"
minfree_5="${minfree_4#*,}"
vmpres_file_min=$((minfree_5 + (minfree_5 - rem_minfree_4)))
echo $vmpres_file_min > /sys/module/lowmemorykiller/parameters/vmpressure_file_min
echo 0 > /sys/module/lowmemorykiller/parameters/enable_adaptive_lmk

setprop sys.post_boot.parsed 1
setprop vendor.post_boot.parsed 1

panel=`cat /sys/class/graphics/fb0/modes`
if [ "${panel:5:1}" == "x" ]; then
    panel=${panel:2:3}
else
    panel=${panel:2:4}
fi

# Apply Scheduler and Governor settings for 8976
# SoC IDs are 266, 274, 277, 278
# HMP scheduler (big.Little cluster related) settings
echo 95 > /proc/sys/kernel/sched_upmigrate
echo 85 > /proc/sys/kernel/sched_downmigrate
echo 2 > /proc/sys/kernel/sched_window_stats_policy
echo 5 > /proc/sys/kernel/sched_ravg_hist_size
echo 3 > /sys/devices/system/cpu/cpu0/sched_mostly_idle_nr_run
echo 3 > /sys/devices/system/cpu/cpu1/sched_mostly_idle_nr_run
echo 3 > /sys/devices/system/cpu/cpu2/sched_mostly_idle_nr_run
echo 3 > /sys/devices/system/cpu/cpu3/sched_mostly_idle_nr_run
echo 3 > /sys/devices/system/cpu/cpu4/sched_mostly_idle_nr_run
echo 3 > /sys/devices/system/cpu/cpu5/sched_mostly_idle_nr_run
echo 3 > /sys/devices/system/cpu/cpu6/sched_mostly_idle_nr_run
echo 3 > /sys/devices/system/cpu/cpu7/sched_mostly_idle_nr_run

for devfreq_gov in /sys/class/devfreq/*qcom,mincpubw*/governor
do
    echo "cpufreq" > $devfreq_gov
done

for devfreq_gov in /sys/class/devfreq/*qcom,cpubw*/governor
do
    echo "bw_hwmon" > $devfreq_gov
    for cpu_io_percent in /sys/class/devfreq/*qcom,cpubw*/bw_hwmon/io_percent
    do
        echo 20 > $cpu_io_percent
    done
    for cpu_guard_band in /sys/class/devfreq/*qcom,cpubw*/bw_hwmon/guard_band_mbps
    do
    echo 30 > $cpu_guard_band
    done
done

for gpu_bimc_io_percent in /sys/class/devfreq/qcom,gpubw*/bw_hwmon/io_percent
do
    echo 40 > $gpu_bimc_io_percent
done

# enable governor for power cluster
echo 1 > /sys/devices/system/cpu/cpu0/online
echo "interactive" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
echo 99 > /sys/devices/system/cpu/cpu0/cpufreq/interactive/go_hispeed_load
echo 20000 > /sys/devices/system/cpu/cpu0/cpufreq/interactive/timer_rate
echo 0 > /sys/devices/system/cpu/cpu0/cpufreq/interactive/io_is_busy
echo 40000 > /sys/devices/system/cpu/cpu0/cpufreq/interactive/min_sample_time
echo 400000 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_min_freq
echo 1305600 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
echo 40000 > /sys/devices/system/cpu/cpu0/cpufreq/boostpulse_duration
echo "50000 1017600:50000 1190400:100000" > /sys/devices/system/cpu/cpu0/cpufreq/interactive/above_hispeed_delay
echo 806400 > /sys/devices/system/cpu/cpu0/cpufreq/interactive/hispeed_freq
echo "1 400000:60 691200:80 1017600:90 1190400:95" > /sys/devices/system/cpu/cpu0/cpufreq/interactive/target_loads

# enable governor for perf cluster
echo 1 > /sys/devices/system/cpu/cpu4/online
echo "interactive" > /sys/devices/system/cpu/cpu4/cpufreq/scaling_governor
echo 99 > /sys/devices/system/cpu/cpu4/cpufreq/interactive/go_hispeed_load
echo 20000 > /sys/devices/system/cpu/cpu4/cpufreq/interactive/timer_rate
echo 0 > /sys/devices/system/cpu/cpu4/cpufreq/interactive/io_is_busy
echo 40000 > /sys/devices/system/cpu/cpu4/cpufreq/interactive/min_sample_time
echo 40000 > /sys/devices/system/cpu/cpu4/cpufreq/interactive/sampling_down_factor
echo 400000 > /sys/devices/system/cpu/cpu4/cpufreq/scaling_min_freq
echo 1612800 > /sys/devices/system/cpu/cpu4/cpufreq/scaling_max_freq
echo 20000 > /sys/devices/system/cpu/cpu4/cpufreq/interactive/max_freq_hysteresis
echo 883200 > /sys/devices/system/cpu/cpu4/cpufreq/interactive/hispeed_freq
echo "50000 940800:50000 998400:50000 1113600:50000 1190400:100000" > /sys/devices/system/cpu/cpu4/cpufreq/interactive/above_hispeed_delay
echo "1 400000:70 940800:80 1113600:90 1190400:95" > /sys/devices/system/cpu/cpu4/cpufreq/interactive/target_loads

# Enable core control
insmod /system/lib/modules/core_ctl.ko
#for 8976
             
echo 2 > /sys/devices/system/cpu/cpu4/core_ctl/min_cpus
echo 4 > /sys/devices/system/cpu/cpu4/core_ctl/max_cpus
echo 60 > /sys/devices/system/cpu/cpu4/core_ctl/busy_up_thres
echo 50 > /sys/devices/system/cpu/cpu4/core_ctl/busy_down_thres
echo 100 > /sys/devices/system/cpu/cpu4/core_ctl/offline_delay_ms
echo 2 > /sys/devices/system/cpu/cpu0/core_ctl/min_cpus
echo 4 > /sys/devices/system/cpu/cpu0/core_ctl/max_cpus
echo 60 > /sys/devices/system/cpu/cpu0/core_ctl/busy_up_thres
echo 50 > /sys/devices/system/cpu/cpu0/core_ctl/busy_down_thres
echo 100 > /sys/devices/system/cpu/cpu0/core_ctl/offline_delay_ms
echo 1 > /sys/devices/system/cpu/cpu4/core_ctl/is_big_cluster

# HMP scheduler (big.Little cluster related) settings
echo 35 > /proc/sys/kernel/sched_upmigrate
echo 23 > /proc/sys/kernel/sched_downmigrate

# disable thermal & BCL core_control to update interactive gov settings
echo 0 > /sys/module/msm_thermal/core_control/enabled

# HMP Task packing settings for 8976
echo 30 > /proc/sys/kernel/sched_small_task
echo 20 > /sys/devices/system/cpu/cpu0/sched_mostly_idle_load
echo 20 > /sys/devices/system/cpu/cpu1/sched_mostly_idle_load
echo 20 > /sys/devices/system/cpu/cpu2/sched_mostly_idle_load
echo 20 > /sys/devices/system/cpu/cpu3/sched_mostly_idle_load
echo 20 > /sys/devices/system/cpu/cpu4/sched_mostly_idle_load
echo 20 > /sys/devices/system/cpu/cpu5/sched_mostly_idle_load
echo 20 > /sys/devices/system/cpu/cpu6/sched_mostly_idle_load
echo 20 > /sys/devices/system/cpu/cpu7/sched_mostly_idle_load

# Disable sched boost
echo 0 > /proc/sys/kernel/sched_boost

# Bring up all cores online
echo 1 > /sys/devices/system/cpu/cpu1/online
echo 1 > /sys/devices/system/cpu/cpu2/online
echo 1 > /sys/devices/system/cpu/cpu3/online
echo 1 > /sys/devices/system/cpu/cpu4/online
echo 1 > /sys/devices/system/cpu/cpu5/online
echo 1 > /sys/devices/system/cpu/cpu6/online
echo 1 > /sys/devices/system/cpu/cpu7/online

# Enable LPM Prediction
echo 1 > /sys/module/lpm_levels/parameters/lpm_prediction

# remove interaction lock when idle
echo 100 > /sys/devices/virtual/graphics/fb0/idle_time

# Disable L2 GDHS on 8976
echo N > /sys/module/lpm_levels/system/a53/a53-l2-gdhs/idle_enabled
echo N > /sys/module/lpm_levels/system/a72/a72-l2-gdhs/idle_enabled

# Enable sched guided freq control
echo 1 > /sys/devices/system/cpu/cpu0/cpufreq/interactive/use_sched_load
echo 1 > /sys/devices/system/cpu/cpu0/cpufreq/interactive/use_migration_notif
echo 1 > /sys/devices/system/cpu/cpu4/cpufreq/interactive/use_sched_load
echo 1 > /sys/devices/system/cpu/cpu4/cpufreq/interactive/use_migration_notif
echo 50000 > /proc/sys/kernel/sched_freq_inc_notify
echo 50000 > /proc/sys/kernel/sched_freq_dec_notify

# Enable timer migration to little cluster
echo 1 > /proc/sys/kernel/power_aware_timer_migration

#enable sched colocation and colocation inheritance
echo 130 > /proc/sys/kernel/sched_grp_upmigrate
echo 110 > /proc/sys/kernel/sched_grp_downmigrate
echo   1 > /proc/sys/kernel/sched_enable_thread_grouping

# Parse misc partition path and set property
misc_link=$(ls -l /dev/block/bootdevice/by-name/misc)
real_path=${misc_link##*>}
setprop persist.vendor.mmi.misc_dev_path $real_path

# Set BFQ as default io-schedular after boot
setprop sys.io.scheduler "bfq"
