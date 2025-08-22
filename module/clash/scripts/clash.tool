scripts=$(realpath $0)
scripts_dir=$(dirname ${scripts})
. /data/clash/clash.config

monitor_local_ipv4() {

    change=false

    wifistatus=$(dumpsys connectivity | grep "WIFI" | grep "state:" | awk -F ", " '{print $2}' | awk -F "=" '{print $2}' 2>&1)

    if [ ! -z "${wifistatus}" ]; then
        if test ! "${wifistatus}" = "$(cat ${Clash_run_path}/lastwifi)"; then
            change=true
            echo "${wifistatus}" >${Clash_run_path}/lastwifi
        elif [ "$(ip route get 1.2.3.4 | awk '{print $5}' 2>&1)" != "wlan0" ]; then
            change=true
            echo "${wifistatus}" >${Clash_run_path}/lastwifi
        fi
    else
        echo "" >${Clash_run_path}/lastwifi
    fi
    
    if [ "$(settings get global mobile_data 2>&1)" -eq 1 ] || [ "$(settings get global mobile_data1 2>&1)" -eq 1 ]; then
        if [ ! "${mobilestatus}" = "$(cat ${Clash_run_path}/lastmobile)" ]; then
            change=true
            echo "${mobilestatus}" >${Clash_run_path}/lastmobile
        fi
    fi

    if [ "${change}" = "true" ]; then

        local_ipv4=$(ip a | awk '$1~/inet$/{print $2}')
        local_ipv6=$(ip -6 a | awk '$1~/inet6$/{print $2}')
        rules_ipv4=$(${iptables_wait} -t mangle -nvL FILTER_LOCAL_IP | grep "ACCEPT" | awk '{print $9}' 2>&1)
        rules_ipv6=$(${ip6tables_wait} -t mangle -nvL FILTER_LOCAL_IP | grep "ACCEPT" | awk '{print $8}' 2>&1)

        for rules_subnet in ${rules_ipv4}; do
            [ -n "${rules_subnet}" ] || continue
            ${iptables_wait} -t mangle -D FILTER_LOCAL_IP -d ${rules_subnet} -j ACCEPT
        done

        for subnet in ${local_ipv4}; do
            [ -n "${subnet}" ] || continue
            if ! (${iptables_wait} -t mangle -C FILTER_LOCAL_IP -d ${subnet} -j ACCEPT >/dev/null 2>&1); then
                ${iptables_wait} -t mangle -I FILTER_LOCAL_IP -d ${subnet} -j ACCEPT
            fi
        done

        for rules_subnet6 in ${rules_ipv6}; do
            [ -n "${rules_subnet6}" ] || continue
            ${ip6tables_wait} -t mangle -D FILTER_LOCAL_IP -d ${rules_subnet6} -j ACCEPT
        done

        for subnet6 in ${local_ipv6}; do
            [ -n "${subnet6}" ] || continue
            if ! (${ip6tables_wait} -t mangle -C FILTER_LOCAL_IP -d ${subnet6} -j ACCEPT >/dev/null 2>&1); then
                ${ip6tables_wait} -t mangle -I FILTER_LOCAL_IP -d ${subnet6} -j ACCEPT
            fi
        done
    fi

    unset local_ipv4
    unset rules_ipv4
    unset local_ipv6
    unset rules_ipv6
    unset wifistatus
    unset mobilestatus
    unset change
}

restart_clash() {
    ${scripts_dir}/clash.service -k && ${scripts_dir}/clash.iptables -k
    ${scripts_dir}/clash.service -s && ${scripts_dir}/clash.iptables -s
    if [ "$?" = "0" ]; then
        log "info: 内核成功重启."
    else
        ${scripts_dir}/clash.service -k && ${scripts_dir}/clash.iptables -k
        log "err: 内核重启失败."
        exit 1
    fi
}

keep_dns() {
    local_dns=$(getprop net.dns1)

    if [ "${local_dns}" != "${static_dns}" ]; then
        for count in $(seq 1 $(getprop | grep dns | wc -l)); do
            setprop net.dns${count} ${static_dns}
        done
    fi

    if [ $(sysctl net.ipv4.ip_forward) != "1" ]; then
        sysctl -w net.ipv4.ip_forward=1
    fi

    unset local_dns
}

