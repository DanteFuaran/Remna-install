#!/bin/bash

SCRIPT_VERSION="1.5.1"
DIR_REMNAWAVE="/opt/remnawave/"
SCRIPT_URL="https://raw.githubusercontent.com/DanteFuaran/Remna-install/refs/heads/main/install_remnawave.sh"

# ═══════════════════════════════════════════════
# ВОССТАНОВЛЕНИЕ ТЕРМИНАЛА И ОБРАБОТКА ПРЕРЫВАНИЙ
# ═══════════════════════════════════════════════
cleanup_terminal() {
    stty sane 2>/dev/null || true
    tput cnorm 2>/dev/null || true
}

handle_interrupt() {
    cleanup_terminal
    echo
    echo -e "${YELLOW}Скрипт прерван пользователем${NC}"
    exit 130
}

trap cleanup_terminal EXIT
trap handle_interrupt INT TERM

# ═══════════════════════════════════════════════
# ЦВЕТА
# ═══════════════════════════════════════════════
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
WHITE='\033[1;37m'
GRAY='\033[0;37m'
NC='\033[0m'
DARKGRAY='\033[1;30m'

# ═══════════════════════════════════════════════
# УТИЛИТЫ ВЫВОДА
# ═══════════════════════════════════════════════
print_action()  { printf "${BLUE}➜${NC}  %b\n" "$1"; }
print_error()   { printf "${RED}✖ %b${NC}\n" "$1"; }
print_success() { printf "${GREEN}✅${NC} %b\n" "$1"; }

# ═══════════════════════════════════════════════
# СПИННЕРЫ
# ═══════════════════════════════════════════════
show_spinner() {
    local pid=$!
    local delay=0.08
    local spin=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0 msg="$1"
    tput civis 2>/dev/null || true
    while kill -0 $pid 2>/dev/null; do
        printf "\r${GREEN}%s${NC}  %s" "${spin[$i]}" "$msg"
        i=$(( (i+1) % 10 ))
        sleep $delay
    done
    printf "\r${GREEN}✅${NC} %s\n" "$msg"
    tput cnorm 2>/dev/null || true
}

show_spinner_timer() {
    local seconds=$1
    local msg="$2"
    local spin=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0
    local delay=0.08
    local elapsed=0
    tput civis 2>/dev/null || true
    while [ $elapsed -lt $seconds ]; do
        local remaining=$((seconds - elapsed))
        printf "\r${GREEN}%s${NC}  %s (%d сек)" "${spin[$i]}" "$msg" "$remaining"
        for ((j=0; j<12; j++)); do
            sleep $delay
            i=$(( (i+1) % 10 ))
        done
        ((elapsed++))
    done
    printf "\r${GREEN}✅${NC} %s\n" "$msg"
    tput cnorm 2>/dev/null || true
}

show_spinner_until_ready() {
    local url="$1"
    local msg="$2"
    local timeout=${3:-120}
    local spin=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0 elapsed=0 delay=0.08 loop_count=0
    tput civis 2>/dev/null || true
    while [ $elapsed -lt $timeout ]; do
        printf "\r${GREEN}%s${NC}  %s (%d/%d сек)" "${spin[$i]}" "$msg" "$elapsed" "$timeout"
        i=$(( (i+1) % 10 ))
        sleep $delay
        ((loop_count++))
        if [ $((loop_count % 12)) -eq 0 ]; then
            ((elapsed++))
            if curl -s -f --max-time 5 "$url" \
                --header 'X-Forwarded-For: 127.0.0.1' \
                --header 'X-Forwarded-Proto: https' \
                > /dev/null 2>&1; then
                printf "\r${GREEN}✅${NC} %s\n" "$msg"
                tput cnorm 2>/dev/null || true
                return 0
            fi
        fi
    done
    printf "\r${YELLOW}⚠️${NC}  %s (таймаут)\n" "$msg"
    tput cnorm 2>/dev/null || true
    return 1
}

# ═══════════════════════════════════════════════
# МЕНЮ СО СТРЕЛОЧКАМИ
# ═══════════════════════════════════════════════
show_arrow_menu() {
    set +e
    local title="$1"
    shift
    local options=("$@")
    local num_options=${#options[@]}
    local selected=0

    # Сохраняем настройки терминала
    local original_stty
    original_stty=$(stty -g 2>/dev/null)

    # Скрываем курсор
    tput civis 2>/dev/null || true

    # Отключаем canonical mode и echo, включаем чтение отдельных символов
    stty -icanon -echo min 1 time 0 2>/dev/null || true

    while true; do
        clear
        echo -e "${BLUE}════════════════════════════════════════${NC}"
        echo -e "${GREEN}   $title${NC}"
        echo -e "${BLUE}════════════════════════════════════════${NC}"
        echo

        for i in "${!options[@]}"; do
            # Проверяем, является ли элемент разделителем
            if [[ "${options[$i]}" =~ ^[─━═\s]*$ ]]; then
                # Разделители не выделяются, только выводятся
                echo -e "  ${options[$i]}"
            elif [ $i -eq $selected ]; then
                echo -e "${BLUE}▶${NC} ${GREEN}${options[$i]}${NC}"
            else
                echo -e "  ${options[$i]}"
            fi
        done

        echo
        echo -e "${BLUE}════════════════════════════════════════${NC}"
        echo -e "${DARKGRAY}Используйте ↑↓ для навигации, Enter для выбора${NC}"

        local key
        read -rsn1 key 2>/dev/null || key=""

        # Проверяем escape-последовательность для стрелок
        if [[ "$key" == $'\e' ]]; then
            local seq1="" seq2=""
            read -rsn1 -t 0.1 seq1 2>/dev/null || seq1=""
            if [[ "$seq1" == '[' ]]; then
                read -rsn1 -t 0.1 seq2 2>/dev/null || seq2=""
                case "$seq2" in
                    'A')  # Стрелка вверх
                        ((selected--))
                        if [ $selected -lt 0 ]; then
                            selected=$((num_options - 1))
                        fi
                        # Пропускаем разделители вверх
                        while [[ "${options[$selected]}" =~ ^[─\s]*$ ]]; do
                            ((selected--))
                            if [ $selected -lt 0 ]; then
                                selected=$((num_options - 1))
                            fi
                        done
                        ;;
                    'B')  # Стрелка вниз
                        ((selected++))
                        if [ $selected -ge $num_options ]; then
                            selected=0
                        fi
                        # Пропускаем разделители вниз
                        while [[ "${options[$selected]}" =~ ^[─\s]*$ ]]; do
                            ((selected++))
                            if [ $selected -ge $num_options ]; then
                                selected=0
                            fi
                        done
                        ;;
                esac
            fi
        else
            local key_code
            if [ -n "$key" ]; then
                key_code=$(printf '%d' "'$key" 2>/dev/null || echo 0)
            else
                key_code=13
            fi

            if [ "$key_code" -eq 10 ] || [ "$key_code" -eq 13 ]; then
                stty "$original_stty" 2>/dev/null || true
                tput cnorm 2>/dev/null || true
                return $selected
            fi
        fi
    done
}

# Ввод текста с подсказкой
reading() {
    local prompt="$1"
    local var_name="$2"
    local input
    read -e -p "$(echo -e "${YELLOW}$prompt${NC} ")" input
    eval "$var_name='$input'"
}

# ═══════════════════════════════════════════════
# ПРОВЕРКИ СИСТЕМЫ
# ═══════════════════════════════════════════════
check_root() {
    if [ "$(id -u)" -ne 0 ]; then
        print_error "Скрипт нужно запускать с правами root"
        exit 1
    fi
}

check_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        case "$ID" in
            debian)
                if [[ "$VERSION_ID" != "11" && "$VERSION_ID" != "12" ]]; then
                    print_error "Поддержка только Debian 11/12 и Ubuntu 22.04/24.04"
                    exit 1
                fi
                ;;
            ubuntu)
                if [[ "$VERSION_ID" != "22.04" && "$VERSION_ID" != "24.04" ]]; then
                    print_error "Поддержка только Debian 11/12 и Ubuntu 22.04/24.04"
                    exit 1
                fi
                ;;
            *)
                print_error "Поддержка только Debian 11/12 и Ubuntu 22.04/24.04"
                exit 1
                ;;
        esac
    else
        print_error "Не удалось определить ОС"
        exit 1
    fi
}

# ═══════════════════════════════════════════════
# УСТАНОВКА ПАКЕТОВ
# ═══════════════════════════════════════════════
install_packages() {
    (
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -qq >/dev/null 2>&1
        apt-get install -y -qq ca-certificates curl jq ufw wget gnupg unzip nano dialog git \
            certbot python3-certbot-dns-cloudflare unattended-upgrades locales dnsutils \
            coreutils grep gawk >/dev/null 2>&1

        # Cron
        if ! dpkg -l | grep -q '^ii.*cron '; then
            apt-get install -y -qq cron >/dev/null 2>&1
        fi
        systemctl start cron 2>/dev/null || true
        systemctl enable cron 2>/dev/null || true

        # Docker
        if ! command -v docker >/dev/null 2>&1 || ! docker info >/dev/null 2>&1; then
            curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
            sh /tmp/get-docker.sh >/dev/null 2>&1
            rm -f /tmp/get-docker.sh
        fi
        systemctl start docker 2>/dev/null || true
        systemctl enable docker 2>/dev/null || true

        # BBR
        if ! sysctl net.ipv4.tcp_congestion_control 2>/dev/null | grep -q bbr; then
            echo "net.core.default_qdisc=fq" >> /etc/sysctl.conf
            echo "net.ipv4.tcp_congestion_control=bbr" >> /etc/sysctl.conf
            sysctl -p >/dev/null 2>&1
        fi

        # UFW
        ufw default deny incoming >/dev/null 2>&1
        ufw default allow outgoing >/dev/null 2>&1
        ufw allow 22/tcp >/dev/null 2>&1
        ufw allow 443/tcp >/dev/null 2>&1
        echo "y" | ufw enable >/dev/null 2>&1

        # IPv6 disable
        sysctl -w net.ipv6.conf.all.disable_ipv6=1 >/dev/null 2>&1
        sysctl -w net.ipv6.conf.default.disable_ipv6=1 >/dev/null 2>&1
        if ! grep -q "net.ipv6.conf.all.disable_ipv6" /etc/sysctl.conf; then
            echo "net.ipv6.conf.all.disable_ipv6=1" >> /etc/sysctl.conf
            echo "net.ipv6.conf.default.disable_ipv6=1" >> /etc/sysctl.conf
        fi

        # Locales
        sed -i '/^#.*en_US.UTF-8/s/^#//' /etc/locale.gen 2>/dev/null || true
        locale-gen >/dev/null 2>&1 || true

        touch "${DIR_REMNAWAVE}install_packages"
    ) &
    show_spinner "Установка необходимых пакетов"
}

