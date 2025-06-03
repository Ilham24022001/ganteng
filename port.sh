#!/bin/bash

CONTAINER_NAME="vpn-container"

# Cek apakah container ada
if ! lxc list --format csv -c n | grep -wq "$CONTAINER_NAME"; then
  echo "❌ Container '$CONTAINER_NAME' tidak ditemukan di project saat ini."
  echo "📋 Daftar container yang tersedia:"
  lxc list --format table
  exit 1
fi

# Dapatkan IP container (interface eth0)
CONTAINER_IP=$(lxc exec "$CONTAINER_NAME" -- ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -n1)

if [ -z "$CONTAINER_IP" ]; then
  echo "❌ Gagal mendapatkan IP container $CONTAINER_NAME."
  exit 1
fi

echo "📦 Menambahkan port forwarding ke container: $CONTAINER_NAME dengan IP: $CONTAINER_IP"

# Fungsi tambah proxy device dengan cek jika sudah ada akan dihapus dulu supaya tidak error duplicate
add_proxy_device() {
  local container=$1
  local name=$2
  local listen_port=$3
  local connect_ip=$4
  local connect_port=$5

  # Jika device sudah ada, hapus dulu
  if lxc config device show "$container" | grep -qw "$name"; then
    echo "⚠️ Device $name sudah ada, menghapus terlebih dahulu..."
    lxc config device remove "$container" "$name"
  fi

  # Tambah device baru
  lxc config device add "$container" "$name" proxy listen=tcp:0.0.0.0:"$listen_port" connect=tcp:"$connect_ip":"$connect_port"
  echo "✅ Device $name ditambahkan: listen=0.0.0.0:$listen_port -> connect=$connect_ip:$connect_port"
}

# === XRAY ===
add_proxy_device "$CONTAINER_NAME" xray443 443 "$CONTAINER_IP" 443
add_proxy_device "$CONTAINER_NAME" xray80 80 "$CONTAINER_IP" 80
add_proxy_device "$CONTAINER_NAME" xray10000 10000 "$CONTAINER_IP" 10000

# === SSH WebSocket ===
add_proxy_device "$CONTAINER_NAME" sshws8880 8880 "$CONTAINER_IP" 8880
add_proxy_device "$CONTAINER_NAME" sshws2082 2082 "$CONTAINER_IP" 2082
add_proxy_device "$CONTAINER_NAME" sshws8080 8080 "$CONTAINER_IP" 8080

# === Dropbear ===
add_proxy_device "$CONTAINER_NAME" dropbear22 149 "$CONTAINER_IP" 149
add_proxy_device "$CONTAINER_NAME" dropbear109 109 "$CONTAINER_IP" 109
add_proxy_device "$CONTAINER_NAME" dropbear143 143 "$CONTAINER_IP" 143
add_proxy_device "$CONTAINER_NAME" dropbear442 442 "$CONTAINER_IP" 442

# === HAProxy ===
add_proxy_device "$CONTAINER_NAME" haproxy8443 8443 "$CONTAINER_IP" 8443
add_proxy_device "$CONTAINER_NAME" haproxy8080 8080 "$CONTAINER_IP" 8080
add_proxy_device "$CONTAINER_NAME" haproxy3000 3000 "$CONTAINER_IP" 3000

echo "✅ Semua port forwarding berhasil ditambahkan ke container '$CONTAINER_NAME'."
