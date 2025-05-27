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
  echo "  cirion-monitor             → executa o monitoramento"
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
  removed=0
  grep -v "^$2 " "$IP_STORE" > "$IP_STORE.tmp" || true
  if [[ "$(diff "$IP_STORE" "$IP_STORE.tmp")" != "" ]]; then
    mv "$IP_STORE.tmp" "$IP_STORE"
    echo "🗑️ IP $2 removido do monitoramento."
    removed=1
  else
    rm -f "$IP_STORE.tmp"
    echo "⚠️ IP $2 não está na lista."
  fi
  
  if [[ $removed -eq 1 && -s "$IP_STORE" ]]; then
  sleep 0.5
  ~/.local/bin/cirion-monitor
  fi
  exit 0
fi

# Regex para validar IPv4
is_valid_ip() {
  [[ "$1" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] && 
  for i in $(echo "$1" | tr '.' ' '); do
    (( i >= 0 && i <= 255 )) || return 1
  done
  return 0
}

# Variáveis de entrada
ip="$1"
cliente="$2"
provedor="$3"

# Validador de IP
is_valid_ip() {
  [[ "$1" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
  for octet in $(echo "$1" | tr '.' ' '); do
    ((octet >= 0 && octet <= 255)) || return 1
  done
  return 0
}

# Valida IP
if ! is_valid_ip "$ip"; then
  echo "❌ IP inválido: $ip"
  exit 1
fi

# Adiciona IP se ainda não existe
if ! grep -Fxq "$ip $cliente $provedor" "$IP_STORE"; then
  echo "$ip $cliente $provedor" >> "$IP_STORE"
  echo "➕ IP $ip ($cliente, $provedor) adicionado ao monitoramento."
  ~/.local/bin/cirion-monitor
else
  echo "ℹ️  IP $ip já está sendo monitorado."
fi

EOF

chmod +x ~/.local/bin/cirion-ping


cat << 'EOF' > ~/.local/bin/cirion-monitor
#!/bin/bash

#func animacao de texto
typewriter() {
  local text="$1"
  local i=0
  while [ $i -lt ${#text} ]; do
    char="${text:$i:1}"
    echo -n "$char"
    sleep 0.01
    ((i++))
  done
  echo
}

#loading animation
loading() {
  local pid=$1
  local delay=0.1
  local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  echo -n "⌛ Atualizando "
  while kill -0 $pid 2>/dev/null; do
    for ((i=0; i<${#spin}; i++)); do
      printf "\b${spin:$i:1}"
      sleep $delay
    done
  done
  echo " "
  typewriter "⏳ Verificando links... ⏳"
  typewriter "⏳ Atualizando dados... ⏳"
}

IP_STORE="$HOME/.local/bin/cirion-ping-ips.txt"

# Verifica se o arquivo existe
if [[ ! -f "$IP_STORE" ]]; then
  echo "⚠️ Nenhum IP monitorado ainda. Use: cirion-ping <IP>"
  exit 1
fi

# Função para verificar IP e armazenar status
check_ip() {
  local ip=$1
  local cliente=$2
  local provedor=$3

  if ping -c 1 -W 1 "$ip" > /dev/null 2>&1; then
    if ping -M do -s 1472 -c 1 -W 1 "$ip" > /dev/null 2>&1; then
      resultmtu_ok=" ✔️ [\033[0;32m OK \033[0m] $cliente $provedor $ip \033[0;32mONLINE\033[0m, MTU 1472: [\033[0;32mOK\033[0m]"
      online_list_mtu_ok+=("$resultmtu_ok")
    else
      resultmtu_fail=" ✔️ [\033[0;32m OK \033[0m] $cliente $provedor $ip \033[0;32mONLINE\033[0m, MTU 1472: [\033[0;31mFAIL\033[0m]"
          online_list_mtu_fail+=("$resultmtu_fail")
    fi
    
  else
    fail_result="❌ [\033[0;31mFAIL\033[0m] $cliente $provedor $ip \033[0;31mOFFLINE\033[0m"
    offline_list+=("$fail_result")
  fi
}

if [[ ! -s "$IP_STORE" ]]; then
  echo "⚠️ Nenhum IP monitorado ainda. Use: cirion-ping <IP>"
  exit 0
fi

# Loop de monitoramento
while true; do
  online_list_mtu_ok=()
  online_list_mtu_fail=()
  offline_list=()
  
  dashboard=""
  dashboard+="🔍 Monitor de Conectividade"$'\n'
  dashboard+="TESTANDO LINKS:"$'\n'
  dashboard+="============================================================================================\n"
  dashboard+="\n"
  while IFS=" " read -r ip cliente provedor; do
    [[ -n "$ip" ]] && check_ip "$ip" "$cliente" "$provedor"
  done < "$IP_STORE"

 # Exibe primeiro os ONLINE com mtu ok
  for line in "${online_list_mtu_ok[@]}"; do
    dashboard+="$line"$'\n'
  done

   # Exibe primeiro os ONLINE com mtu fail
  for line in "${online_list_mtu_fail[@]}"; do
    dashboard+="$line"$'\n'
  done

  # Depois os OFFLINE
  for line in "${offline_list[@]}"; do
    dashboard+="$line"$'\n'
  done
  # Exibir testes
  dashboard+="\n"
  dashboard+="============================================================================================\n"
  
  dashboard+="📅 $(date '+%d/%m/%Y') \033[0;36m$(date '+%H:%M:%S')\033[0m"$'\n'
  clear
  echo -e "$dashboard"
  typewriter "Dados atualizados com sucesso..."
    {
  sleep 3
  } & loading $!


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