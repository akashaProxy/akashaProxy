[ -z "$version" ] && . /data/adb/akashaProxy/clash.config

monitor_local_ipv4() {

    change=false

    wifistatus=$(dumpsys connectivity | grep "WIFI" | grep "state:" | awk -F ", " '{print $2}' | awk -F "=" '{print $2}' 2>&1)

    if [ ! -z "${wifistatus}" ]; then
        if test ! "${wifistatus}" = "$(cat ${run_path}/lastwifi)"; then
            change=true
            echo "${wifistatus}" >${run_path}/lastwifi
        elif [ "$(ip route get 1.2.3.4 |,awk '{print $5}' 2>&1)" != "wlan0" ]; then
            change=true
            echo "${wifistatus}" >${run_path}/lastwifi
        fi
    else
        echo "" >${run_path}/lastwifi
    fi
    
    if [ "$(settings get global mobile_data 2>&1)" -eq 1 ] || [ "$(settings get global mobile_data1 2>&1)" -eq 1 ]; then
        if [ ! "${mobilestatus}" = "$(cat ${run_path}/lastmobile)" ]; then
            change=true
            echo "${mobilestatus}" >${run_path}/lastmobile
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

restart() {
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

upgrade() {
    log "正在下载 ${bin_name} 内核..."
    mkdir -p ${data_dir}/kernel/temp
    remote_mihomo_ver=$1
    specific_mihomo_filename="mihomo-android-${ABI}-${remote_mihomo_ver}"
    if [ "${alpha}" = "true" ];then
        curl --connect-timeout 5 -Ls -o ${data_dir}/kernel/temp/mihomo.gz "${ghproxy}https://github.com/MetaCubeX/mihomo/releases/download/Prerelease-Alpha/${specific_mihomo_filename}.gz"
    else
        curl --connect-timeout 5 -Ls -o ${data_dir}/kernel/temp/mihomo.gz "${ghproxy}https://github.com/MetaCubeX/mihomo/releases/latest/download/${specific_mihomo_filename}.gz"
    fi

    if [ -f ${data_dir}/kernel/temp/mihomo.gz ];then
        busybox gunzip -f ${data_dir}/kernel/temp/mihomo.gz
        if [ -f ${data_dir}/kernel/temp/mihomo ];then
            rm -f ${data_dir}/kernel/mihomo
            mv ${data_dir}/kernel/temp/mihomo ${data_dir}/kernel/
            rm -rf ${data_dir}/kernel/temp
            chmod +x ${data_dir}/kernel/mihomo
            log "info: 更新完成"
        else
            rm -rf ${data_dir}/kernel/temp
            log "err: 更新失败, 请自行前往 GitHub 项目地址下载 → https://github.com/MetaCubeX/mihomo/releases"
            return
        fi
    else
        rm -rf ${data_dir}/kernel/temp
        log "err: 更新失败, 请自行前往 GitHub 项目地址下载 → https://github.com/MetaCubeX/mihomo/releases"
        return
    fi
}

check_mihomo_ver() {
    if [ "${alpha}" = "true" ];then
        remote_mihomo_ver=$(curl --connect-timeout 5 -Ls "${ghproxy}https://github.com/MetaCubeX/mihomo/releases/download/Prerelease-Alpha/version.txt")
    else
        remote_mihomo_ver=$(curl --connect-timeout 5 -Ls "${ghproxy}https://github.com/MetaCubeX/mihomo/releases/latest/download/version.txt")
    fi
    if [ -z "${remote_mihomo_ver}" ];then
        unset remote_mihomo_ver
        log "err: 网络连接失败"
        return
    fi

    if [ -f ${kernel_bin} ];then
        local_mihomo_ver=$(eval ${kernel_bin} -v | head -n 1 | sed 's/.*Meta //g' | sed 's/ android.*//g')
    else
        local_mihomo_ver=""
    fi

    if [ "${remote_mihomo_ver}" = "${local_mihomo_ver}" ];then
        log "info: 当前为最新版: ${local_mihomo_ver}"
    elif [ -z "${local_mihomo_ver}" ];then
        log "err: 获取本地版本失败, 最新版为: ${remote_mihomo_ver}"
        upgrade $remote_mihomo_ver
        if [ "$?" = "0" ]; then
            flag=true
        fi
    else
        log "info: 本地版本为: ${local_mihomo_ver}, 最新版为: ${remote_mihomo_ver}"
        upgrade $remote_mihomo_ver
        if [ "$?" = "0" ]; then
            flag=true
        fi

    fi

    unset local_mihomo_ver
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
    hd=""
    if [ "${mode}" = "global" ]; then
        mode=blacklist
    else
        if [ "${proxyGoogle}" = "true" ];then
            if [ "${mode}" = "whitelist" ];then
                uids=$(cat ${filter_packages_file} ${run_path}/Google.dat)
            else
                log "err: proxyGoogle只能在whitelist模式下使用"
                exit 1
            fi
        else
            uids=$(cat ${filter_packages_file})
        fi
    fi
    
    for package in $uids; do

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
        if [ "${mode}" = "blacklist" ]; then
            log "info: 排除 ${package}"
        else
            log "info: 代理 ${package}"
        fi
        echo "${hd}${uid}" >> ${appuid_file}
    done
}

port_detection() {
    kernel_pid=$(busybox pidof ${kernel_bin})
    match_count=0

    if ! (ss -h >/dev/null 2>&1); then
        kernel_port=$(netstat -anlp | grep -v p6 | grep ${bin_name} | awk '$6~/'"${kernel_pid}"*'/{print $4}' | awk -F ':' '{print $2}' | sort -u)
    else
        kernel_port=$(ss -antup | grep ${bin_name} | awk '$7~/'pid="${kernel_pid}"*'/{print $5}' | awk -F ':' '{print $2}' | sort -u)
    fi

    if [ "$(echo ${kernel_port} | grep "${tproxy_port}")" != "" ];then
        log "info: tproxy端口启动成功."
    else
        log "err: tproxy端口启动失败."
        exit 1
    fi

    if [ "$(echo ${kernel_port} | grep "${dns_port}")" != "" ];then
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
            update_file ${GeoIP_url} ${GeoIP_file}
        fi
    if [ "${auto_updateGeoSite}" = "true" ]; then
            update_file ${GeoSite_url} ${GeoSite_file}
        fi
    fi
    if [ "${auto_updatemihomo}" = "true" ] || [ ! -f "${kernel_bin}" ]; then
        check_mihomo_ver
        flag=true
    fi
    if [ "$(busybox pidof ${kernel_bin})" ] && [ "${flag}" = "true" ]; then
    if [ "${restart_update}" = "true" ];then
            restart
        fi
    fi

}

reload() {
    if [ ! -f "${config_file}" ]; then
        log "err: 缺少config.yaml 配置文件."
        return 1
    fi

    if [ -z "$(busybox pidof ${kernel_bin})" ]; then
        log "err: ${bin_name}未运行 无法热重载配置."
        return 1
    fi

    if ! ${kernel_bin} -d ${data_dir} -f "${config_file}" -t >/dev/null 2>&1; then
        log "err: 配置文件校验未通过 已放弃重载 请检查config.yaml."
        ${kernel_bin} -d ${data_dir} -f "${config_file}" -t 2>&1 | tail -3
        return 1
    fi

    cp -f "${config_file}" "${temporary_config_file}"
    chown ${kernel_user_group} "${temporary_config_file}"
    chmod 0644 "${temporary_config_file}"

    # mihomo 的 PUT /configs 接受 {"path": "..."}, 必须是绝对路径
    if [ -n "${kernel_ui_secret}" ]; then
        response=$(curl -s -o /dev/null -w '%{http_code}' -X PUT \
            -H "Authorization: Bearer ${kernel_ui_secret}" \
            -H "Content-Type: application/json" \
            -d "{\"path\": \"${temporary_config_file}\"}" \
            "http://127.0.0.1:${kernel_ui_port}/configs?force=true")
    else
        response=$(curl -s -o /dev/null -w '%{http_code}' -X PUT \
            -H "Content-Type: application/json" \
            -d "{\"path\": \"${temporary_config_file}\"}" \
            "http://127.0.0.1:${kernel_ui_port}/configs?force=true")
    fi

    case "${response}" in
        20*)
            log "info: 配置已热重载."
            ;;
        401 | 403)
            log "err: 热重载被拒绝(${response}) 请检查config.yaml中的secret是否与实际一致."
            return 1
            ;;
        "" | 000)
            log "err: 无法连接 external-controller(127.0.0.1:${kernel_ui_port}) 热重载失败."
            return 1
            ;;
        *)
            log "err: 热重载失败 HTTP ${response}."
            return 1
            ;;
    esac
}

limit() {
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

    mkdir "${Cgroup_memory_path}/${bin_name}"
    echo $(busybox pidof ${kernel_bin}) >"${Cgroup_memory_path}/${bin_name}/cgroup.procs"
    echo "${Cgroup_memory_limit}" >"${Cgroup_memory_path}/${bin_name}/memory.limit_in_bytes"

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
        if [ "${mode}" = "blacklist" ] && [ "$(busybox pidof ${kernel_bin})" ]; then
            monitor_local_ipv4
        else
            exit 0
        fi
        if [ "${mode}" = "global" ] && [ "$(busybox pidof ${kernel_bin})" ]; then
            monitor_local_ipv4
        else
            exit 0
        fi
        ;;
    p)
        port_detection
        ;;
    l)
        limit
        ;;
    ?)
        echo ""
        ;;
    esac
done
