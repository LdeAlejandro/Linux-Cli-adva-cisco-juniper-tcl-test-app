cat << 'EOF' > juniper
#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Mostrar ajuda direto aqui, sem chamar expect
if [[ "$1" == "--help" || "$1" == "-h" || $# -lt 2 ]]; then
  echo ""
  echo "🔧 USO DO SCRIPT:"
  echo "  juniper <device> <interface>"
  echo ""
  echo "📥 VARIÁVEIS NECESSÁRIAS:"
  echo "  <device>     → IP ou hostname do equipamento (ex: 192.168.0.1)"
  echo "  <interface>  → Nome da interface a ser verificada (ex: G0/0/3.999)"
  echo ""
  echo "📘 EXEMPLO:"
  echo "  juniper 192.168.1.1 G0/0/3.100"
  echo ""
  echo "ℹ️  As credenciais devem estar definidas em variaveis_ambiente.sh"
  echo ""
  exit 0
fi

# Carrega variáveis de ambiente
source "$SCRIPT_DIR/variaveis_ambiente.sh"

# Executa o script expect com os argumentos recebidos
expect "$SCRIPT_DIR/juniper.exec" "$1" "$2"
EOF



chmod +x juniper

cat << 'EOF' > juniper.exec
#!/usr/bin/expect -f

# Checa se o usuário pediu ajuda ou não passou os argumentos necessários
if { $argc < 2 || [lindex $argv 0] in {"--help" "-h"} } {
    puts "\n USO DO SCRIPT:"
    puts "  ./juniper.exec <device> <interface>\n"
    puts "VARIÁVEIS NECESSÁRIAS:"
    puts "  <device>     → IP ou hostname do equipamento (ex: 192.168.0.1)"
    puts "  <interface>  → Nome da interface a ser verificada (ex: GigabitEthernet0/0/3)"
    puts ""
    puts "EXEMPLO:"
    puts "  juniper 192.168.1.1 G0/0/3.938712639812"
    exit 0
    
}

set timeout 10
set device [lindex $argv 0]
set interface [lindex $argv 1]
set user $env(USER_JUNIPER)
set password $env(PASS_JUNIPER)
set command_responses ""
set final_report "=========================\n"

# Guardar o valor da interface fisica
if {[string match "*.*" $interface]} {
    set physical_interface [lindex [split $interface "."] 0]
} else {
    set physical_interface $interface
}

# Inicia a sessão telnet
spawn telnet $device

# Login
expect "Username:"
send "$user\r"

expect "Password:"
send "$password\r"

# Espera prompt de modo operacional (ajuste conforme o prompt do seu sistema)
expect "RP"

send "sh interface $physical_interface\r"

#verificar informação da interface
expect {
     -re "\n.*#" {
    set output $expect_out(buffer)
        append command_responses "$output\n"

        if {[regexp {is up, line protocol is up} $output]} {
            append final_report "Interface ativa OK: is up, line protocol is up\n"
        } elseif {[regexp {is up, line protocol is down} $output]} {
            append final_report "Interface ligada fisicamente, mas sem conectividade FAIL: is up, line protocol is down."
        } elseif {[regexp {is down, line protocol is down} $output]} {
            append final_report "Interface desligada ou sem cabo FAIL: is down, line protocol is down.\n"
        } elseif {[regexp {administratively down} $output]} {
            append final_report "Interface desabilitada manualmente (shutdown) FAIL: administratively down\n"
        } else {
            append final_report "\n FAIL: Estado da interface não identificado"
        }
    }  
}     

send " sh l2vpn forwarding bridge-domain mac-address location 0/0/CPU0 | i $interface\r"

# Verificar resposta
expect {
    -re ".*dynamic.*$interface" {
        set output $expect_out(buffer)

        # guardar resposta do comando
        append command_responses "$output\n"

        append final_report "Mac Learning $interface OK: está aprendendo MACs\n"
    }
    timeout {
        append final_report "Mac Learning $interface FAIL: Timeout esperando resposta do comando para $interface Nenhuma MAC encontrada para $interface\n"

    }
    eof {
        append final_report "Mac Learning $interface FAIL: Nenhuma MAC encontrada para $interface\n"
    }
}
puts "\n=========================\n"
puts "\n Resumo dos comandos executados:\n"
puts "Device: $device"
puts "$command_responses"
puts "\n=========================\n"
puts "\nResultado final:\n"
puts "$final_report"
puts "\n=========================\n"
puts "Device: $device"


# Fecha a sessão
expect eof

EOF


# Mover arquivos para executar com comandos
mv juniper ~/.local/bin/
mv juniper.exec ~/.local/bin/
chmod +x ~/.local/bin/juniper
chmod +x ~/.local/bin/juniper.exec