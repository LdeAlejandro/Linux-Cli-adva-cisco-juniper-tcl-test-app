cat << 'EOF' > ~/.local/bin/cirion-ping
#!/bin/bash

# Created by Alejandro Amoroso
# Github: https://github.com/LdeAlejandro

IP_STORE="$HOME/.local/bin/cirion-ping-ips.txt"

# Mostrar ajuda
if [[ "$1" == "--help" || "$1" == "-h" || $# -eq 0 ]]; then
  echo ""
  echo "📡 Uso:"
  echo "  cirion-ping <IP>           → adiciona IP ao monitoramento"
  echo "  cirion-ping -c <IP>        → remove IP do monitoramento"
  echo "  cirion-ping --clear        → limpa todos os IPs monitorados"
  echo "  cirion-monitor --clear        → executa o monitoramento"
  echo ""
  echo "📋 IPs monitorados atualmente:"
  cat "$IP_STORE" 2>/dev/null || echo "(nenhum ainda)"
  exit 0
fi

# Cria arquivo se necessário
mkdir -p "$HOME/.local/bin"
touch "$IP_STORE"

# Remover todos os IPs
if [[ "$1" == "--clear" ]]; then
  > "$IP_STORE"
  echo "🧹 Todos os IPs foram removidos do monitoramento."
  exit 0
fi

# Remover IP específico
if [[ "$1" == "-c" && -n "$2" ]]; then
  if grep -Fxq "$2" "$IP_STORE"; then
    grep -Fxv "$2" "$IP_STORE" > "$IP_STORE.tmp" && mv "$IP_STORE.tmp" "$IP_STORE"
    echo "🗑️ IP $2 removido do monitoramento."
    ~/.local/bin/cirion-monitor
  else
    echo "⚠️ IP $2 não está na lista."
    ~/.local/bin/cirion-monitor
  fi
  exit 0
fi

# Adicionar IPs passados como argumento
cliente="$2"
provedor="$3"
for ip in "$@"; do
  if ! grep -Fxq "$ip" "$IP_STORE"; then
    echo "$ip $cliente $provedor" >> "$IP_STORE"
    echo "➕ IP $ip ($cliente, $provedor) adicionado ao monitoramento. "
    # Executa o monitor em primeiro plano (na sequência)
    ~/.local/bin/cirion-monitor
  else
    echo "ℹ️  IP $ip já está sendo monitorado."
  fi
done

EOF

chmod +x ~/.local/bin/cirion-ping


cat << 'EOF' > ~/.local/bin/cirion-monitor
#!/bin/bash

IP_STORE="$HOME/.local/bin/cirion-ping-ips.txt"

# Verifica se o arquivo existe
if [[ ! -f "$IP_STORE" ]]; then
  echo "⚠️ Nenhum IP monitorado ainda. Use: cirion-ping <IP>"
  exit 1
fi

# Função para verificar um IP
check_ip() {
  local ip=$1
  if ping -c 1 -W 1 "$ip" > /dev/null 2>&1; then
    if ping -M do -s 1472 -c 1 -W 1 "$ip" > /dev/null 2>&1; then
      echo "✔️ $cliente $provedor ping $ip está ONLINE, PING MTU: 1472 OK"
    else
      echo "✔️ $cliente $provedor ping $ip está ONLINE, PING MTU: ❌ falhou"
    fi
  else
    echo "❌ $cliente $provedor $ip está OFFLINE"
  fi
}

# Loop de monitoramento
while true; do
  clear
  echo "🔍 Monitor de Conectividade (atualiza a cada 5s)"
  echo "📅 $(date '+%d/%m/%Y %H:%M:%S')"
  echo "TESTANDO LINKS:"
  echo "=============================================="
  while IFS= read -r ip; do
    [[ -n "$ip" ]] && check_ip "$ip"
  done < "$IP_STORE"
  echo "=============================================="
  sleep 5
done
EOF


mv cirion-ping ~/.local/bin/
mv cirion-ping.exec ~/.local/bin/
chmod +x ~/.local/bin/cirion-ping
chmod +x ~/.local/bin/cirion-ping.exec

mv cirion-monitor ~/.local/bin/
mv cirion-monitor.exec ~/.local/bin/
chmod +x ~/.local/bin/cirion-ping
chmod +x ~/.local/bin/cirion-ping.exec