upgrade_clash() {
    log "正在下载 ${Clash_bin_name} 内核..."
    mkdir -p ${Clash_data_dir}/clashkernel/temp
    remote_clash_ver=$1
    specific_clash_filename="mihomo-android-${ABI}-${remote_clash_ver}"
    if [ "${alpha}" = "true" ];then
        curl --connect-timeout 5 -Ls -o ${Clash_data_dir}/clashkernel/temp/mihomo.gz "${ghproxy}https://github.com/MetaCubeX/mihomo/releases/download/Prerelease-Alpha/${specific_clash_filename}.gz"
    else
        curl --connect-timeout 5 -Ls -o ${Clash_data_dir}/clashkernel/temp/mihomo.gz "${ghproxy}https://github.com/MetaCubeX/mihomo/releases/latest/download/${specific_clash_filename}.gz"
    fi

    if [ -f ${Clash_data_dir}/clashkernel/temp/mihomo.gz ];then
        busybox gunzip -f ${Clash_data_dir}/clashkernel/temp/mihomo.gz
        if [ -f ${Clash_data_dir}/clashkernel/temp/mihomo ];then
            rm -f ${Clash_data_dir}/clashkernel/mihomo
            mv ${Clash_data_dir}/clashkernel/temp/mihomo ${Clash_data_dir}/clashkernel/
            rm -rf ${Clash_data_dir}/clashkernel/temp
            chmod +x ${Clash_data_dir}/clashkernel/mihomo
            log "info: 更新完成"
        else
            rm -rf ${Clash_data_dir}/clashkernel/temp
            log "err: 更新失败, 请自行前往 GitHub 项目地址下载 → https://github.com/MetaCubeX/mihomo/releases"
            return
        fi
    else
        rm -rf ${Clash_data_dir}/clashkernel/temp
        log "err: 更新失败, 请自行前往 GitHub 项目地址下载 → https://github.com/MetaCubeX/mihomo/releases"
        return
    fi
}

check_clash_ver() {
    if [ "${alpha}" = "true" ];then
        remote_clash_ver=$(curl --connect-timeout 5 -Ls "${ghproxy}https://github.com/MetaCubeX/mihomo/releases/download/Prerelease-Alpha/version.txt")
    else
        remote_clash_ver=$(curl --connect-timeout 5 -Ls "${ghproxy}https://github.com/MetaCubeX/mihomo/releases/latest/download/version.txt")
    fi
    if [ -z "${remote_clash_ver}" ];then
        unset remote_clash_ver
        log "err: 网络连接失败"
        return
    fi

    if [ -f ${Clash_bin_path} ];then
        local_clash_ver=$(eval ${Clash_bin_path} -v | head -n 1 | sed 's/.*Meta //g' | sed 's/ android.*//g')
    else
        local_clash_ver=""
    fi

    if [ "${remote_clash_ver}" = "${local_clash_ver}" ];then
        log "info: 当前为最新版: ${local_clash_ver}"
    elif [ -z "${local_clash_ver}" ];then
        log "err: 获取本地版本失败, 最新版为: ${remote_clash_ver}"
        upgrade_clash $remote_clash_ver
        if [ "$?" = "0" ]; then
            flag=true
        fi
    else
        log "info: 本地版本为: ${local_clash_ver}, 最新版为: ${remote_clash_ver}"
        upgrade_clash $remote_clash_ver
        if [ "$?" = "0" ]; then
            flag=true
        fi

    fi

    unset local_clash_ver
}

update_file() {
    file="$1"
    file_temp="${file}.temp"
    update_url="$2"

    curl -L ${update_url} -o ${file_temp}

    if [ -f "${file_temp}" ]; then
        mv -f ${file_temp} ${file}
        log "info: ${file}更新成功."
    else
        rm -rf ${file_temp}
        log "warn: ${file}更新失败"
        return 1
    fi
}

find_packages_uid() {
    rm -f ${appuid_file}
    rm -f ${appuid_file}.tmp
    hd=""
    if [ "${mode}" = "global" ]; then
        mode=blacklist
        uids=""
    else
        if [ "${proxyGoogle}" = "true" ];then
            if [ "${mode}" = "whitelist" ];then
                uids=$(cat ${filter_packages_file} ${Clash_run_path}/Google.dat)
            else
                log "err: proxyGoogle只能在whitelist模式下使用"
                exit 1
            fi
        else
            uids=$(cat ${filter_packages_file})
        fi
    fi
    
    for package in $uids; do
        if echo "${package}" | grep -q ":" ; then
            echo "${package}" >> ${appuid_file}
            if [ "${mode}" = "blacklist" ]; then
                log "info: ${package}已过滤."
            elif [ "${mode}" = "whitelist" ]; then
                log "info: ${package}已代理."
            fi
            continue
        fi

        if echo "${package}" | grep -q "[0-9].*\." ; then
            echo "${package}" >> ${appuid_file}
            if [ "${mode}" = "blacklist" ]; then
                log "info: ${package}已过滤."
            elif [ "${mode}" = "whitelist" ]; then
                log "info: ${package}已代理."
            fi
            continue
        fi

        nhd=$(echo "${package}" | awk -F ">" '/^[0-9]+>$/{print $1}')
        if [ "${nhd}" != "" ]; then
            hd=${nhd}
            continue
        fi

        uid=$(awk '$1~/'^"${package}"$'/{print $2}' ${system_packages_file})
    if [ -z "${uid}" ]; then
            uids=$(dumpsys package ${package} | grep appId= | awk -F= '{print $2}')
            if [ -z "${uids}" ]; then
                log "warn: ${package}未找到."
                continue
            else
                uid=uids
            fi
        fi

        echo "${hd}${uid}" >> ${appuid_file}.tmp
        if [ "${mode}" = "blacklist" ]; then
            log "info: ${hd}${package}已过滤."
        elif [ "${mode}" = "whitelist" ]; then
            log "info: ${hd}${package}已代理."
        fi
    done
    for uid in $(cat ${appuid_file}.tmp | sort -u); do
        echo ${uid} >> ${appuid_file}
    done
    rm -f ${appuid_file}.tmp
}

