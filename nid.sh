cat << 'EOF' > nid
#!/bin/bash

#Created by Alejandro Amoroso
#Github: https://github.com/LdeAlejandro

# Define o diretório absoluto onde o script está localizado
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Carrega variáveis de ambiente
source "$SCRIPT_DIR/variaveis_ambiente.sh"

# Executa o script expect com os argumentos recebidos
expect "$SCRIPT_DIR/nid.exec" "$1" "$2" "$3"
EOF

chmod +x nid

cat << 'EOF' > nid.exec
#!/usr/bin/expect -f
#Created by Alejandro Amoroso
#Github: https://github.com/LdeAlejandro
# Checa se o usuário pediu ajuda ou não passou os argumentos necessários
if { $argc < 2 || [lindex $argv 0] in {"--help" "-h"} } {
    puts "\n"
    puts "Documentação dos comandos NID"
    puts "  <device>        → IP ou hostname do equipamento (ex: 10.227.127.117)"
    puts "  <porta-lec>     → número da interface da lec (Se for: 1-1-1-3 então: 3)"
    puts "  <porta-cliente> → número da porta do cliente (Se for: 1-1-1-4 então: 4)"
    puts "  <arp> → arp"

    puts "\n"
    puts "  EXEMPLOS:"
    puts "  Para conectar-se ao NID e validar interfaces, use o comando:"
    puts "  nid <device> <porta-lec> <porta-cliente>"
    puts "  Exemplo: nid 10.227.127.117 1 3"
    puts "\n"

    puts "  Para conectar-se ao NID apenas, use o comando:"
    puts "  nid <device>"
    puts "  Exemplo: nid 10.227.127.117"
    puts "\n"

    puts "  Para conectar-se ao NID e validar tabela arp, use o comando:"
    puts "  nid <device> arp"
    puts "  Comando de exemplo: nid 10.227.127.117 arp"
    puts "\n"
    exit 0
}

set timeout 10
set device [lindex $argv 0]
set firstArg [lindex $argv 1]
set secondArg [lindex $argv 2]
set user $env(USER_NID)
set password $env(PASS_NID)
set command_responses ""
set final_report "=========================\n"

#Conexão simples
#eq valida que seja vazio o argumento "ne" valida que nao seja igual
if { $user ne "" && $password ne "" && $device ne "" && $firstArg eq "" && $secondArg eq "" } {
    puts "Conectando ao NID..."
    spawn ssh $user@$device
    expect {
        -re "Are you sure you want to continue connecting.*" {
            send "yes\r"
            exp_continue
        }
        -re ".*password:" {
            send "$password\r"
        }
    }
    interact
    exit 0
}

#Conexão e ARP
if { $user ne "" && $password ne "" && $device ne "" && $firstArg eq "arp"} {
    puts "Conectando ao NID validando ARP..."
    spawn ssh $user@$device
    expect {
        -re "Are you sure you want to continue connecting.*" {
            send "yes\r"
            exp_continue
        }
        -re ".*password:" {
            send "$password\r"
        }
    }

    #envia  comando arp
    expect -re ".*-->"
    send "sh arp\r"
    interact
    exit 0
}

#Teste mais completos

# Inicia a sessão telnet -o StrictHostKeyChecking=no
spawn ssh   $user@$device
expect {
    -re "Are you sure you want to continue connecting.*" {
        send "yes\r"
        exp_continue
    }
    -re ".*password:" {
        send "$password\r"
    }
}

# Espera prompt de modo operacional 
expect -re ".*-->"

# show system
send "show system\r"

# Captura múltiplas páginas até o prompt final "-->"
set output ""
expect {
    -regexp "--More--" {
        append output $expect_out(buffer)
        send " "
        exp_continue
    }
    -re ".*-->" {
        append output $expect_out(buffer)
    }
}

# Guarda saída completa
append command_responses "$output\n"

# Extração da linha do uptime
regexp {System Up Time\s*:\s*(.+)} $output -> uptime
# Usa split para pegar só a parte antes de "File"
set uptime_trimmed [lindex [split $uptime "F"] 0]
append final_report "NID: $device \nSystem Up Time: $uptime_trimmed\n"

