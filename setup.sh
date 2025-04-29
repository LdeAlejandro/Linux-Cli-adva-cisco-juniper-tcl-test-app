cat << 'EOF' > variaveis_ambiente.sh
#!/bin/bash

export USER_JUNIPER=XXXXXX
export PASS_JUNIPER=XXXXXX
export USER_NID=XXXXX
export PASS_NID=XXXXX
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