# ═══════════════════════════════════════════════
# ГЕНЕРАТОРЫ
# ═══════════════════════════════════════════════
generate_password() {
    openssl rand -base64 48 | tr -dc 'a-zA-Z0-9!@#$%' | head -c 24
}

generate_username() {
    openssl rand -base64 12 | tr -dc 'a-zA-Z' | head -c 8
}

generate_secret() {
    openssl rand -base64 48 | tr -dc 'a-zA-Z0-9' | head -c 64
}

generate_webhook_secret() {
    openssl rand -hex 32
}

generate_admin_password() {
    # Генерация пароля минимум 24 символа с заглавными, строчными буквами и цифрами
    local upper=$(tr -dc 'A-Z' < /dev/urandom | head -c 8)
    local lower=$(tr -dc 'a-z' < /dev/urandom | head -c 8)
    local digits=$(tr -dc '0-9' < /dev/urandom | head -c 8)
    # Перемешиваем и добавляем ещё символов для длины
    echo "${upper}${lower}${digits}" | fold -w1 | shuf | tr -d '\n' && tr -dc 'a-zA-Z0-9' < /dev/urandom | head -c 8
}

generate_admin_username() {
    # Генерация логина из случайного слова + цифр
    echo "admin$(openssl rand -hex 4)"
}

# ═══════════════════════════════════════════════
# РАБОТА С ДОМЕНАМИ
# ═══════════════════════════════════════════════
extract_domain() {
    local full_domain="$1"
    local parts
    parts=$(echo "$full_domain" | tr '.' '\n' | wc -l)
    if [ "$parts" -gt 2 ]; then
        echo "$full_domain" | cut -d'.' -f2-
    else
        echo "$full_domain"
    fi
}

get_server_ip() {
    curl -s4 ifconfig.me 2>/dev/null || curl -s4 icanhazip.com 2>/dev/null || echo ""
}

check_domain() {
    local domain="$1"
    local check_ip="${2:-true}"
    local server_ip
    server_ip=$(get_server_ip)

    local domain_ip
    domain_ip=$(dig +short "$domain" A 2>/dev/null | head -1)

    if [ -z "$domain_ip" ]; then
        print_error "Не удалось определить IP для домена $domain"
        return 1
    fi

    if [ "$check_ip" = true ] && [ "$domain_ip" != "$server_ip" ]; then
        print_error "Домен $domain ($domain_ip) не указывает на этот сервер ($server_ip)"
        echo -e "${YELLOW}Убедитесь что DNS записи настроены правильно (DNS Only, без прокси Cloudflare)${NC}"
        echo
        local confirm
        read -e -p "$(echo -e "${YELLOW}Продолжить всё равно? [y/N]: ${NC}")" confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            return 2
        fi
    fi
    return 0
}

# ═══════════════════════════════════════════════
# СЕРТИФИКАТЫ
# ═══════════════════════════════════════════════
handle_certificates() {
    local -n domains_ref=$1
    local cert_method="$2"
    local email="$3"

    for domain in "${!domains_ref[@]}"; do
        local base_domain
        base_domain=$(extract_domain "$domain")

        # Проверяем наличие сертификата
        if [ -d "/etc/letsencrypt/live/$domain" ] || [ -d "/etc/letsencrypt/live/$base_domain" ]; then
            print_success "Сертификат для $domain уже существует"
            continue
        fi

        case "$cert_method" in
            1)
                # Cloudflare DNS-01 (wildcard)
                get_cert_cloudflare "$base_domain" "$email"
                ;;
            2)
                # ACME HTTP-01
                get_cert_acme "$domain" "$email"
                ;;
            *)
                print_error "Неизвестный метод сертификации"
                return 1
                ;;
        esac
    done
}

get_cert_cloudflare() {
    local domain="$1"
    local email="$2"

    if [ ! -f "/etc/letsencrypt/cloudflare.ini" ]; then
        print_error "Файл /etc/letsencrypt/cloudflare.ini не найден"
        return 1
    fi

    (
        certbot certonly --dns-cloudflare \
            --dns-cloudflare-credentials /etc/letsencrypt/cloudflare.ini \
            --dns-cloudflare-propagation-seconds 30 \
            -d "$domain" -d "*.$domain" \
            --email "$email" --agree-tos --non-interactive \
            --key-type ecdsa >/dev/null 2>&1
    ) &
    show_spinner "Получение wildcard сертификата для *.$domain"

    # Добавляем cron для обновления
    local cron_rule="0 3 * * * certbot renew --quiet --deploy-hook 'cd /opt/remnawave && docker compose restart remnawave-nginx' 2>/dev/null"
    if ! crontab -l 2>/dev/null | grep -q "certbot renew"; then
        (crontab -l 2>/dev/null; echo "$cron_rule") | crontab -
    fi
}

get_cert_acme() {
    local domain="$1"
    local email="$2"

    (
        ufw allow 80/tcp >/dev/null 2>&1
        certbot certonly --standalone \
            -d "$domain" \
            --email "$email" --agree-tos --non-interactive \
            --http-01-port 80 \
            --key-type ecdsa >/dev/null 2>&1
        ufw delete allow 80/tcp >/dev/null 2>&1
        ufw reload >/dev/null 2>&1
    ) &
    show_spinner "Получение сертификата для $domain"

    local cron_rule="0 3 * * * certbot renew --quiet --deploy-hook 'cd /opt/remnawave && docker compose restart remnawave-nginx' 2>/dev/null"
    if ! crontab -l 2>/dev/null | grep -q "certbot renew"; then
        (crontab -l 2>/dev/null; echo "$cron_rule") | crontab -
    fi
}

