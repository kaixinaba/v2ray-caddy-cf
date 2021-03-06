#!/bin/bash

if [[ $(/usr/bin/id -u) -ne 0 ]]; then
    echo "请使用root用户或sudo指令執行"
    exit 2
fi

V2_DOMAIN=$1
V2_PATH=$(echo $2| tr -d '/')
CF_EMAIL=$3
CF_APIKEY=$4

apt-get install curl git uuid-runtime coreutils libcap2-bin wget ntp -y

# install v2ray
bash <(curl -L -s https://install.direct/go.sh)

# install caddy
curl https://getcaddy.com | bash -s personal tls.dns.cloudflare

rm -rf v2ray-caddy-cf
git clone https://github.com/phlinhng/v2ray-caddy-cf.git
cd v2ray-caddy-cf

uuid=$(uuidgen)
sed -i "s/FAKEUUID/${uuid}/g" config.json
sed -i "s/FAKEDOMAIN/${V2_DOMAIN}/g" Caddyfile
sed -i "s/FAKEPATH/${V2_PATH}/g" Caddyfile
sed -i "s/FAKEEMAIL/${CF_EMAIL}/g" caddy.service
sed -i "s/FAKEAPIKEY/${CF_APIKEY}/g" caddy.service

# Give the caddy binary the ability to bind to privileged ports (e.g. 80, 443) as a non-root user
setcap 'cap_net_bind_service=+ep' /usr/local/bin/caddy

# create user for caddy
groupadd -g 33 www-data
useradd -g www-data --no-user-group \
  --home-dir /var/www --no-create-home \
  --shell /usr/sbin/nologin \
  --system --uid 33 www-data
  
mkdir /var/www
chown www-data:www-data /var/www
chmod 555 /var/www

/bin/cp -f config.json /etc/v2ray

mkdir -p /etc/caddy
chown -R root:root /etc/caddy

mkdir -p /etc/ssl/caddy
chown -R root:www-data /etc/ssl/caddy
chmod 0770 /etc/ssl/caddy
# to prevent problem from restarting caddy
rm -rf /etc/ssl/caddy/*

/bin/cp Caddyfile /etc/caddy/Caddyfile
chown root:root /etc/caddy/Caddyfile
chmod 644 /etc/caddy/Caddyfile

/bin/cp caddy.service /etc/systemd/system/caddy.service
chown root:root /etc/systemd/system/caddy.service
chmod 644 /etc/systemd/system/caddy.service

(crontab -l 2>/dev/null; echo "0 7 * * * wget -q https://github.com/Loyalsoldier/v2ray-rules-dat/raw/release/geoip.dat -O /usr/bin/v2ray/geoip.dat >/dev/null >/dev/null") | crontab -
(crontab -l 2>/dev/null; echo "0 7 * * * wget -q https://github.com/Loyalsoldier/v2ray-rules-dat/raw/release/geosite.dat -O /usr/bin/v2ray/geosite.dat >/dev/null >/dev/null") | crontab -

systemctl daemon-reload

systemctl enable ntp
systemctl start ntp

systemctl enable v2ray
systemctl start v2ray

systemctl enable caddy
systemctl start caddy

cd ..
rm -rf v2ray-caddy-cf

printf ""
printf "Address: ${V2_DOMAIN}"
printf "Port: 443"
printf "UUID: ${uuid}"
printf "Alter ID: 0"
printf "Type: websocket"
printf "Hostname: ${V2_DOMAIN}"
printf "Path: /${V2_PATH}"
printf ""

json="{\"add\":\"${V2_DOMAIN}\",\"aid\":\"0\",\"host\":\"${V2_DOMAIN}\",\"id\":\"${uuid}\",\"net\":\"ws\",\"path\":\"/${V2_PATH}\",\"port\":\"443\",\"ps\":\"${V2_DOMAIN}:443\",\"tls\":\"tls\",\"type\":\"none\",\"v\":\"2\"}"

uri="$(printf "${json}" | base64)"
printf "vmess://${uri}"
printf "\n"

exit 0
