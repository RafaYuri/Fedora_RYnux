#!/bin/bash
# ==============================================================================
# Script: 01-oh-my-bash.sh
# Descrição: Instala o Oh My Bash, garante a configuração do ~/.bash_profile e
# configura a notificação de atualização pendente
# ==============================================================================

echo "🚀 Iniciando a instalação do Oh My Bash..."

# 1. Executa o instalador oficial.
# A flag --unattended garante que o script instale e saia silenciosamente,
# sem sequestrar a sessão do terminal atual.
bash -c "$(curl -fsSL https://raw.githubusercontent.com/ohmybash/oh-my-bash/master/tools/install.sh)" --unattended

echo "✅ Instalação base concluída."

# 2. Trata a exigência da documentação sobre o ~/.bash_profile
BASH_PROFILE="$HOME/.bash_profile"

if [[ -f "$BASH_PROFILE" ]]; then
    echo "🔍 O arquivo $BASH_PROFILE existe. Verificando as chamadas..."

    # Procura pela expressão "source ~/.bashrc" ou ". ~/.bashrc" ignorando espaços
    if ! grep -qE "(source|\.)\s+~/\.bashrc" "$BASH_PROFILE"; then
        echo "⚙️ Adicionando o carregamento do .bashrc ao $BASH_PROFILE..."

        # Anexa o bloco de código corretamente no final do arquivo
        cat << 'EOF' >> "$BASH_PROFILE"

# Carrega o .bashrc caso exista (Requisito do Oh My Bash)
if [[ -f ~/.bashrc ]]; then
  source ~/.bashrc
fi
EOF
        echo "✅ $BASH_PROFILE configurado com sucesso."
    else
        echo "✅ O $BASH_PROFILE já possui a chamada para o .bashrc. Nenhuma alteração necessária."
    fi
else
    # Se não existia, o instalador acabou de criar a versão padrão correta
    echo "ℹ️ O arquivo $BASH_PROFILE não existia anteriormente e foi criado pelo instalador."
fi

# 3. Injeta a notificação do bootc no ~/.bashrc de forma idempotente
BASHRC="$HOME/.bashrc"
BOOTC_CMD="[ -f /usr/local/bin/bootc-notify.sh ] && /usr/local/bin/bootc-notify.sh"

echo "🔍 Verificando o arquivo $BASHRC para a notificação do bootc..."

if [[ -f "$BASHRC" ]]; then
    if ! grep -qF "$BOOTC_CMD" "$BASHRC"; then
        echo "⚙️ Adicionando a notificação de bootc ao $BASHRC..."

        cat << 'EOF' >> "$BASHRC"

# Notificação de bootc
[ -f /usr/local/bin/bootc-notify.sh ] && /usr/local/bin/bootc-notify.sh
EOF
        echo "✅ Notificação de bootc configurada com sucesso."
    else
        echo "✅ O $BASHRC já possui a notificação de bootc. Nenhuma alteração necessária."
    fi
else
    echo "⚠️ O arquivo $BASHRC não foi encontrado. A notificação de bootc não foi adicionada."
fi

echo "🎉 Oh My Bash instalado e configurado!"
echo "👉 Para carregar o novo visual imediatamente, basta digitar: bash"