port_detection() {
    clash_pid=$(cat ${Clash_pid_file})
    match_count=0

    if ! (ss -h >/dev/null 2>&1); then
        clash_port=$(netstat -anlp | grep -v p6 | grep ${Clash_bin_name} | awk '$6~/'"${clash_pid}"*'/{print $4}' | awk -F ':' '{print $2}' | sort -u)
    else
        clash_port=$(ss -antup | grep ${Clash_bin_name} | awk '$7~/'pid="${clash_pid}"*'/{print $5}' | awk -F ':' '{print $2}' | sort -u)
    fi

    if [ "$(echo ${clash_port} | grep "${Clash_tproxy_port}")" != "" ];then
        log "info: tproxy端口启动成功."
    else
        log "err: tproxy端口启动失败."
        exit 1
    fi

    if [ "$(echo ${clash_port} | grep "${Clash_dns_port}")" != "" ];then
        log "info: dns端口启动成功."
    else
        log "err: dns端口启动失败."
        exit 1
    fi

    exit 0
}

update_pre() {
    flag=false
    if [ $Geo_auto_update != "true" ];then
        if [ "${auto_updateGeoIP}" = "true" ];then
            update_file ${GeoIP_url} ${Clash_GeoIP_file}
        fi
    if [ "${auto_updateGeoSite}" = "true" ]; then
            update_file ${GeoSite_url} ${Clash_GeoSite_file}
        fi
    fi
    if [ "${auto_updateMihomo}" = "true" ] || [ ! -f "${Clash_bin_path}" ]; then
        check_clash_ver
        flag=true
    fi
    if [ -f "${Clash_pid_file}" ] && [ "${flag}" = "true" ]; then
    if [ "${restart_update}" = "true" ];then
            restart_clash
        fi
    fi

}

reload() {
    cp -f ${Clash_config_file} ${temporary_config_file}
    curl -X PUT -d '{"configs": ["${temporary_config_file}"]}' http://127.0.0.1:${Clash_ui_port}/configs?force=true
}

limit_clash() {
    if [ -z "${Cgroup_memory_limit}" ]; then
        return
    fi

    if [ -z "${Cgroup_memory_path}" ]; then
        Cgroup_memory_path=$(mount | grep cgroup | awk '/memory/{print $3}' | head -1)
        if [ -z "${Cgroup_memory_path}" ]; then
            log "err: 自动获取Cgroup_memory_path失败."
            return
        fi
    fi

    mkdir "${Cgroup_memory_path}/clash"
    echo $(cat ${Clash_pid_file}) >"${Cgroup_memory_path}/clash/cgroup.procs"
    echo "${Cgroup_memory_limit}" >"${Cgroup_memory_path}/clash/memory.limit_in_bytes"

    log "info: 限制内存: ${Cgroup_memory_limit}."
}

while getopts ":kfmpusl" signal; do
    case ${signal} in
    u)
        update_pre
        ;;
    s)
        reload
        ;;
    k)
        if [ "${mode}" = "blacklist" ] || [ "${mode}" = "whitelist" ] || [ "${mode}" = "global" ]; then
            keep_dns
        else
            exit 0
        fi
        ;;
    f)
        find_packages_uid
        ;;
    m)
        if [ "${mode}" = "blacklist" ] && [ -f "${Clash_pid_file}" ]; then
            monitor_local_ipv4
        else
            exit 0
        fi
        if [ "${mode}" = "global" ] && [ -f "${Clash_pid_file}" ]; then
            monitor_local_ipv4
        else
            exit 0
        fi
        ;;
    p)
        port_detection
        ;;
    l)
        limit_clash
        ;;
    ?)
        echo ""
        ;;
    esac
done
