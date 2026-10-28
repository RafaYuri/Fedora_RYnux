#!/bin/bash
# ==============================================================================
# Script: 20-shell-and-homebrew.sh
# Descrição: Incorpora o Oh My Bash, a notificação de atualização do bootc e o
#            Homebrew nativamente na imagem do sistema, configurando /etc/skel
#            e o serviço de provisionamento automático em /home/linuxbrew.
# ==============================================================================
set -euo pipefail

echo "🔔 [20-shell-and-homebrew] Instalando script de notificação de reboot (bootc-notify.sh)..."
cat << 'EOF' > /usr/local/bin/bootc-notify.sh
#!/bin/bash
if [ -f /run/reboot-required ]; then
    echo -e "\e[1;36m🔄 Atualização pendente, reinicie para aplicação.\e[0m"
fi
EOF
chmod +x /usr/local/bin/bootc-notify.sh

echo "🐚 [20-shell-and-homebrew] Instalando Oh My Bash em /usr/share/oh-my-bash..."
rm -rf /usr/share/oh-my-bash
git clone --depth=1 https://github.com/ohmybash/oh-my-bash.git /usr/share/oh-my-bash
rm -rf /usr/share/oh-my-bash/.git

echo "📝 [20-shell-and-homebrew] Configurando /etc/skel/.bashrc e /etc/skel/.bash_profile..."
mkdir -p /etc/skel

cat << 'EOF' > /etc/skel/.bashrc
# Enable the subsequent settings only in interactive sessions
case $- in
  *i*) ;;
    *) return;;
esac

# Path to your oh-my-bash installation (usa ~/.oh-my-bash se existir localmente,
# caso contrário utiliza a instalação imutável do sistema em /usr/share/oh-my-bash)
if [ -d "$HOME/.oh-my-bash" ]; then
  export OSH="$HOME/.oh-my-bash"
else
  export OSH="/usr/share/oh-my-bash"
  export DISABLE_AUTO_UPDATE="true"
fi

# Tema padrão do Oh My Bash
OSH_THEME="font"

# Permite uso de sudo em plugins/aliases do Oh My Bash
OMB_USE_SUDO=true

# Completions, Aliases e Plugins carregados por padrão
completions=(
  git
  composer
  ssh
)

aliases=(
  general
)

plugins=(
  git
  bashmarks
)

if [ -f "$OSH/oh-my-bash.sh" ]; then
  source "$OSH/oh-my-bash.sh"
fi

# Inicialização do Homebrew
if [ -x "/home/linuxbrew/.linuxbrew/bin/brew" ]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
elif [ -x "$HOME/.linuxbrew/bin/brew" ]; then
  eval "$("$HOME/.linuxbrew/bin/brew" shellenv)"
fi

# Diretório de binários locais do usuário
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac

# Notificação de atualização pendente do bootc
[ -f /usr/local/bin/bootc-notify.sh ] && /usr/local/bin/bootc-notify.sh
EOF

cat << 'EOF' > /etc/skel/.bash_profile
# .bash_profile

# Carrega o .bashrc caso exista (Requisito do Oh My Bash e sessões de login)
if [[ -f ~/.bashrc ]]; then
  source ~/.bashrc
fi

# Diretório de binários locais do usuário
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac
EOF

echo "🍺 [20-shell-and-homebrew] Pré-instalando Homebrew em /usr/share/homebrew/.linuxbrew..."
rm -rf /usr/share/homebrew
mkdir -p /usr/share/homebrew/.linuxbrew/{bin,etc,include,lib,opt,sbin,share,var/homebrew/linked,Cellar,Caskroom,Frameworks}

git clone https://github.com/Homebrew/brew /usr/share/homebrew/.linuxbrew/Homebrew
ln -sf ../Homebrew/bin/brew /usr/share/homebrew/.linuxbrew/bin/brew

