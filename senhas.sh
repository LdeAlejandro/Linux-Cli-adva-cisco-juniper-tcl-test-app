cat << 'EOF' > variaveis_ambiente.sh
#!/bin/bash

#Created by Alejandro Amoroso
#Github: https://github.com/LdeAlejandro

export USER_JUNIPER=seuusuario
export PASS_JUNIPER=suasenha
export USER_NID=seuusuario
export PASS_NID=suasenha
export USER_CPE=seuusuario
export PASS_CPE=suasenha
export USER_PSR=seuusuario
export PASS_PSR=suasenha
EOF
chmod +x variaveis_ambiente.sh
source variaveis_ambiente.sh


#mover arquivos para excutar com comandos
mkdir -p ~/.local/bin
#mv nid ~/.local/bin/
#mv nid.exec ~/.local/bin/
mv variaveis_ambiente.sh ~/.local/bin/
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

