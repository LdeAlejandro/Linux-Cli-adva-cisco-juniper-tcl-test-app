cat << 'EOF' > cpe
#!/bin/bash

#Created by Alejandro Amoroso
#Github: https://github.com/LdeAlejandro

# Define o diretório absoluto onde o script está localizado
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Carrega variáveis de ambiente
source "$SCRIPT_DIR/variaveis_ambiente.sh"

# Executa o script expect com os argumentos recebidos
expect "$SCRIPT_DIR/cpe.exec" "$1" "$2" "$3"
EOF

chmod +x cpe

cat << 'EOF' > cpe.exec
#!/usr/bin/expect -f
#Created by Alejandro Amoroso
#Github: https://github.com/LdeAlejandro
# Checa se o usuário pediu ajuda ou não passou os argumentos necessários
if { $argc < 2 || [lindex $argv 0] in {"--help" "-h"} } {
    puts "\n"
    puts "Documentação dos comandos cpe"
    puts "  <device>        → IP ou hostname do equipamento (ex: 172.28.15.208)"
    puts "  <bgp> → bgp"

    puts "\n"
    puts "  EXEMPLOS:"

    puts "  Para conectar-se ao cpe apenas, use o comando:"
    puts "  cpe <device>"
    puts "  Exemplo: cpe 172.28.15.208"
    puts "\n"

    puts "  Para conectar-se ao cpe e validar bgp, use o comando:"
    puts "  cpe <device> bgp"
    puts "  Comando de exemplo: cpe 172.28.15.208 bgp"
    puts "\n"
    exit 0
}

set timeout 10
set device [lindex $argv 0]
set firstArg [lindex $argv 1]
set secondArg [lindex $argv 2]
set user $env(USER_CPE)
set password $env(PASS_CPE)
set command_responses ""
set final_report "=========================\n"

#Conexão simples
#eq valida que seja vazio o argumento "ne" valida que nao seja igual
if { $user ne "" && $password ne "" && $device ne "" && $firstArg eq "" && $secondArg eq "" } {
    puts "Conectando ao cpe..."
    spawn ssh $user@$device
    expect {
        -re "Are you sure you want to continue connecting.*" {
            send "yes\r"
            exp_continue
        }
        -re ".*Prove it:" {
            send "$password\r"
        }
    }
    interact
    exit 0
}

#Conexão e bgp
if { $user ne "" && $password ne "" && $device ne "" && $firstArg eq "bgp"} {
    puts "Conectando ao cpe validando BGP..."
    spawn ssh $user@$device
    expect {
        -re "Are you sure you want to continue connecting.*" {
            send "yes\r"
            exp_continue
        }
        -re ".*Prove it:" {
            send "$password\r"
        }
    }

    #envia  comando bgp
    expect -re ".*#"
    send "sh bgp summary\r"
    interact
    exit 0
}


EOF

# Mover arquivos para executar com comandos
mv cpe ~/.local/bin/
mv cpe.exec ~/.local/bin/
chmod +x ~/.local/bin/cpe
chmod +x ~/.local/bin/cpe.exec