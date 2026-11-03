# Bootc KCM — Módulo de Gerenciamento de Imagem (`bootc`) para o KDE Plasma 6

Módulo nativo para o **System Settings (`systemsettings`) do KDE Plasma 6**, desenvolvido em **C++20 / Qt 6 / KDE Frameworks 6 (KCMUtils, Kirigami e KAuth)** especialmente para o **Fedora RYnux**.

Seu objetivo é fornecer uma interface gráfica leve, moderna e **100% *daemonless*** (0 MB de consumo de RAM em segundo plano) para inspecionar e gerenciar imagens de sistema baseadas em contêineres inicializáveis (`bootc`).

---

## 🏗️ Arquitetura (Zero Daemon em Background)

Diferente de abordagens tradicionais (como backends residentes em Python para o Discover), este módulo utiliza exclusivamente mecanismos sob demanda do KDE Frameworks 6 e do systemd:

1. **Elevação de Privilégio Efêmera via `KF6::Auth` (`KAuth`):**
   * O comando `bootc` exige privilégios de `root` até mesmo para leitura (`bootc status --format=json`).
   * Quando o usuário abre o módulo no *System Settings*, o plugin `kcm_bootc.so` (rodando sem privilégios na sessão do usuário) invoca o helper `kcm_bootc_authhelper` via **D-Bus System Bus Activation** + **Polkit**.
   * A regra Polkit (`polkit/90-rynux-kcm-bootc.rules`) permite que sessões locais ativas consultem o status (`status`) e verifiquem atualizações (`check`) **sem solicitar senha**, e permite que usuários do grupo `wheel` baixem/preparem atualizações (`upgrade`) de forma transparente.
   * Assim que o comando `bootc` termina, o binário do helper **se encerra imediatamente** — não resta nenhum daemon residente na memória.

2. **Notificação de Reboot Pendente 100% Daemonless (`/run/reboot-required`):**
   * Aproveitando a lógica já existente no `/usr/local/bin/bootc-notify.sh` do Fedora RYnux (que verifica a existência do arquivo `/run/reboot-required` ao abrir o terminal), este projeto adiciona duas camadas gráficas **sem daemon**:
     * **Com o KCM aberto:** um `QFileSystemWatcher` monitora `/run` via `inotify` do kernel e exibe instantaneamente o banner verde **"Reiniciar Agora"** assim que `/run/reboot-required` surge.
     * **Em segundo plano na sessão gráfica:** a unidade `systemd --user` `rynux-bootc-reboot-notify.path` usa a diretiva `PathExists=/run/reboot-required` (monitorada pelo próprio `systemd` da sessão do usuário, com **0 bytes de RAM extra**). No exato instante em que o timer do `bootc` prepara uma atualização *staged* e cria `/run/reboot-required`, o systemd dispara o script oneshot `rynux-bootc-desktop-notify.sh`, exibindo uma notificação nativa do KDE Plasma com botões **"Reiniciar Agora"** e **"Abrir Painel Bootc"**.

---

## ✨ Funcionalidades

* **Imagem Ativa (`Booted`):** Exibe a referência completa da imagem OCI, versão, data/hora de compilação, transporte, arquitetura, status de *pinning* e o digest `SHA256` (com botões para copiar para a área de transferência).
* **Imagem Preparada (`Staged`):** Detecta automaticamente quando há uma atualização baixada aguardando reboot (via JSON do `bootc` e `/run/reboot-required`), exibindo um banner em destaque com botão **"Reiniciar Agora"** (integrado ao diálogo nativo `org.kde.LogoutPrompt` do Plasma 6).
* **Verificação e Download de Atualizações:**
  * **Verificar Atualizações (`bootc upgrade --check`):** Consulta os metadados do registro remoto sem baixar as camadas e avisa se há uma nova versão disponível.
  * **Baixar e Aplicar (`bootc upgrade`):** Baixa e prepara a nova imagem em modo *staged*, transmitindo o log do `bootc` linha a linha em tempo real para a interface do KCM.
* **Recuperação Atômica (`Rollback`):** Exibe os metadados do deployment anterior (`rollback`) quando disponível e permite agendar a reversão para o próximo boot (`bootc rollback`) com confirmação de segurança.
* **Controle de Automação:** Permite ativar ou desativar diretamente pela interface o timer nativo `bootc-fetch-apply-updates.timer`.

---

## 📂 Estrutura do Projeto