# Pré-baixa o Portable Ruby do Homebrew na imagem para uso imediato no primeiro boot.
# Nota: Em imagens bootc/OSTree, /root é um symlink para /var/roothome (que não existe
# durante o build para manter /var vazio). Por isso redirecionamos HOME e HOMEBREW_CACHE
# temporariamente para /tmp durante o download do Portable Ruby.
mkdir -p /tmp/homebrew-home /tmp/homebrew-cache /tmp/homebrew-logs /tmp/homebrew-temp
HOME="/tmp/homebrew-home" \
HOMEBREW_CACHE="/tmp/homebrew-cache" \
HOMEBREW_LOGS="/tmp/homebrew-logs" \
HOMEBREW_TEMP="/tmp/homebrew-temp" \
HOMEBREW_FORCE_VENDOR_RUBY=1 \
    /usr/share/homebrew/.linuxbrew/bin/brew setup-ruby

HOME="/tmp/homebrew-home" \
HOMEBREW_CACHE="/tmp/homebrew-cache" \
    /usr/share/homebrew/.linuxbrew/bin/brew --version

# Limpa caches temporários gerados durante o setup do Portable Ruby
rm -rf /tmp/homebrew-*

echo "⚙️ [20-shell-and-homebrew] Criando serviço de materialização do Homebrew no subvolume /home..."
cat << 'EOF' > /usr/local/bin/rynux-homebrew-init.sh
#!/bin/bash
# ==============================================================================
# Script: rynux-homebrew-init.sh
# Descrição: Materializa a instalação pré-empacotada do Homebrew de
#            /usr/share/homebrew/.linuxbrew para /home/linuxbrew/.linuxbrew
#            no subvolume BTRFS persistente (/home) e ajusta permissões para o
#            usuário principal do sistema.
# ==============================================================================
set -euo pipefail

BREW_SRC="/usr/share/homebrew/.linuxbrew"
BREW_PARENT="/home/linuxbrew"
BREW_DST="${BREW_PARENT}/.linuxbrew"

if [ ! -d "$BREW_SRC" ]; then
    echo "Erro: Diretório fonte $BREW_SRC não encontrado na imagem." >&2
    exit 1
fi

# Determina o UID e GID do usuário humano principal (>= 1000 e < 60000).
# Caso o serviço rode no 1º boot antes do plasma-setup criar o usuário no /etc/passwd,
# utiliza 1000:1000, que é o UID:GID atribuído ao primeiro usuário criado no Fedora.
TARGET_UG="$(awk -F: '$3 >= 1000 && $3 < 60000 { print $3 ":" $4; exit }' /etc/passwd)"
if [ -z "$TARGET_UG" ]; then
    TARGET_UG="1000:1000"
fi

if [ ! -x "${BREW_DST}/bin/brew" ]; then
    echo "📦 Materializando Homebrew em ${BREW_DST}..."
    mkdir -p "$BREW_PARENT"
    cp -a "$BREW_SRC" "$BREW_DST"
fi

# Garante que o diretório pertença ao usuário principal para uso sem sudo
CURRENT_UG="$(stat -c '%u:%g' "$BREW_DST" 2>/dev/null || echo '')"
if [ "$CURRENT_UG" != "$TARGET_UG" ]; then
    chown -R "$TARGET_UG" "$BREW_PARENT"
fi

echo "✅ Homebrew pronto em ${BREW_DST} (proprietário ${TARGET_UG})."
EOF
chmod +x /usr/local/bin/rynux-homebrew-init.sh

cat << 'EOF' > /usr/lib/systemd/system/rynux-homebrew-init.service
[Unit]
Description=Fedora RYnux - Inicialização do Homebrew em /home/linuxbrew
Documentation=https://github.com/RafaYuri/Fedora_RYnux
After=local-fs.target home.mount var-home.mount
ConditionPathExists=/usr/share/homebrew/.linuxbrew/bin/brew
ConditionPathExists=!/home/linuxbrew/.linuxbrew/bin/brew

[Service]
Type=oneshot
ExecStart=/usr/local/bin/rynux-homebrew-init.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl enable rynux-homebrew-init.service
echo "✅ [20-shell-and-homebrew] Oh My Bash, bootc-notify e Homebrew configurados com sucesso."
