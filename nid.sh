cat << 'EOF' > nid
#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Carrega variáveis de ambiente
source "$SCRIPT_DIR/variaveis_ambiente.sh"

# Executa o script expect com os argumentos recebidos
expect "$SCRIPT_DIR/nid.exec" "$1" "$2" "$3"
EOF

chmod +x nid

cat << 'EOF' > nid.exec
#!/usr/bin/expect -f

# Checa se o usuário pediu ajuda ou não passou os argumentos necessários
if { $argc < 2 || [lindex $argv 0] in {"--help" "-h"} } {
    puts "\n USO DO SCRIPT:"
    puts "  ./nid.exec <device> <interface>\n"
    puts "VARIÁVEIS NECESSÁRIAS:"
    puts "  número de porta do cliente → um número só"
    puts " número de porta da lec → um número só" 
    puts "EXEMPLO:"
    puts " IP_DO_NID NUMERO_DE_PORTA_LEC NUMERO_DE_PORTA_CLIENTE "
    puts " 10.226.126.112 1 3"
    exit 0
    
}


set timeout 10
set device [lindex $argv 0]
set cliente_interface [lindex $argv 1]
set lec_interface [lindex $argv 2]
set user $env(USER_NID)
set password $env(PASS_NID)
set command_responses ""
set final_report "=========================\n"

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
send "sh access-port access-1-1-1-$lec_interface\r"

#capturar dados
set lec_interface_output ""
expect {
    -exact "--More--" {
        append lec_interface_output $expect_out(buffer)
        send " "
        exp_continue
    }
    -re ".*-->" {
        append lec_interface_output $expect_out(buffer)
        append command_responses "$lec_interface_output\n"
    }
}

# Extração da linha do adminstration state
regexp {Admin State\s*:\s*(.+)} $lec_interface_output -> lec_int_admin_state
regexp {Operational State\s*:\s*(.+)} $lec_interface_output -> lec_int_operational_state

# Usar splits"
set lec_admin_state_trimmed [lindex [split $lec_int_admin_state "O"] 0]
set lec_operational_state_trimmed [lindex [split $lec_int_operational_state"S"] 0]
append final_report "\n---------------------------\n"
append final_report "Lec Interface: 1-1-1-$lec_interface\n"
append final_report "\nAdmin State: $lec_admin_state_trimmed\n"
append final_report "Operational State: $lec_operational_state_trimmed\n"
append final_report "\n---------------------------\n"

### interface cliente

# Espera prompt de modo operacional 
#expect -re ".*-->"
send "sh network-port network-1-1-1-$cliente_interface\r"

#capturar dados
set cliente_interface_output ""
expect {
    -regexp "--More--" {
        append cliente_interface_output $expect_out(buffer)
        send " "
        exp_continue
    }
    -re ".*NID" {
        append cliente_interface_output $expect_out(buffer)
        append command_responses "$cliente_interface_output\n"
    }
}

# Extração da linha do adminstration state
regexp {Admin State\s*:\s*(.+)} $cliente_interface_output -> client_int_admin_state
regexp {Operational State\s*:\s*(.+)} $cliente_interface_output -> client_int_operational_state

# Usar splits"
set client_admin_state_trimmed [lindex [split $client_int_admin_state "O"] 0]
set client_operational_state_trimmed [lindex [split $client_int_operational_state"S"] 0]
append final_report "Client Interface:1-1-1-$cliente_interface\n"
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
send "configure access-port access-1-1-1-$lec_interface\r"
expect -re ".*-->"
send "configure flow flow-1-1-1-$lec_interface-1\r"
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