setup_cloudflare_credentials() {
    echo
    reading "Введите Cloudflare API Token:" CF_TOKEN

    # Проверяем токен
    local check
    check=$(curl -s -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" \
        -H "Authorization: Bearer $CF_TOKEN" | jq -r '.success' 2>/dev/null)

    if [ "$check" != "true" ]; then
        print_error "Cloudflare API Token невалиден"
        return 1
    fi
    print_success "Cloudflare API Token подтверждён"

    mkdir -p /etc/letsencrypt
    cat > /etc/letsencrypt/cloudflare.ini <<EOF
dns_cloudflare_api_token = $CF_TOKEN
EOF
    chmod 600 /etc/letsencrypt/cloudflare.ini
}

# ═══════════════════════════════════════════════
# API ФУНКЦИИ (Remnawave Panel)
# ═══════════════════════════════════════════════
make_api_request() {
    local method=$1
    local url=$2
    local token=$3
    local data=$4

    local headers=(
        -H "Authorization: Bearer $token"
        -H "Content-Type: application/json"
        -H "X-Forwarded-For: 127.0.0.1"
        -H "X-Forwarded-Proto: https"
        -H "X-Remnawave-Client-Type: browser"
    )

    if [ -n "$data" ]; then
        curl -s -X "$method" "http://$url" "${headers[@]}" -d "$data"
    else
        curl -s -X "$method" "http://$url" "${headers[@]}"
    fi
}

register_remnawave() {
    local domain_url=$1
    local username=$2
    local password=$3

    local register_data='{"username":"'"$username"'","password":"'"$password"'"}'
    local response
    response=$(curl -s -X POST "http://$domain_url/api/auth/register" \
        -H "Content-Type: application/json" \
        -H "X-Forwarded-For: 127.0.0.1" \
        -H "X-Forwarded-Proto: https" \
        -d "$register_data")

    local token
    token=$(echo "$response" | jq -r '.response.accessToken // empty' 2>/dev/null)

    if [ -z "$token" ]; then
        # Попытка логина если уже зарегистрирован
        local login_data='{"username":"'"$username"'","password":"'"$password"'"}'
        response=$(curl -s -X POST "http://$domain_url/api/auth/login" \
            -H "Content-Type: application/json" \
            -H "X-Forwarded-For: 127.0.0.1" \
            -H "X-Forwarded-Proto: https" \
            -d "$login_data")
        token=$(echo "$response" | jq -r '.response.accessToken // empty' 2>/dev/null)
    fi

    echo "$token"
}

get_public_key() {
    local domain_url=$1
    local token=$2
    local target_dir=$3

    local response
    response=$(make_api_request "GET" "$domain_url/api/keygen" "$token")
    local pubkey
    pubkey=$(echo "$response" | jq -r '.response.pubKey // empty' 2>/dev/null)

    if [ -n "$pubkey" ]; then
        sed -i "s|SECRET_KEY=.*|SECRET_KEY=\"$pubkey\"|" "$target_dir/docker-compose.yml" 2>/dev/null || true
    fi
}

generate_xray_keys() {
    local domain_url=$1
    local token=$2

    local response
    response=$(make_api_request "GET" "$domain_url/api/system/tools/x25519/generate" "$token")
    local private_key
    private_key=$(echo "$response" | jq -r '.response.keypairs[0].privateKey // empty' 2>/dev/null)

    if [ -z "$private_key" ] || [ "$private_key" = "null" ]; then
        # Fallback — возможно другая версия API
        private_key=$(echo "$response" | jq -r '.response.privateKey // empty' 2>/dev/null)
    fi

    echo "$private_key"
}

create_config_profile() {
    local domain_url=$1
    local token=$2
    local name=$3
    local domain=$4
    local private_key=$5
    local inbound_tag="${6:-Steal}"

    local short_id
    short_id=$(openssl rand -hex 8)

    local request_body
    request_body=$(jq -n --arg name "$name" --arg domain "$domain" \
        --arg private_key "$private_key" --arg short_id "$short_id" \
        --arg inbound_tag "$inbound_tag" '{
        name: $name,
        config: {
            log: { loglevel: "warning" },
            dns: {
                queryStrategy: "UseIPv4",
                servers: [{ address: "https://dns.google/dns-query", skipFallback: false }]
            },
            inbounds: [{
                tag: $inbound_tag,
                port: 443,
                protocol: "vless",
                settings: { clients: [], decryption: "none" },
                sniffing: { enabled: true, destOverride: ["http", "tls", "quic"] },
                streamSettings: {
                    network: "tcp",
                    security: "reality",
                    realitySettings: {
                        show: false,
                        xver: 1,
                        dest: "/dev/shm/nginx.sock",
                        spiderX: "",
                        shortIds: [$short_id],
                        privateKey: $private_key,
                        serverNames: [$domain]
                    }
                }
            }],
            outbounds: [
                { tag: "DIRECT", protocol: "freedom" },
                { tag: "BLOCK", protocol: "blackhole" }
            ],
            routing: {
                rules: [
                    { ip: ["geoip:private"], type: "field", outboundTag: "BLOCK" },
                    { type: "field", protocol: ["bittorrent"], outboundTag: "BLOCK" }
                ]
            }
        }
    }')

    local response
    response=$(make_api_request "POST" "$domain_url/api/config-profiles" "$token" "$request_body")

    local config_uuid
    config_uuid=$(echo "$response" | jq -r '.response.uuid // empty' 2>/dev/null)
    local inbound_uuid
    inbound_uuid=$(echo "$response" | jq -r '.response.inbounds[0].uuid // empty' 2>/dev/null)

    if [ -z "$config_uuid" ] || [ "$config_uuid" = "null" ] || \
       [ -z "$inbound_uuid" ] || [ "$inbound_uuid" = "null" ]; then
        echo "ERROR" >&2
        return 1
    fi

    echo "$config_uuid $inbound_uuid"
}

delete_config_profile() {
    local domain_url=$1
    local token=$2

    local response
    response=$(make_api_request "GET" "$domain_url/api/config-profiles" "$token")

    local config_uuids
    config_uuids=$(echo "$response" | jq -r '.response.configProfiles[].uuid // empty' 2>/dev/null)

    if [ -n "$config_uuids" ]; then
        while IFS= read -r uuid; do
            [ -z "$uuid" ] && continue
            make_api_request "DELETE" "$domain_url/api/config-profiles/$uuid" "$token" >/dev/null 2>&1
        done <<< "$config_uuids"
    fi
}

create_node() {
    local domain_url=$1
    local token=$2
    local config_profile_uuid=$3
    local inbound_uuid=$4
    local node_address="${5:-172.30.0.1}"
    local node_name="${6:-Steal}"

    local request_body
    request_body=$(jq -n --arg name "$node_name" --arg address "$node_address" \
        --arg config_uuid "$config_profile_uuid" --arg inbound "$inbound_uuid" '{
        name: $name,
        address: $address,
        port: 2222,
        configProfile: {
            activeConfigProfileUuid: $config_uuid,
            activeInbounds: [$inbound]
        },
        isTrafficTrackingActive: false,
        trafficLimitBytes: 0,
        notifyPercent: 0,
        trafficResetDay: 31,
        excludedInbounds: [],
        countryCode: "XX",
        consumptionMultiplier: 1.0
    }')

    local response
    response=$(make_api_request "POST" "$domain_url/api/nodes" "$token" "$request_body")

    if echo "$response" | jq -e '.response.uuid' >/dev/null 2>&1; then
        return 0
    else
        echo "ERROR: $response" >&2
        return 1
    fi
}

create_host() {
    local domain_url=$1
    local token=$2
    local config_uuid=$3
    local inbound_uuid=$4
    local remark=$5
    local address=$6

    local request_body
    request_body=$(jq -n --arg config_uuid "$config_uuid" --arg inbound_uuid "$inbound_uuid" \
        --arg remark "$remark" --arg address "$address" '{
        inbound: {
            configProfileUuid: $config_uuid,
            configProfileInboundUuid: $inbound_uuid
        },
        remark: $remark,
        address: $address,
        port: 443,
        path: "",
        sni: $address,
        host: "",
        alpn: null,
        fingerprint: "chrome",
        allowInsecure: false,
        isDisabled: false,
        securityLayer: "DEFAULT"
    }')

    make_api_request "POST" "$domain_url/api/hosts" "$token" "$request_body" >/dev/null
}

get_default_squad() {
    local domain_url=$1
    local token=$2

    local response
    response=$(make_api_request "GET" "$domain_url/api/internal-squads" "$token")
    echo "$response" | jq -r '.response.internalSquads[].uuid // empty' 2>/dev/null
}

update_squad() {
    local domain_url=$1
    local token=$2
    local squad_uuid=$3
    local inbound_uuid=$4

    local current
    current=$(make_api_request "GET" "$domain_url/api/internal-squads" "$token")

    # Получаем текущие inbounds сквада
    local current_inbounds
    current_inbounds=$(echo "$current" | jq -r --arg uuid "$squad_uuid" \
        '[.response.internalSquads[] | select(.uuid == $uuid) | .inbounds[].uuid] // []' 2>/dev/null)

    # Добавляем новый inbound к существующим
    local inbounds_array
    inbounds_array=$(echo "$current_inbounds" | jq --arg inbound "$inbound_uuid" \
        '. + [$inbound] | unique | map({uuid: .})' 2>/dev/null)

    local request_body
    request_body=$(jq -n --arg uuid "$squad_uuid" --argjson inbounds "$inbounds_array" '{
        uuid: $uuid,
        inbounds: $inbounds
    }')

    make_api_request "PATCH" "$domain_url/api/internal-squads" "$token" "$request_body" >/dev/null
}

create_api_token() {
    local domain_url=$1
    local token=$2
    local target_dir=${3:-/opt/remnawave}

    local request_body='{"tokenName":"subscription-page"}'
    local response
    response=$(make_api_request "POST" "$domain_url/api/tokens" "$token" "$request_body")

    local api_token
    api_token=$(echo "$response" | jq -r '.response.token // empty' 2>/dev/null)

    if [ -z "$api_token" ] || [ "$api_token" = "null" ]; then
        print_error "Не удалось создать API токен: $(echo "$response" | jq -r '.message // "Unknown error"')"
        return 1
    fi

    sed -i "s|REMNAWAVE_API_TOKEN=.*|REMNAWAVE_API_TOKEN=$api_token|" "$target_dir/docker-compose.yml"
    print_success "API токен создан и добавлен в docker-compose.yml"
}

# ═══════════════════════════════════════════════
# ШАБЛОНЫ SELFSTEAL
# ═══════════════════════════════════════════════
randomhtml() {
    # Массив шаблонов с названиями: "URL|Название"
    local templates=(
        "https://github.com/eGamesAPI/simple-web-templates/archive/refs/heads/main.zip|Простые веб-шаблоны"
        "https://github.com/eGamesAPI/sni-templates/archive/refs/heads/main.zip|SNI маскировка"
        "https://github.com/eGamesAPI/nothing-sni/archive/refs/heads/main.zip|Минималистичный стиль"
        "https://github.com/ColorlibHQ/AdminLTE/archive/refs/heads/master.zip|Админ панель"
        "https://github.com/creativetimofficial/material-dashboard/archive/refs/heads/master.zip|Material дизайн"
        "https://github.com/puikinsh/Adminator-admin-dashboard/archive/refs/heads/master.zip|Современный дашборд"
        "https://github.com/themefisher/small-apps-free-app-landing-page-template/archive/refs/heads/master.zip|Лендинг приложения"
        "https://github.com/leroyg/html5up-paradigm-shift/archive/refs/heads/master.zip|HTML5 стиль"
        "https://github.com/startbootstrap/startbootstrap-agency/archive/refs/heads/master.zip|Корпоративный стиль"
        "https://github.com/thomaspark/bootswatch/archive/refs/heads/master.zip|Bootstrap темы"
    )

    local random_index=$((RANDOM % ${#templates[@]}))
    local selected="${templates[$random_index]}"
    local template_url="${selected%%|*}"
    local template_name="${selected##*|}"

    echo -e "${BLUE}➜${NC}  Выбран шаблон: ${GREEN}${template_name}${NC}"

    (
        local tmp_dir
        tmp_dir=$(mktemp -d)
        cd "$tmp_dir"

        wget -q "$template_url" -O template.zip 2>/dev/null
        unzip -q template.zip 2>/dev/null

        local extracted_dir
        extracted_dir=$(find . -maxdepth 1 -type d ! -name '.' | head -1)

        if [ -d "$extracted_dir" ]; then
            local dirs
            dirs=($(find "$extracted_dir" -mindepth 1 -maxdepth 1 -type d 2>/dev/null))
            if [ ${#dirs[@]} -gt 0 ]; then
                local random_dir="${dirs[$((RANDOM % ${#dirs[@]}))]}"
                local subtemplate_name=$(basename "$random_dir")
                rm -rf /var/www/html/*
                cp -r "$random_dir"/* /var/www/html/ 2>/dev/null || true
                echo "$template_name ($subtemplate_name)" > /var/www/.current_template
            else
                # Если нет подпапок, используем весь контент
                rm -rf /var/www/html/*
                cp -r "$extracted_dir"/* /var/www/html/ 2>/dev/null || true
                echo "$template_name" > /var/www/.current_template
            fi
        fi

        rm -rf "$tmp_dir"
    ) &
    show_spinner "Установка шаблона: ${template_name}"
    
    # Выводим информацию после установки
    if [ -f /var/www/.current_template ]; then
        local installed=$(cat /var/www/.current_template)
        echo -e "${GREEN}✅${NC} Установлен: ${WHITE}${installed}${NC}"
    fi
}

# ═══════════════════════════════════════════════
# ГЕНЕРАЦИЯ .ENV
# ═══════════════════════════════════════════════
generate_env_file() {
    local panel_domain=$1
    local sub_domain=$2

    local jwt_auth_secret
    jwt_auth_secret=$(generate_secret)
    local jwt_api_secret
    jwt_api_secret=$(generate_secret)
    local webhook_secret
    webhook_secret=$(generate_webhook_secret)
    local metrics_user
    metrics_user=$(generate_username)
    local metrics_pass
    metrics_pass=$(generate_password)

    cat > /opt/remnawave/.env <<EOL
### APP ###
APP_PORT=3000
METRICS_PORT=3001

### API ###
# Possible values: max (start instances on all cores), number (start instances on number of cores), -1 (start instances on all cores - 1)
# !!! Do not set this value more than physical cores count in your machine !!!
# Review documentation: https://remna.st/docs/install/environment-variables#scaling-api
API_INSTANCES=1

### DATABASE ###
# FORMAT: postgresql://{user}:{password}@{host}:{port}/{database}
DATABASE_URL="postgresql://postgres:postgres@remnawave-db:5432/postgres"

### REDIS ###
REDIS_HOST=remnawave-redis
REDIS_PORT=6379

### JWT ###
JWT_AUTH_SECRET=$jwt_auth_secret
JWT_API_TOKENS_SECRET=$jwt_api_secret

# Set the session idle timeout in the panel to avoid daily logins.
# Value in hours: 12–168
JWT_AUTH_LIFETIME=168

### TELEGRAM NOTIFICATIONS ###
IS_TELEGRAM_NOTIFICATIONS_ENABLED=false
TELEGRAM_BOT_TOKEN=change_me
TELEGRAM_NOTIFY_USERS_CHAT_ID=change_me
TELEGRAM_NOTIFY_NODES_CHAT_ID=change_me
TELEGRAM_NOTIFY_CRM_CHAT_ID=change_me

# Optional
# Only set if you want to use topics
TELEGRAM_NOTIFY_USERS_THREAD_ID=
TELEGRAM_NOTIFY_NODES_THREAD_ID=
TELEGRAM_NOTIFY_CRM_THREAD_ID=

### FRONT_END ###
# Used by CORS, you can leave it as * or place your domain there
FRONT_END_DOMAIN=$panel_domain

### SUBSCRIPTION PUBLIC DOMAIN ###
### DOMAIN, WITHOUT HTTP/HTTPS, DO NOT ADD / AT THE END ###
### Used in "profile-web-page-url" response header and in UI/API ###
### Review documentation: https://remna.st/docs/install/environment-variables#domains
SUB_PUBLIC_DOMAIN=$sub_domain

### If CUSTOM_SUB_PREFIX is set in @remnawave/subscription-page, append the same path to SUB_PUBLIC_DOMAIN. Example: SUB_PUBLIC_DOMAIN=sub-page.example.com/sub ###

### SWAGGER ###
SWAGGER_PATH=/docs
SCALAR_PATH=/scalar
IS_DOCS_ENABLED=false

### PROMETHEUS ###
### Metrics are available at /api/metrics
METRICS_USER=$metrics_user
METRICS_PASS=$metrics_pass

### Webhook configuration
### Enable webhook notifications (true/false, defaults to false if not set or empty)
WEBHOOK_ENABLED=false
### Webhook URL to send notifications to (can specify multiple URLs separated by commas if needed)
### Only http:// or https:// are allowed.
WEBHOOK_URL=https://your-webhook-url.com/endpoint
### This secret is used to sign the webhook payload, must be exact 64 characters. Only a-z, 0-9, A-Z are allowed.
WEBHOOK_SECRET_HEADER=$webhook_secret

### Bandwidth usage reached notifications
BANDWIDTH_USAGE_NOTIFICATIONS_ENABLED=false
# Only in ASC order (example: [60, 80]), must be valid array of integer(min: 25, max: 95) numbers. No more than 5 values.
BANDWIDTH_USAGE_NOTIFICATIONS_THRESHOLD=[60, 80]

### CLOUDFLARE ###
# USED ONLY FOR docker-compose-prod-with-cf.yml
# NOT USED BY THE APP ITSELF
CLOUDFLARE_TOKEN=ey...

### Database ###
### For Postgres Docker container ###
# NOT USED BY THE APP ITSELF
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=postgres
EOL
}

# ═══════════════════════════════════════════════
# ГЕНЕРАЦИЯ DOCKER-COMPOSE
# ═══════════════════════════════════════════════
generate_docker_compose_full() {
    local panel_cert_domain=$1
    local sub_cert_domain=$2
    local node_cert_domain=$3

    cat > /opt/remnawave/docker-compose.yml <<'COMPOSE_HEAD'
services:
  remnawave-db:
    image: postgres:17
    container_name: remnawave-db
    hostname: remnawave-db
    restart: always
    ulimits:
      nofile:
        soft: 1048576
        hard: 1048576
    env_file:
      - .env
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres
      - POSTGRES_DB=postgres
    ports:
      - '127.0.0.1:6767:5432'
    volumes:
      - remnawave-db-data:/var/lib/postgresql/data
    networks:
      - remnawave-network
    healthcheck:
      test: ['CMD-SHELL', 'pg_isready -U postgres -d postgres']
      interval: 3s
      timeout: 10s
      retries: 3
    logging:
      driver: 'json-file'
      options:
        max-size: '30m'
        max-file: '5'

  remnawave:
    image: remnawave/backend:2
    container_name: remnawave
    hostname: remnawave
    restart: always
    ulimits:
      nofile:
        soft: 1048576
        hard: 1048576
    env_file:
      - .env
    ports:
      - '127.0.0.1:3000:${APP_PORT:-3000}'
      - '127.0.0.1:3001:${METRICS_PORT:-3001}'
    networks:
      - remnawave-network
    healthcheck:
      test: ['CMD-SHELL', 'curl -f http://localhost:${METRICS_PORT:-3001}/health']
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 30s
    depends_on:
      remnawave-db:
        condition: service_healthy
      remnawave-redis:
        condition: service_healthy
    logging:
      driver: 'json-file'
      options:
        max-size: '30m'
        max-file: '5'

  remnawave-redis:
    image: valkey/valkey:9.0.0-alpine
    container_name: remnawave-redis
    hostname: remnawave-redis
    restart: always
    ulimits:
      nofile:
        soft: 1048576
        hard: 1048576
    networks:
      - remnawave-network
    command: >
      valkey-server
      --save ""
      --appendonly no
      --maxmemory-policy noeviction
      --loglevel warning
    healthcheck:
      test: ['CMD', 'valkey-cli', 'ping']
      interval: 3s
      timeout: 10s
      retries: 3
    logging:
      driver: 'json-file'
      options:
        max-size: '30m'
        max-file: '5'

  remnawave-nginx:
    image: nginx:1.28
    container_name: remnawave-nginx
    hostname: remnawave-nginx
    network_mode: host
    restart: always
    ulimits:
      nofile:
        soft: 1048576
        hard: 1048576
    volumes:
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
COMPOSE_HEAD

    # Монтируем сертификаты для каждого домена
    for cert in "$panel_cert_domain" "$sub_cert_domain" "$node_cert_domain"; do
        cat >> /opt/remnawave/docker-compose.yml <<COMPOSE_CERT
      - /etc/letsencrypt/live/$cert/fullchain.pem:/etc/nginx/ssl/$cert/fullchain.pem:ro
      - /etc/letsencrypt/live/$cert/privkey.pem:/etc/nginx/ssl/$cert/privkey.pem:ro
COMPOSE_CERT
    done

    cat >> /opt/remnawave/docker-compose.yml <<'COMPOSE_TAIL'
      - /dev/shm:/dev/shm:rw
      - /var/www/html:/var/www/html:ro
    command: sh -c 'rm -f /dev/shm/nginx.sock && exec nginx -g "daemon off;"'
    depends_on:
      - remnawave
      - remnawave-subscription-page
    logging:
      driver: 'json-file'
      options:
        max-size: '30m'
        max-file: '5'

  remnawave-subscription-page:
    image: remnawave/subscription-page:latest
    container_name: remnawave-subscription-page
    hostname: remnawave-subscription-page
    restart: always
    ulimits:
      nofile:
        soft: 1048576
        hard: 1048576
    depends_on:
      remnawave:
        condition: service_healthy
    environment:
      - REMNAWAVE_PANEL_URL=http://remnawave:3000
      - APP_PORT=3010
      - REMNAWAVE_API_TOKEN=$api_token
    ports:
      - '127.0.0.1:3010:3010'
    networks:
      - remnawave-network
    logging:
      driver: 'json-file'
      options:
        max-size: '30m'
        max-file: '5'

  remnanode:
    image: remnawave/node:latest
    container_name: remnanode
    hostname: remnanode
    restart: always
    ulimits:
      nofile:
        soft: 1048576
        hard: 1048576
    network_mode: host
    environment:
      - NODE_PORT=2222
      - SECRET_KEY="PUBLIC KEY FROM REMNAWAVE-PANEL"
    volumes:
      - /dev/shm:/dev/shm:rw
    logging:
      driver: 'json-file'
      options:
        max-size: '30m'
        max-file: '5'

networks:
  remnawave-network:
    name: remnawave-network
    driver: bridge
    ipam:
      config:
        - subnet: 172.30.0.0/16
    external: false

volumes:
  remnawave-db-data:
    driver: local
    external: false
    name: remnawave-db-data
COMPOSE_TAIL
}

generate_docker_compose_panel() {
    local panel_cert_domain=$1
    local sub_cert_domain=$2

    cat > /opt/remnawave/docker-compose.yml <<'COMPOSE_TAIL'
services:
  remnawave-db:
    image: postgres:17
    container_name: remnawave-db
    hostname: remnawave-db
    restart: always
    ulimits:
      nofile:
        soft: 1048576
        hard: 1048576
    env_file:
      - .env
    environment:
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgres
      - POSTGRES_DB=postgres
    ports:
      - '127.0.0.1:6767:5432'
    volumes:
      - remnawave-db-data:/var/lib/postgresql/data
    networks:
      - remnawave-network
    healthcheck:
      test: ['CMD-SHELL', 'pg_isready -U postgres -d postgres']
      interval: 3s
      timeout: 10s
      retries: 3
    logging:
      driver: 'json-file'
      options:
        max-size: '30m'
        max-file: '5'

  remnawave:
    image: remnawave/backend:2
    container_name: remnawave
    hostname: remnawave
    restart: always
    ulimits:
      nofile:
        soft: 1048576
        hard: 1048576
    env_file:
      - .env
    ports:
      - '127.0.0.1:3000:${APP_PORT:-3000}'
      - '127.0.0.1:3001:${METRICS_PORT:-3001}'
    networks:
      - remnawave-network
    healthcheck:
      test: ['CMD-SHELL', 'curl -f http://localhost:${METRICS_PORT:-3001}/health']
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 30s
    depends_on:
      remnawave-db:
        condition: service_healthy
      remnawave-redis:
        condition: service_healthy
    logging:
      driver: 'json-file'
      options:
        max-size: '30m'
        max-file: '5'

  remnawave-redis:
    image: valkey/valkey:9.0.0-alpine
    container_name: remnawave-redis
    hostname: remnawave-redis
    restart: always
    ulimits:
      nofile:
        soft: 1048576
        hard: 1048576
    networks:
      - remnawave-network
    command: >
      valkey-server
      --save ""
      --appendonly no
      --maxmemory-policy noeviction
      --loglevel warning
    healthcheck:
      test: ['CMD', 'valkey-cli', 'ping']
      interval: 3s
      timeout: 10s
      retries: 3
    logging:
      driver: 'json-file'
      options:
        max-size: '30m'
        max-file: '5'

  remnawave-nginx:
    image: nginx:1.28
    container_name: remnawave-nginx
    hostname: remnawave-nginx
    restart: always
    ulimits:
      nofile:
        soft: 1048576
        hard: 1048576
    volumes:
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
      - /etc/letsencrypt:/etc/letsencrypt:ro
    network_mode: host
    depends_on:
      - remnawave
      - remnawave-subscription-page
    logging:
      driver: 'json-file'
      options:
        max-size: '30m'
        max-file: '5'

  remnawave-subscription-page:
    image: remnawave/subscription-page:latest
    container_name: remnawave-subscription-page
    hostname: remnawave-subscription-page
    restart: always
    ulimits:
      nofile:
        soft: 1048576
        hard: 1048576
    depends_on:
      remnawave:
        condition: service_healthy
    environment:
      - REMNAWAVE_PANEL_URL=http://remnawave:3000
      - APP_PORT=3010
      - REMNAWAVE_API_TOKEN=$api_token
    ports:
      - '127.0.0.1:3010:3010'
    networks:
      - remnawave-network
    logging:
      driver: 'json-file'
      options:
        max-size: '30m'
        max-file: '5'

networks:
  remnawave-network:
    name: remnawave-network
    driver: bridge
    external: false

volumes:
  remnawave-db-data:
    driver: local
    external: false
    name: remnawave-db-data
COMPOSE_TAIL
}

# ═══════════════════════════════════════════════
# ГЕНЕРАЦИЯ NGINX.CONF
# ═══════════════════════════════════════════════
generate_nginx_conf_full() {
    local panel_domain=$1
    local sub_domain=$2
    local selfsteal_domain=$3
    local panel_cert=$4
    local sub_cert=$5
    local node_cert=$6

    cat > /opt/remnawave/nginx.conf <<EOL
server_names_hash_bucket_size 64;

upstream remnawave {
    server 127.0.0.1:3000;
}

upstream json {
    server 127.0.0.1:3010;
}

map \$http_upgrade \$connection_upgrade {
    default upgrade;
    ""      close;
}

ssl_protocols TLSv1.2 TLSv1.3;
ssl_ecdh_curve X25519:prime256v1:secp384r1;
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-CHACHA20-POLY1305;
ssl_prefer_server_ciphers on;
ssl_session_timeout 1d;
ssl_session_cache shared:MozSSL:10m;
ssl_session_tickets off;

server {
    server_name $panel_domain;
    listen unix:/dev/shm/nginx.sock ssl proxy_protocol;
    http2 on;

    ssl_certificate "/etc/nginx/ssl/$panel_cert/fullchain.pem";
    ssl_certificate_key "/etc/nginx/ssl/$panel_cert/privkey.pem";
    ssl_trusted_certificate "/etc/nginx/ssl/$panel_cert/fullchain.pem";

    location / {
        proxy_http_version 1.1;
        proxy_pass http://remnawave;
        proxy_set_header Host \$host;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header X-Real-IP \$proxy_protocol_addr;
        proxy_set_header X-Forwarded-For \$proxy_protocol_addr;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}

server {
    server_name $sub_domain;
    listen unix:/dev/shm/nginx.sock ssl proxy_protocol;
    http2 on;

    ssl_certificate "/etc/nginx/ssl/$sub_cert/fullchain.pem";
    ssl_certificate_key "/etc/nginx/ssl/$sub_cert/privkey.pem";
    ssl_trusted_certificate "/etc/nginx/ssl/$sub_cert/fullchain.pem";

    location / {
        proxy_http_version 1.1;
        proxy_pass http://json;
        proxy_set_header Host \$host;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header X-Real-IP \$proxy_protocol_addr;
        proxy_set_header X-Forwarded-For \$proxy_protocol_addr;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        proxy_intercept_errors on;
        error_page 400 404 500 502 @redirect;
    }

    location @redirect {
        return 444;
    }
}

server {
    server_name $selfsteal_domain;
    listen unix:/dev/shm/nginx.sock ssl proxy_protocol;
    http2 on;

    ssl_certificate "/etc/nginx/ssl/$node_cert/fullchain.pem";
    ssl_certificate_key "/etc/nginx/ssl/$node_cert/privkey.pem";
    ssl_trusted_certificate "/etc/nginx/ssl/$node_cert/fullchain.pem";

    root /var/www/html;
    index index.html;
    add_header X-Robots-Tag "noindex, nofollow, noarchive, nosnippet, noimageindex" always;
}

server {
    listen unix:/dev/shm/nginx.sock ssl proxy_protocol default_server;
    server_name _;
    add_header X-Robots-Tag "noindex, nofollow, noarchive, nosnippet, noimageindex" always;
    ssl_reject_handshake on;
    return 444;
}
EOL
}

generate_nginx_conf_panel() {
    local panel_domain=$1
    local sub_domain=$2
    local panel_cert=$3
    local sub_cert=$4

    cat > /opt/remnawave/nginx.conf <<EOL
server_names_hash_bucket_size 64;

upstream remnawave {
    server 127.0.0.1:3000;
}

upstream json {
    server 127.0.0.1:3010;
}

map \$http_upgrade \$connection_upgrade {
    default upgrade;
    ""      close;
}

ssl_protocols TLSv1.2 TLSv1.3;
ssl_ecdh_curve X25519:prime256v1:secp384r1;
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-CHACHA20-POLY1305;
ssl_prefer_server_ciphers on;
ssl_session_timeout 1d;
ssl_session_cache shared:MozSSL:10m;
ssl_session_tickets off;

server {
    server_name $panel_domain;
    listen 443 ssl http2;
    listen [::]:443 ssl http2;

    ssl_certificate "/etc/letsencrypt/live/$panel_cert/fullchain.pem";
    ssl_certificate_key "/etc/letsencrypt/live/$panel_cert/privkey.pem";
    ssl_trusted_certificate "/etc/letsencrypt/live/$panel_cert/fullchain.pem";

    location / {
        proxy_http_version 1.1;
        proxy_pass http://remnawave;
        proxy_set_header Host \$host;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$remote_addr;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
}

server {
    server_name $sub_domain;
    listen 443 ssl http2;
    listen [::]:443 ssl http2;

    ssl_certificate "/etc/letsencrypt/live/$sub_cert/fullchain.pem";
    ssl_certificate_key "/etc/letsencrypt/live/$sub_cert/privkey.pem";
    ssl_trusted_certificate "/etc/letsencrypt/live/$sub_cert/fullchain.pem";

    location / {
        proxy_http_version 1.1;
        proxy_pass http://json;
        proxy_set_header Host \$host;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection \$connection_upgrade;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$remote_addr;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_set_header X-Forwarded-Port \$server_port;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
        proxy_intercept_errors on;
        error_page 400 404 500 502 @redirect;
    }

    location @redirect {
        return 444;
    }
}

server {
    listen 443 ssl default_server;
    server_name _;
    ssl_reject_handshake on;
}
EOL
}

generate_nginx_conf_node() {
    local selfsteal_domain=$1
    local node_cert=$2

    cat > /opt/remnawave/nginx.conf <<EOL
server_names_hash_bucket_size 64;

map \$http_upgrade \$connection_upgrade {
    default upgrade;
    ""      close;
}

ssl_protocols TLSv1.2 TLSv1.3;
ssl_ecdh_curve X25519:prime256v1:secp384r1;
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-CHACHA20-POLY1305;
ssl_prefer_server_ciphers on;
ssl_session_timeout 1d;
ssl_session_cache shared:MozSSL:10m;
ssl_session_tickets off;

server {
    server_name $selfsteal_domain;
    listen unix:/dev/shm/nginx.sock ssl proxy_protocol;
    http2 on;

    ssl_certificate "/etc/nginx/ssl/$node_cert/fullchain.pem";
    ssl_certificate_key "/etc/nginx/ssl/$node_cert/privkey.pem";
    ssl_trusted_certificate "/etc/nginx/ssl/$node_cert/fullchain.pem";

    root /var/www/html;
    index index.html;
    add_header X-Robots-Tag "noindex, nofollow, noarchive, nosnippet, noimageindex" always;
}

server {
    listen unix:/dev/shm/nginx.sock ssl proxy_protocol default_server;
    server_name _;
    add_header X-Robots-Tag "noindex, nofollow, noarchive, nosnippet, noimageindex" always;
    ssl_reject_handshake on;
    return 444;
}
EOL
}

# ═══════════════════════════════════════════════
# УСТАНОВКА: ПАНЕЛЬ + НОДА
# ═══════════════════════════════════════════════
installation_full() {
    clear
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${GREEN}   📦 УСТАНОВКА ПАНЕЛИ + НОДЫ${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo

    mkdir -p /opt/remnawave && cd /opt/remnawave
    mkdir -p /var/www/html

    # Домены
    reading "Домен панели (например panel.example.com):" PANEL_DOMAIN
    check_domain "$PANEL_DOMAIN" true || return

    reading "Домен подписки (например sub.example.com):" SUB_DOMAIN
    check_domain "$SUB_DOMAIN" true || return

    reading "Домен selfsteal/ноды (например node.example.com):" SELFSTEAL_DOMAIN
    check_domain "$SELFSTEAL_DOMAIN" true || return

    # Автогенерация учётных данных администратора
    echo
    echo -e "${YELLOW}👤 ГЕНЕРАЦИЯ УЧЁТНЫХ ДАННЫХ АДМИНИСТРАТОРА${NC}"
    local SUPERADMIN_USERNAME
    local SUPERADMIN_PASSWORD
    SUPERADMIN_USERNAME=$(generate_admin_username)
    SUPERADMIN_PASSWORD=$(generate_admin_password)
    
    echo -e "${DARKGRAY}Логин и пароль будут созданы автоматически и показаны в конце установки${NC}"

    # Название ноды
    echo
    local entity_name=""
    while true; do
        reading "Название ноды (3-20 символов, a-zA-Z0-9-):" entity_name
        if [[ "$entity_name" =~ ^[a-zA-Z0-9-]+$ ]]; then
            if [ ${#entity_name} -ge 3 ] && [ ${#entity_name} -le 20 ]; then
                break
            else
                print_error "Название должно быть от 3 до 20 символов"
            fi
        else
            print_error "Допустимы только символы: a-zA-Z0-9 и дефис"
        fi
    done

    # Сертификаты
    echo
    show_arrow_menu "🔐 МЕТОД ПОЛУЧЕНИЯ СЕРТИФИКАТОВ" \
        "☁️   Cloudflare DNS-01 (wildcard)" \
        "🌐  ACME HTTP-01 (Let's Encrypt)" \
        "❌  Назад"
    local cert_choice=$?

    case $cert_choice in
        0) CERT_METHOD=1 ;;
        1) CERT_METHOD=2 ;;
        2) return ;;
    esac

    reading "Email для Let's Encrypt:" LETSENCRYPT_EMAIL

    if [ "$CERT_METHOD" -eq 1 ]; then
        setup_cloudflare_credentials || return
    fi

    # Обработка сертификатов
    declare -A domains_to_check
    domains_to_check["$PANEL_DOMAIN"]=1
    domains_to_check["$SUB_DOMAIN"]=1
    domains_to_check["$SELFSTEAL_DOMAIN"]=1

    handle_certificates domains_to_check "$CERT_METHOD" "$LETSENCRYPT_EMAIL"

    # Определяем домены сертификатов
    local PANEL_CERT_DOMAIN SUB_CERT_DOMAIN NODE_CERT_DOMAIN
    if [ "$CERT_METHOD" -eq 1 ]; then
        PANEL_CERT_DOMAIN=$(extract_domain "$PANEL_DOMAIN")
        SUB_CERT_DOMAIN=$(extract_domain "$SUB_DOMAIN")
        NODE_CERT_DOMAIN=$(extract_domain "$SELFSTEAL_DOMAIN")
    else
        PANEL_CERT_DOMAIN="$PANEL_DOMAIN"
        SUB_CERT_DOMAIN="$SUB_DOMAIN"
        NODE_CERT_DOMAIN="$SELFSTEAL_DOMAIN"
    fi

    # Генерируем конфиги
    echo
    print_action "Генерация конфигурации..."

    (
        generate_env_file "$PANEL_DOMAIN" "$SUB_DOMAIN"
    ) &
    show_spinner "Создание .env файла"

    (
        generate_docker_compose_full "$PANEL_CERT_DOMAIN" "$SUB_CERT_DOMAIN" "$NODE_CERT_DOMAIN"
    ) &
    show_spinner "Создание docker-compose.yml"

    (
        generate_nginx_conf_full "$PANEL_DOMAIN" "$SUB_DOMAIN" "$SELFSTEAL_DOMAIN" \
            "$PANEL_CERT_DOMAIN" "$SUB_CERT_DOMAIN" "$NODE_CERT_DOMAIN"
    ) &
    show_spinner "Создание nginx.conf"

    # UFW для ноды
    (
        remnawave_network_subnet=172.30.0.0/16
        ufw allow from "$remnawave_network_subnet" to any port 2222 proto tcp >/dev/null 2>&1
    ) &
    show_spinner "Настройка файрвола"

    # Запуск
    echo
    print_action "Запуск сервисов..."

    (
        cd /opt/remnawave
        docker compose up -d >/dev/null 2>&1
    ) &
    show_spinner "Запуск Docker контейнеров"

    # Ожидание готовности
    show_spinner_timer 20 "Ожидание запуска Remnawave"

    local domain_url="127.0.0.1:3000"
    local target_dir="/opt/remnawave"

    show_spinner_until_ready "http://$domain_url/api/auth/status" "Проверка доступности API" 120
    if [ $? -ne 0 ]; then
        print_error "API не отвечает. Проверьте: docker compose -f /opt/remnawave/docker-compose.yml logs"
        return
    fi

    # ═══════════════════════════════════════════
    # АВТОНАСТРОЙКА: РЕГИСТРАЦИЯ И СОЗДАНИЕ НОДЫ
    # ═══════════════════════════════════════════
    echo
    print_action "Автонастройка панели и ноды..."

    # 1. Регистрация суперадмина → получение токена
    print_action "Регистрация администратора..."
    local token
    token=$(register_remnawave "$domain_url" "$SUPERADMIN_USERNAME" "$SUPERADMIN_PASSWORD")

    if [ -z "$token" ]; then
        print_error "Не удалось зарегистрироваться/авторизоваться в панели"
        print_error "Настройте ноду вручную через панель: https://$PANEL_DOMAIN"
        randomhtml
        echo
        echo -e "${BLUE}════════════════════════════════════════${NC}"
        echo -e "${GREEN}   ⚠️  УСТАНОВКА ЧАСТИЧНО ЗАВЕРШЕНА${NC}"
        echo -e "${BLUE}════════════════════════════════════════${NC}"
        echo
        echo -e "${WHITE}Панель:${NC}       https://$PANEL_DOMAIN"
        echo -e "${WHITE}Подписка:${NC}     https://$SUB_DOMAIN"
        echo -e "${WHITE}SelfSteal:${NC}    https://$SELFSTEAL_DOMAIN"
        echo
        echo -e "${YELLOW}Нода не настроена автоматически. Настройте вручную.${NC}"
        echo
        read -s -n 1 -p "$(echo -e "${DARKGRAY}Нажмите Enter для продолжения${NC}")"
        return
    fi
    print_success "Администратор зарегистрирован"

    # 2. Получение публичного ключа → SECRET_KEY для ноды
    print_action "Получение публичного ключа панели..."
    get_public_key "$domain_url" "$token" "$target_dir"
    print_success "Публичный ключ получен и записан в docker-compose"

    # 3. Генерация ключей x25519 (REALITY)
    print_action "Генерация REALITY ключей..."
    local private_key
    private_key=$(generate_xray_keys "$domain_url" "$token")

    if [ -z "$private_key" ]; then
        print_error "Не удалось сгенерировать REALITY ключи"
        return
    fi
    print_success "REALITY ключи сгенерированы"

    # 4. Удаление дефолтного config profile
    print_action "Удаление дефолтного конфиг-профиля..."
    delete_config_profile "$domain_url" "$token"
    print_success "Дефолтный конфиг-профиль удалён"

    # 5. Создание config profile с VLESS REALITY
    print_action "Создание конфиг-профиля ($entity_name)..."
    local config_result
    config_result=$(create_config_profile "$domain_url" "$token" "$entity_name" "$SELFSTEAL_DOMAIN" "$private_key" "$entity_name")

    local config_profile_uuid inbound_uuid
    read config_profile_uuid inbound_uuid <<< "$config_result"

    if [ -z "$config_profile_uuid" ] || [ "$config_profile_uuid" = "ERROR" ] || \
       [ -z "$inbound_uuid" ]; then
        print_error "Не удалось создать конфиг-профиль"
        return
    fi
    print_success "Конфиг-профиль создан"

    # 6. Создание ноды
    print_action "Создание ноды ($entity_name)..."
    create_node "$domain_url" "$token" "$config_profile_uuid" "$inbound_uuid" "172.30.0.1" "$entity_name"
    if [ $? -eq 0 ]; then
        print_success "Нода создана"
    else
        print_error "Не удалось создать ноду"
    fi

    # 7. Создание хоста
    print_action "Создание хоста ($SELFSTEAL_DOMAIN)..."
    create_host "$domain_url" "$token" "$config_profile_uuid" "$inbound_uuid" "$entity_name" "$SELFSTEAL_DOMAIN"
    print_success "Хост создан"

    # 8. Получение и обновление сквадов
    print_action "Настройка сквадов..."
    local squad_uuids
    squad_uuids=$(get_default_squad "$domain_url" "$token")

    if [ -n "$squad_uuids" ]; then
        while IFS= read -r squad_uuid; do
            [ -z "$squad_uuid" ] && continue
            update_squad "$domain_url" "$token" "$squad_uuid" "$inbound_uuid"
        done <<< "$squad_uuids"
        print_success "Сквады обновлены"
    else
        echo -e "${YELLOW}⚠️  Сквады не найдены (будут настроены при создании пользователей)${NC}"
    fi

    # 9. Создание API токена для subscription-page
    print_action "Создание API токена для страницы подписки..."
    create_api_token "$domain_url" "$token" "$target_dir"

    # 10. Перезапуск Docker Compose (с обновлённым docker-compose.yml)
    print_action "Перезапуск сервисов с обновлённой конфигурацией..."
    (
        cd /opt/remnawave
        docker compose down >/dev/null 2>&1
    ) &
    show_spinner "Остановка контейнеров"

    (
        cd /opt/remnawave
        docker compose up -d >/dev/null 2>&1
    ) &
    show_spinner "Запуск контейнеров"

    # 11. Шаблон selfsteal
    randomhtml

    # Ожидаем готовность после перезапуска
    show_spinner_timer 10 "Ожидание запуска сервисов"

    # Итог
    echo
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${GREEN}   🎉 УСТАНОВКА ЗАВЕРШЕНА!${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo
    echo -e "${WHITE}Панель:${NC}       https://$PANEL_DOMAIN"
    echo -e "${WHITE}Подписка:${NC}     https://$SUB_DOMAIN"
    echo -e "${WHITE}SelfSteal:${NC}    https://$SELFSTEAL_DOMAIN"
    echo
    echo -e "${YELLOW}👤 ДАННЫЕ АДМИНИСТРАТОРА:${NC}"
    echo -e "${WHITE}Логин:${NC}        $SUPERADMIN_USERNAME"
    echo -e "${WHITE}Пароль:${NC}        $SUPERADMIN_PASSWORD"
    echo
    echo -e "${GREEN}✅ Нода \"$entity_name\" настроена автоматически${NC}"
    echo -e "${GREEN}✅ API токен для страницы подписки создан${NC}"
    echo -e "${GREEN}✅ REALITY конфиг-профиль создан${NC}"
    echo
    read -s -n 1 -p "$(echo -e "${DARKGRAY}Нажмите Enter для продолжения${NC}")"
}

# ═══════════════════════════════════════════════
# УСТАНОВКА: ТОЛЬКО ПАНЕЛЬ
# ═══════════════════════════════════════════════
installation_panel() {
    clear
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${GREEN}   📦 УСТАНОВКА ТОЛЬКО ПАНЕЛИ${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo

    mkdir -p /opt/remnawave && cd /opt/remnawave

    reading "Домен панели (например panel.example.com):" PANEL_DOMAIN
    check_domain "$PANEL_DOMAIN" true || return

    reading "Домен подписки (например sub.example.com):" SUB_DOMAIN
    check_domain "$SUB_DOMAIN" true || return

    echo
    show_arrow_menu "🔐 МЕТОД ПОЛУЧЕНИЯ СЕРТИФИКАТОВ" \
        "☁️   Cloudflare DNS-01 (wildcard)" \
        "🌐  ACME HTTP-01 (Let's Encrypt)" \
        "❌  Назад"
    local cert_choice=$?

    case $cert_choice in
        0) CERT_METHOD=1 ;;
        1) CERT_METHOD=2 ;;
        2) return ;;
    esac

    reading "Email для Let's Encrypt:" LETSENCRYPT_EMAIL

    if [ "$CERT_METHOD" -eq 1 ]; then
        setup_cloudflare_credentials || return
    fi

    declare -A domains_to_check
    domains_to_check["$PANEL_DOMAIN"]=1
    domains_to_check["$SUB_DOMAIN"]=1
    handle_certificates domains_to_check "$CERT_METHOD" "$LETSENCRYPT_EMAIL"

    local PANEL_CERT_DOMAIN SUB_CERT_DOMAIN
    if [ "$CERT_METHOD" -eq 1 ]; then
        PANEL_CERT_DOMAIN=$(extract_domain "$PANEL_DOMAIN")
        SUB_CERT_DOMAIN=$(extract_domain "$SUB_DOMAIN")
    else
        PANEL_CERT_DOMAIN="$PANEL_DOMAIN"
        SUB_CERT_DOMAIN="$SUB_DOMAIN"
    fi

    (generate_env_file "$PANEL_DOMAIN" "$SUB_DOMAIN") &
    show_spinner "Создание .env файла"

    (generate_docker_compose_panel "$PANEL_CERT_DOMAIN" "$SUB_CERT_DOMAIN") &
    show_spinner "Создание docker-compose.yml"

    (generate_nginx_conf_panel "$PANEL_DOMAIN" "$SUB_DOMAIN" "$PANEL_CERT_DOMAIN" "$SUB_CERT_DOMAIN") &
    show_spinner "Создание nginx.conf"

    echo
    (
        cd /opt/remnawave
        docker compose up -d >/dev/null 2>&1
    ) &
    show_spinner "Запуск Docker контейнеров"

    show_spinner_timer 20 "Ожидание запуска Remnawave"

    local domain_url="127.0.0.1:3000"
    show_spinner_until_ready "http://$domain_url/api/auth/status" "Проверка доступности API" 120
    if [ $? -ne 0 ]; then
        print_error "API не отвечает"
        return
    fi

    echo
    print_action "Панель готова к использованию"

    echo
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${GREEN}   🎉 ПАНЕЛЬ УСТАНОВЛЕНА!${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo
    echo -e "${WHITE}Панель:${NC}       https://$PANEL_DOMAIN"
    echo -e "${WHITE}Подписка:${NC}     https://$SUB_DOMAIN"
    echo
    echo -e "${YELLOW}📝 Откройте панель и создайте свой аккаунт администратора${NC}"
    echo -e "${DARKGRAY}   При первом входе Remnawave попросит вас установить логин и пароль${NC}"
    echo
    read -s -n 1 -p "$(echo -e "${DARKGRAY}Нажмите Enter для продолжения${NC}")"
}

# ═══════════════════════════════════════════════
# УСТАНОВКА: ТОЛЬКО НОДА
# ═══════════════════════════════════════════════
installation_node() {
    clear
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${GREEN}   📦 УСТАНОВКА ТОЛЬКО НОДЫ${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo

    mkdir -p /opt/remnawave && cd /opt/remnawave
    mkdir -p /var/www/html

    reading "Домен selfsteal/ноды (например node.example.com):" SELFSTEAL_DOMAIN
    check_domain "$SELFSTEAL_DOMAIN" true || return

    local PANEL_IP
    while true; do
        reading "IP адрес сервера панели:" PANEL_IP
        if echo "$PANEL_IP" | grep -E '^([0-9]{1,3}\.){3}[0-9]{1,3}$' >/dev/null; then
            break
        fi
        print_error "Некорректный IP адрес"
    done

    echo -e "${YELLOW}Вставьте сертификат (SECRET_KEY) из панели и нажмите Enter дважды:${NC}"
    local CERTIFICATE=""
    while IFS= read -r line; do
        if [ -z "$line" ] && [ -n "$CERTIFICATE" ]; then
            break
        fi
        CERTIFICATE="$CERTIFICATE$line\n"
    done

    echo
    show_arrow_menu "🔐 МЕТОД ПОЛУЧЕНИЯ СЕРТИФИКАТОВ" \
        "☁️   Cloudflare DNS-01 (wildcard)" \
        "🌐  ACME HTTP-01 (Let's Encrypt)" \
        "❌  Назад"
    local cert_choice=$?

    case $cert_choice in
        0) CERT_METHOD=1 ;;
        1) CERT_METHOD=2 ;;
        2) return ;;
    esac

    reading "Email для Let's Encrypt:" LETSENCRYPT_EMAIL

    if [ "$CERT_METHOD" -eq 1 ]; then
        setup_cloudflare_credentials || return
    fi

    declare -A domains_to_check
    domains_to_check["$SELFSTEAL_DOMAIN"]=1
    handle_certificates domains_to_check "$CERT_METHOD" "$LETSENCRYPT_EMAIL"

    local NODE_CERT_DOMAIN
    if [ "$CERT_METHOD" -eq 1 ]; then
        NODE_CERT_DOMAIN=$(extract_domain "$SELFSTEAL_DOMAIN")
    else
        NODE_CERT_DOMAIN="$SELFSTEAL_DOMAIN"
    fi

    # Docker-compose для ноды
    (
        cat > /opt/remnawave/docker-compose.yml <<EOL
services:
  remnawave-nginx:
    image: nginx:1.28
    container_name: remnawave-nginx
    hostname: remnawave-nginx
    restart: always
    ulimits:
      nofile:
        soft: 1048576
        hard: 1048576
    volumes:
      - ./nginx.conf:/etc/nginx/conf.d/default.conf:ro
      - /etc/letsencrypt/live/$NODE_CERT_DOMAIN/fullchain.pem:/etc/nginx/ssl/$NODE_CERT_DOMAIN/fullchain.pem
      - /etc/letsencrypt/live/$NODE_CERT_DOMAIN/privkey.pem:/etc/nginx/ssl/$NODE_CERT_DOMAIN/privkey.pem
      - /dev/shm:/dev/shm:rw
      - /var/www/html:/var/www/html:ro
    command: sh -c 'rm -f /dev/shm/nginx.sock && exec nginx -g "daemon off;"'
    network_mode: host
    depends_on:
      - remnanode
    logging:
      driver: 'json-file'
      options:
        max-size: '30m'
        max-file: '5'

  remnanode:
    image: remnawave/node:latest
    container_name: remnanode
    hostname: remnanode
    restart: always
    ulimits:
      nofile:
        soft: 1048576
        hard: 1048576
    network_mode: host
    environment:
      - NODE_PORT=2222
      - SECRET_KEY=$(echo -e "$CERTIFICATE")
    volumes:
      - /dev/shm:/dev/shm:rw
    logging:
      driver: 'json-file'
      options:
        max-size: '30m'
        max-file: '5'
EOL
    ) &
    show_spinner "Создание docker-compose.yml"

    (generate_nginx_conf_node "$SELFSTEAL_DOMAIN" "$NODE_CERT_DOMAIN") &
    show_spinner "Создание nginx.conf"

    (
        ufw allow from "$PANEL_IP" to any port 2222 >/dev/null 2>&1
        ufw reload >/dev/null 2>&1
    ) &
    show_spinner "Настройка файрвола"

    (
        cd /opt/remnawave
        docker compose up -d >/dev/null 2>&1
    ) &
    show_spinner "Запуск Docker контейнеров"

    show_spinner_timer 5 "Ожидание запуска ноды"

    randomhtml

    echo
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${GREEN}   🎉 НОДА УСТАНОВЛЕНА!${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo
    echo -e "${WHITE}SelfSteal:${NC}    https://$SELFSTEAL_DOMAIN"
    echo -e "${WHITE}IP панели:${NC}    $PANEL_IP"
    echo
    echo -e "${YELLOW}Проверьте подключение ноды в панели Remnawave${NC}"
    echo
    read -s -n 1 -p "$(echo -e "${DARKGRAY}Нажмите Enter для продолжения${NC}")"
}

# ═══════════════════════════════════════════════
# УПРАВЛЕНИЕ
# ═══════════════════════════════════════════════
change_credentials() {
    clear
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${GREEN}   🔐 СБРОС СУПЕРАДМИНА${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo
    echo -e "${YELLOW}⚠️  ВНИМАНИЕ!${NC}"
    echo -e "${WHITE}Эта операция удалит текущего суперадмина из базы данных.${NC}"
    echo -e "${WHITE}При следующем входе в панель вам будет предложено${NC}"
    echo -e "${WHITE}создать нового суперадмина.${NC}"
    echo
    reading "Вы уверены? (yes/no):" CONFIRM

    if [ "$CONFIRM" != "yes" ]; then
        print_error "Операция отменена"
        sleep 2
        return
    fi

    echo
    print_action "Сброс суперадмина..."

    # Останавливаем панель
    (
        cd /opt/remnawave
        docker compose stop remnawave >/dev/null 2>&1
    ) &
    show_spinner "Остановка панели"

    # Подключаемся к базе и удаляем всех администраторов
    docker exec -i remnawave-db psql -U postgres -d postgres <<'EOSQL' >/dev/null 2>&1
DELETE FROM admin;
EOSQL

    if [ $? -eq 0 ]; then
        print_success "Суперадмин удалён из базы данных"
    else
        print_error "Не удалось удалить суперадмина"
        # Запускаем панель обратно
        (
            cd /opt/remnawave
            docker compose start remnawave >/dev/null 2>&1
        ) &
        show_spinner "Запуск панели"
        sleep 2
        return
    fi

    # Запускаем панель обратно
    (
        cd /opt/remnawave
        docker compose start remnawave >/dev/null 2>&1
    ) &
    show_spinner "Запуск панели"

    # Ждём готовности
    show_spinner_timer 10 "Ожидание запуска панели"

    echo
    echo -e "${GREEN}✅ Сброс выполнен успешно!${NC}"
    echo
    echo -e "${WHITE}При следующем входе в панель вы сможете создать${NC}"
    echo -e "${WHITE}нового суперадмина с любым логином и паролем.${NC}"
    echo
    read -s -n 1 -p "$(echo -e "${DARKGRAY}Нажмите Enter для возврата${NC}")"
}

# ═══════════════════════════════════════════════
# УПРАВЛЕНИЕ: СЛУЧАЙНЫЙ ШАБЛОН
# ═══════════════════════════════════════════════
manage_start() {
    (
        cd /opt/remnawave
        docker compose up -d >/dev/null 2>&1
    ) &
    show_spinner "Запуск сервисов"
    print_success "Сервисы запущены"
    read -s -n 1 -p "$(echo -e "${DARKGRAY}Нажмите Enter для продолжения${NC}")"
}

manage_stop() {
    (
        cd /opt/remnawave
        docker compose down >/dev/null 2>&1
    ) &
    show_spinner "Остановка сервисов"
    print_success "Сервисы остановлены"
    read -s -n 1 -p "$(echo -e "${DARKGRAY}Нажмите Enter для продолжения${NC}")"
}

manage_update() {
    clear
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${GREEN}   🔄 ОБНОВЛЕНИЕ КОМПОНЕНТОВ${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo

    (
        cd /opt/remnawave
        docker compose pull >/dev/null 2>&1
    ) &
    show_spinner "Скачивание обновлений"

    (
        cd /opt/remnawave
        docker compose up -d >/dev/null 2>&1
    ) &
    show_spinner "Перезапуск сервисов"

    (
        docker image prune -af >/dev/null 2>&1
    ) &
    show_spinner "Очистка старых образов"

    print_success "Обновление завершено"
    read -s -n 1 -p "$(echo -e "${DARKGRAY}Нажмите Enter для продолжения${NC}")"
}

manage_logs() {
    clear
    echo -e "${YELLOW}Для выхода из логов нажмите Ctrl+C${NC}"
    sleep 1
    cd /opt/remnawave
    docker compose logs -f -t --tail 100
}

manage_reinstall() {
    clear
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${RED}   🗑️ ПЕРЕУСТАНОВКА${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo

    echo -e "${RED}⚠️  Все данные будут удалены!${NC}"
    echo
    local confirm
    read -e -p "$(echo -e "${YELLOW}Вы уверены? [y/N]: ${NC}")" confirm
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        return
    fi

    (
        cd /opt/remnawave
        docker compose down -v --rmi all >/dev/null 2>&1
        docker system prune -af >/dev/null 2>&1
    ) &
    show_spinner "Удаление контейнеров и данных"

    (
        rm -f /opt/remnawave/.env
        rm -f /opt/remnawave/docker-compose.yml
        rm -f /opt/remnawave/nginx.conf
    ) &
    show_spinner "Очистка конфигурации"

    print_success "Готово к переустановке"

    show_arrow_menu "📦 ВЫБЕРИТЕ ТИП УСТАНОВКИ" \
        "📦  Панель + Нода (один сервер)" \
        "🖥️   Только панель" \
        "🌐  Только нода" \
        "❌  Назад"
    local choice=$?

    case $choice in
        0) installation_full ;;
        1) installation_panel ;;
        2) installation_node ;;
        3) return ;;
    esac
}

manage_random_template() {
    clear
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${GREEN}   🎨 СЛУЧАЙНЫЙ ШАБЛОН${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo

    randomhtml

    (
        cd /opt/remnawave
        docker compose restart remnawave-nginx >/dev/null 2>&1
    ) &
    show_spinner "Перезапуск Nginx"

    print_success "Шаблон обновлён"
    read -s -n 1 -p "$(echo -e "${DARKGRAY}Нажмите Enter для продолжения${NC}")"
}

# ═══════════════════════════════════════════════
# ПРОВЕРКА ВЕРСИИ И ОБНОВЛЕНИЕ СКРИПТА
# ═══════════════════════════════════════════════
check_for_updates() {
    local remote_version
    
    # Получаем последний коммит SHA и используем его для обхода кеша
    local latest_sha
    latest_sha=$(curl -sL --max-time 3 "https://api.github.com/repos/DanteFuaran/Remna-install/commits/main" 2>/dev/null | grep -m 1 '"sha"' | cut -d'"' -f4)
    
    if [ -n "$latest_sha" ]; then
        remote_version=$(curl -sL --max-time 3 "https://raw.githubusercontent.com/DanteFuaran/Remna-install/$latest_sha/install_remnawave.sh" 2>/dev/null | grep -m 1 'SCRIPT_VERSION=' | cut -d'"' -f2)
    fi
    
    if [ -z "$remote_version" ]; then
        return 1
    fi
    
    # Сравнение версий (простое сравнение строк)
    if [ "$remote_version" != "$SCRIPT_VERSION" ]; then
        # Дополнительная проверка что remote_version новее
        local current_ver="${SCRIPT_VERSION//./}"
        local remote_ver="${remote_version//./}"
        
        if [ "$remote_ver" -gt "$current_ver" ] 2>/dev/null; then
            echo "$remote_version"
            return 0
        fi
    fi
    
    return 1
}

show_update_notification() {
    local new_version=$1
    echo
    echo -e "${YELLOW}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║${NC}  ${GREEN}🔔 ДОСТУПНО ОБНОВЛЕНИЕ!${NC}                        ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}                                                  ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}  Текущая версия:  ${WHITE}v$SCRIPT_VERSION${NC}                      ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}  Новая версия:     ${GREEN}v$new_version${NC}                      ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}                                                  ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}  Обновите скрипт через меню:                    ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}  ${BLUE}🔄 Обновить скрипт${NC}                             ${YELLOW}║${NC}"
    echo -e "${YELLOW}╚══════════════════════════════════════════════════╝${NC}"
    echo
}

update_script() {
    clear
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${GREEN}   🔄 ОБНОВЛЕНИЕ СКРИПТА${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo

    (
        wget -q -O "${DIR_REMNAWAVE}remna_install" "$SCRIPT_URL" 2>/dev/null
        chmod +x "${DIR_REMNAWAVE}remna_install"
        ln -sf "${DIR_REMNAWAVE}remna_install" /usr/local/bin/remna_install
    ) &
    show_spinner "Загрузка обновлений"

    print_success "Скрипт обновлён до последней версии"
    read -s -n 1 -p "$(echo -e "${DARKGRAY}Нажмите Enter для перезапуска${NC}")"
    exec "$0"
}

remove_script() {
    clear
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo -e "${RED}   🗑️ УДАЛЕНИЕ СКРИПТА${NC}"
    echo -e "${BLUE}════════════════════════════════════════${NC}"
    echo

    show_arrow_menu "Выберите действие" \
        "🗑️   Удалить только скрипт" \
        "💣  Удалить скрипт + все данные Remnawave" \
        "❌  Назад"
    local choice=$?

    case $choice in
        0)
            rm -f /usr/local/bin/remna_install
            rm -rf "${DIR_REMNAWAVE}"
            print_success "Скрипт удалён"
            exit 0
            ;;
        1)
            echo -e "${RED}⚠️  ВСЕ ДАННЫЕ БУДУТ УДАЛЕНЫ!${NC}"
            echo
            local confirm
            read -e -p "$(echo -e "${YELLOW}Подтвердите: [y/N]: ${NC}")" confirm
            if [[ "$confirm" == "y" || "$confirm" == "Y" ]]; then
                (
                    cd /opt/remnawave 2>/dev/null
                    docker compose down -v --rmi all >/dev/null 2>&1 || true
                    docker system prune -af >/dev/null 2>&1 || true
                ) &
                show_spinner "Удаление контейнеров"
                rm -rf /opt/remnawave
                rm -f /usr/local/bin/remna_install
                rm -rf "${DIR_REMNAWAVE}"
                print_success "Всё удалено"
                exit 0
            fi
            ;;
        2) return ;;
    esac
}

# ═══════════════════════════════════════════════
# УСТАНОВКА СКРИПТА
# ═══════════════════════════════════════════════
install_script() {
    # Проверяем, запущен ли скрипт уже из /usr/local/bin
    if [ -L "/usr/local/bin/remna_install" ] && [ -f "${DIR_REMNAWAVE}remna_install" ]; then
        local installed_size
        installed_size=$(wc -c < "${DIR_REMNAWAVE}remna_install" 2>/dev/null || echo 0)
        if [ "$installed_size" -gt 1000 ]; then
            # Скрипт уже корректно установлен
            return 0
        fi
    fi

    # Скачиваем скрипт в постоянное местоположение
    mkdir -p "${DIR_REMNAWAVE}"
    
    if ! wget -O "${DIR_REMNAWAVE}remna_install" "$SCRIPT_URL" >/dev/null 2>&1; then
        echo -e "${RED}✖ Не удалось скачать скрипт${NC}"
        exit 1
    fi
    
    chmod +x "${DIR_REMNAWAVE}remna_install"
    ln -sf "${DIR_REMNAWAVE}remna_install" /usr/local/bin/remna_install

    local bashrc_file="/etc/bash.bashrc"
    local alias_line="alias ri='remna_install'"
    if [ -f "$bashrc_file" ] && ! grep -q "$alias_line" "$bashrc_file"; then
        echo "$alias_line" >> "$bashrc_file"
    fi
}

# ═══════════════════════════════════════════════
# ГЛАВНОЕ МЕНЮ
# ═══════════════════════════════════════════════
main_menu() {
    while true; do
        local is_installed=false
        if [ -f "/opt/remnawave/docker-compose.yml" ]; then
            is_installed=true
        fi
        
        # Получаем информацию о доступной версии (если есть)
        local update_notice=""
        if [ -f /tmp/remna_update_available ]; then
            local new_version
            new_version=$(cat /tmp/remna_update_available)
            update_notice=" ${YELLOW}(Доступна версия v$new_version)${NC}"
        fi

        if [ "$is_installed" = true ]; then
            show_arrow_menu "🚀 REMNAWAVE INSTALLER v$SCRIPT_VERSION" \
                "📦  Установить компоненты" \
                "🔄  Переустановить" \
                "──────────────────────────────────────" \
                "▶️   Запустить сервисы" \
                "⏹️   Остановить сервисы" \
                "📋  Просмотр логов" \
                "──────────────────────────────────────" \
                "🔄  Обновить панель/ноду" \
                "🔐  Сбросить суперадмина" \
                "🎨  Случайный шаблон selfsteal" \
                "──────────────────────────────────────" \
                "🔄  Обновить скрипт$update_notice" \
                "🗑️   Удалить скрипт" \
                "──────────────────────────────────────" \
                "❌  Выход"
            local choice=$?

            case $choice in
                0)
                    show_arrow_menu "📦 ВЫБЕРИТЕ ТИП УСТАНОВКИ" \
                        "📦  Панель + Нода (один сервер)" \
                        "🖥️   Только панель" \
                        "🌐  Только нода" \
                        "❌  Назад"
                    local install_choice=$?
                    case $install_choice in
                        0)
                            if [ ! -f "${DIR_REMNAWAVE}install_packages" ] || ! command -v docker >/dev/null 2>&1; then
                                install_packages
                            fi
                            installation_full
                            ;;
                        1)
                            if [ ! -f "${DIR_REMNAWAVE}install_packages" ] || ! command -v docker >/dev/null 2>&1; then
                                install_packages
                            fi
                            installation_panel
                            ;;
                        2)
                            if [ ! -f "${DIR_REMNAWAVE}install_packages" ] || ! command -v docker >/dev/null 2>&1; then
                                install_packages
                            fi
                            installation_node
                            ;;
                        3) continue ;;
                    esac
                    ;;
                1) manage_reinstall ;;
                2) continue ;;
                3) manage_start ;;
                4) manage_stop ;;
                5) manage_logs ;;
                6) continue ;;
                7) manage_update ;;
                8) change_credentials ;;
                9) manage_random_template ;;
                10) continue ;;
                11) update_script ;;
                12) remove_script ;;
                13) continue ;;
                14) clear; exit 0 ;;
            esac
        else
            show_arrow_menu "🚀 REMNAWAVE INSTALLER v$SCRIPT_VERSION" \
                "📦  Установить компоненты" \
                "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" \
                "🔄  Обновить скрипт$update_notice" \
                "🗑️   Удалить скрипт" \
                "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" \
                "❌  Выход"
            local choice=$?

            case $choice in
                0)
                    show_arrow_menu "📦 ВЫБЕРИТЕ ТИП УСТАНОВКИ" \
                        "📦  Панель + Нода (один сервер)" \
                        "🖥️   Только панель" \
                        "🌐  Только нода" \
                        "❌  Назад"
                    local install_choice=$?
                    case $install_choice in
                        0)
                            install_packages
                            installation_full
                            ;;
                        1)
                            install_packages
                            installation_panel
                            ;;
                        2)
                            install_packages
                            installation_node
                            ;;
                        3) continue ;;
                    esac
                    ;;
                1) continue ;;
                2) update_script ;;
                3) remove_script ;;
                4) continue ;;
                5) clear; exit 0 ;;
            esac
        fi
    done
}

# ═══════════════════════════════════════════════
# ТОЧКА ВХОДА
# ═══════════════════════════════════════════════
check_root
check_os

# Проверяем, нужно ли установить скрипт
if [ ! -L "/usr/local/bin/remna_install" ] || [ ! -f "${DIR_REMNAWAVE}remna_install" ]; then
    install_script
    # Перезапускаем из установленной копии
    print_success "Скрипт установлен в систему"
    echo -e "${YELLOW}Запускаем меню установки...${NC}"
    sleep 1
    exec /usr/local/bin/remna_install
fi

# Проверка обновлений (синхронно, но только если прошло больше часа с последней проверки)
UPDATE_CHECK_FILE="/tmp/remna_last_update_check"
current_time=$(date +%s)
last_check=0

if [ -f "$UPDATE_CHECK_FILE" ]; then
    last_check=$(cat "$UPDATE_CHECK_FILE" 2>/dev/null || echo 0)
fi

# Проверяем раз в час (3600 секунд)
time_diff=$((current_time - last_check))
if [ $time_diff -gt 3600 ] || [ ! -f /tmp/remna_update_available ]; then
    new_version=$(check_for_updates)
    if [ $? -eq 0 ] && [ -n "$new_version" ]; then
        echo "$new_version" > /tmp/remna_update_available
    else
        rm -f /tmp/remna_update_available 2>/dev/null
    fi
    echo "$current_time" > "$UPDATE_CHECK_FILE"
fi

main_menu