```text
Bootc KCM/
├── CMakeLists.txt                                 # Configuração principal do CMake (Qt6 + KF6)
├── README.md                                      # Esta documentação
├── install.sh                                     # Script de compilação e instalação (nativo ou via Podman)
├── uninstall.sh                                   # Script de remoção completa
├── desktop/
│   ├── kcm_bootc.desktop                          # Atalho para System Settings, KRunner e Menu de Apps
│   └── rynux-bootc-desktop-notify.sh              # Script oneshot de notificação nativa no KDE
├── polkit/
│   └── 90-rynux-kcm-bootc.rules                   # Regras Polkit para leitura sem senha em sessão local
├── systemd/
│   ├── rynux-bootc-reboot-notify.path             # Gatilho inotify systemd user (PathExists=/run/reboot-required)
│   └── rynux-bootc-reboot-notify.service          # Serviço oneshot acionado pelo .path
└── src/
    ├── CMakeLists.txt                             # Targets do plugin KCM e do helper KAuth
    ├── kcm_bootc.json                             # Metadados KPlugin para o System Settings
    ├── kcm_bootc.h                                # Header do backend C++ (KQuickManagedConfigModule)
    ├── kcm_bootc.cpp                              # Implementação do KCM, parser JSON e chamadas KAuth
    ├── helper/
    │   ├── bootchelper.h                          # Header do helper privilegiado KAuth
    │   ├── bootchelper.cpp                        # Execução segura do /usr/bin/bootc e streaming de progresso
    │   └── org.fedoraproject.rynux.bootc.actions  # Definição das ações Polkit/KAuth
    └── ui/
        └── main.qml                               # Interface QML (Kirigami + QtQuick Controls 2)
```

---

## 🚀 Como Compilar e Instalar

### Cenário 1: Testando diretamente em uma máquina Fedora RYnux em execução (Host Imutável)

Em um sistema `bootc` já instalado, `/usr` é montado como somente-leitura e pacotes `-devel` não ficam instalados na imagem final. O script `install.sh` detecta isso automaticamente:
1. Compila o código-fonte dentro de um container **Podman** efêmero (`quay.io/fedora/fedora`), sem sujar o seu host com pacotes `-devel`;
2. Oferece ativar `bootc usr-overlay` (ou aceita a flag `--usr-overlay`) para permitir gravar os binários compilados em `/usr` imediatamente para teste:

```bash
cd "Bootc KCM"
./install.sh --usr-overlay
```

Para abrir o módulo após a instalação:
```bash
systemsettings kcm_bootc
```
*(Ou abra o **Configurações do Sistema** do KDE -> categoria **Administração do Sistema** -> **Imagem do Sistema (bootc)**).*

### Cenário 2: Compilação Nativa (Ambientes mutáveis ou Distrobox)

Caso esteja compilando em um ambiente Fedora tradicional, basta executar:
```bash
cd "Bootc KCM"
./install.sh
```

---

## 🗑️ Como Desinstalar

Para remover todos os arquivos instalados (`.so`, helper KAuth, políticas Polkit, serviços D-Bus e unidades systemd) e atualizar o cache do KDE Plasma:

```bash
cd "Bootc KCM"
./uninstall.sh
```

---

## 📦 Como Integrar Definitivamente no `Containerfile` do Fedora RYnux

Para que o **Bootc KCM** faça parte nativa da imagem do Fedora RYnux (sem depender de `usr-overlay`), você pode compilá-lo em um estágio separado (*multi-stage build*) no `Containerfile` para que nenhum pacote `-devel` ou compilador vá parar na imagem final!

Exemplo de adição no `Containerfile`:

```dockerfile
# ====================================================================
# ESTÁGIO AUXILIAR: Compilação do Bootc KCM (Zero pacotes -devel na imagem final)
# ====================================================================
FROM quay.io/fedora/fedora-bootc:45 AS kcm-builder
COPY ["Bootc KCM/", "/tmp/bootc-kcm/"]
RUN --mount=type=cache,dst=/var/cache/dnf \
    dnf install --setopt=tsflags=nodocs -y \
        cmake extra-cmake-modules gcc-c++ ninja-build gettext \
        qt6-qtbase-devel qt6-qtdeclarative-devel \
        kf6-kcoreaddons-devel kf6-ki18n-devel kf6-kcmutils-devel kf6-kauth-devel && \
    cmake -B /tmp/bootc-kcm/build -S /tmp/bootc-kcm \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_TESTING=OFF && \
    cmake --build /tmp/bootc-kcm/build --parallel "$(nproc)" && \
    DESTDIR=/tmp/kcm-install cmake --install /tmp/bootc-kcm/build
```

E no estágio `final` do `Containerfile`:
```dockerfile
COPY --from=kcm-builder /tmp/kcm-install/ /
RUN systemctl --global enable rynux-bootc-reboot-notify.path
```

---

## 🧪 Como Testar a Notificação Gráfica de Reboot Pendente

Você pode simular a chegada de uma atualização *staged* do `bootc` criando o arquivo `/run/reboot-required`:

```bash
sudo touch /run/reboot-required
```

* Se a unidade `rynux-bootc-reboot-notify.path` estiver ativa (`systemctl --user status rynux-bootc-reboot-notify.path`), o KDE Plasma exibirá **imediatamente** a notificação gráfica com os botões **"Reiniciar Agora"** e **"Abrir Painel Bootc"**.
* Se a janela do `systemsettings kcm_bootc` estiver aberta, o banner verde de reinicialização aparecerá automaticamente no topo do módulo.

Para limpar o teste:
```bash
sudo rm -f /run/reboot-required
systemctl --user reset-failed rynux-bootc-reboot-notify.service 2>/dev/null || true
```
