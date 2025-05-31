cat << 'EOF' > psr
#!/bin/bash

#Created by Alejandro Amoroso
#Github: https://github.com/LdeAlejandro

# Define o diretório absoluto onde o script está localizado
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Carrega variáveis de ambiente
source "$SCRIPT_DIR/variaveis_ambiente.sh"

# Executa o script expect com os argumentos recebidos
expect "$SCRIPT_DIR/psr.exec" "$1" "$2" "$3"
EOF

chmod +x psr

cat << 'EOF' > psr.exec
#!/usr/bin/expect -f
#Created by Alejandro Amoroso
#Github: https://github.com/LdeAlejandro
# Checa se o usuário pediu ajuda ou não passou os argumentos necessários
if { $argc < 2 || [lindex $argv 0] in {"--help" "-h"} } {
    puts "\n"
    puts "Documentação dos comandos psr"
    puts "  <device>        → IP ou hostname do equipamento (ex: PS1.TAT)"
    puts "  <bgp> → bgp"

    puts "\n"
    puts "  EXEMPLOS:"

    puts "  Para conectar-se ao psr apenas, use o comando:"
    puts "  psr <device>"
    puts "  Exemplo: psr PS1.TAT"
    puts "\n"

    puts "  Para conectar-se ao psr e validar bgp, use o comando:"
    puts "  psr <device> bgp"
    puts "  Comando de exemplo: psr PS1.TAT bgp"
    puts "\n"
    exit 0
}

set timeout 10
set device [lindex $argv 0]
set firstArg [lindex $argv 1]
set secondArg [lindex $argv 2]
set user $env(USER_PSR)
set password $env(PASS_PSR)
set command_responses ""
set final_report "=========================\n"

#Conexão simples
#eq valida que seja vazio o argumento "ne" valida que nao seja igual
if { $user ne "" && $password ne "" && $device ne "" && $firstArg eq "" && $secondArg eq "" } {
    puts "Conectando ao psr..."
    spawn ssh $user@$device
    expect {
        -re "Are you sure you want to continue connecting.*" {
            send "yes\r"
            exp_continue
        }
        -re ".*Password:" {
            send "$password\r"
        }
        
    }
    interact
    exit 0
}

if { $user ne "" && $password ne "" && $device ne "" && $firstArg eq "bgp" && $secondArg ne "" } {
    puts "Conectando ao psr..."
    spawn ssh $user@$device
    expect {
        -re "Are you sure you want to continue connecting.*" {
            send "yes\r"
            exp_continue
        }
        -re ".*Password:" {
            send "$password\r"
        }
        
    }
    # Envia comando para mostrar descrições da interface
    expect -re ".*>"
    send "show interfaces $secondArg descriptions\r"

    # Envia comando para mostrar info da interface
    expect -re ".*>"
    send "show interfaces $secondArg\r"

    expect -re ".*>"        ;# 
    set interface_output $expect_out(buffer)

    # Extrair IP local
    set src_ip ""
    if { [regexp {Local: ([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+)} $interface_output match src_ip] == 0 } {
        puts "❌ IP local não encontrado. Abortando..."
        exit 1
    }

    # Dividir IP em octetos
    set ip_parts [split $src_ip "."]
    set oct1 [lindex $ip_parts 0]
    set oct2 [lindex $ip_parts 1]
    set oct3 [lindex $ip_parts 2]
    set oct4 [lindex $ip_parts 3]
    set last_octet_plus1 [expr {$oct4 + 1}]
    set dst_ip "$oct1.$oct2.$oct3.$last_octet_plus1"

    # Envia comando para mostrar info da interface e routing-instance
    expect -re ".*>"
    send "show configuration routing-instances | display set | match $secondArg\r"

    #Salvar resposta do comando
    expect -re ".*>"
    set config_output $expect_out(buffer)

    # Extrai o nome da instance
    set instance_name ""
    regexp {routing-instances (\S+) interface} $config_output match instance_name

    # mostrar bgp summary instance
    send "show bgp summary instance $instance_name | match $dst_ip\r"
    expect -re ".*>"

     # ping instance
    send "ping routing-instance $instance_name $dst_ip source $src_ip rapid count 1000 do-not-fragment size 1472\r"
    expect -re ".*>"

    interact
    exit 0
}






EOF

# Mover arquivos para executar com comandos
mv psr ~/.local/bin/
mv psr.exec ~/.local/bin/
chmod +x ~/.local/bin/psr
chmod +x ~/.local/bin/psr.exec