# Espera prompt de modo operacional 
#expect -re ".*-->"
send "sh access-port access-1-1-1-$secondArg\r"

#capturar dados
set secondArg_output ""
expect {
    -exact "--More--" {
        append secondArg_output $expect_out(buffer)
        send " "
        exp_continue
    }
    -re ".*-->" {
        append secondArg_output $expect_out(buffer)
        append command_responses "$secondArg_output\n"
    }
}

# Extração da linha do adminstration state
regexp {Admin State\s*:\s*(.+)} $secondArg_output -> lec_int_admin_state
regexp {Operational State\s*:\s*(.+)} $secondArg_output -> lec_int_operational_state

# Usar splits"
set lec_admin_state_trimmed [lindex [split $lec_int_admin_state "O"] 0]
set lec_operational_state_trimmed [lindex [split $lec_int_operational_state"S"] 0]
append final_report "\n---------------------------\n"
append final_report "Lec Interface: 1-1-1-$secondArg\n"
append final_report "\nAdmin State: $lec_admin_state_trimmed\n"
append final_report "Operational State: $lec_operational_state_trimmed\n"
append final_report "\n---------------------------\n"

### interface cliente

# Espera prompt de modo operacional 
#expect -re ".*-->"
send "sh network-port network-1-1-1-$firstArg\r"

#capturar dados
set firstArg_output ""
expect {
    -regexp "--More--" {
        append firstArg_output $expect_out(buffer)
        send " "
        exp_continue
    }
    -re ".*NID" {
        append firstArg_output $expect_out(buffer)
        append command_responses "$firstArg_output\n"
    }
}

# Extração da linha do adminstration state
regexp {Admin State\s*:\s*(.+)} $firstArg_output -> client_int_admin_state
regexp {Operational State\s*:\s*(.+)} $firstArg_output -> client_int_operational_state

# Usar splits"
set client_admin_state_trimmed [lindex [split $client_int_admin_state "O"] 0]
set client_operational_state_trimmed [lindex [split $client_int_operational_state"S"] 0]
append final_report "Client Interface:1-1-1-$firstArg\n"
append final_report "\nAdmin State: $client_admin_state_trimmed\n"
append final_report "Operational State: $client_operational_state_trimmed\n"

#show arp
send "sh arp\r"
set timeout 5
match_max 100000

set arp_output ""
expect {
    -re {(?s)(.+)NID.*-->} {
        set arp_output $expect_out(1,string)
    }
}

append command_responses "$arp_output\n"
append final_report "----------------------------\n"
append final_report "\nARP:\n"
append final_report "$arp_output\n"


# fwd-entries
send "network-element ne-1\r"
expect -re ".*-->"
send "configure nte nte114pro-1-1-1\r"
expect -re ".*-->"
send "configure access-port access-1-1-1-$secondArg\r"
expect -re ".*-->"
send "configure flow flow-1-1-1-$secondArg-1\r"
expect -re ".*-->"
send "network-learning-ctrl mac-based\r"
expect -re ".*-->"

send "list fwd-entries\r"
sleep 1  ;# Espera 1 segundo para garantir que a resposta esteja disponível

set fwd_entries_output ""
expect {
    -regexp "--More--" {
        append fwd_entries_output $expect_out(buffer)
        send " "
        exp_continue
    }
    -re ".*-->" {
        append fwd_entries_output $expect_out(buffer)
    }
}

append command_responses "$fwd_entries_output\n"
append final_report "----------------------------\n"
append final_report "\nfwd-entries:\n"
append final_report "$fwd_entries_output\n"


puts "\n===================================================================================================="
puts "========================="
puts "Resumo dos comandos executados:"
puts "========================="
puts $command_responses
puts "=================================================="
puts "Resultado final:"
puts $final_report
puts "========================="

# Fecha a sessão
#expect eof

EOF

# Mover arquivos para executar com comandos
mv nid ~/.local/bin/
mv nid.exec ~/.local/bin/
chmod +x ~/.local/bin/nid
chmod +x ~/.local/bin/nid.exec