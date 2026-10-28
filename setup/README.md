# ⚙️ Central de Pós-Instalação do Fedora RYnux (`rynux-setup`)

A partir da versão 45 do **Fedora RYnux**, as ferramentas de base do terminal (**Oh My Bash**, **notificação automática de atualizações do `bootc`** no `.bashrc` e o gerenciador de pacotes **Homebrew**) já vêm **instaladas e configuradas por padrão na imagem do sistema**!

Os demais scripts modulares para personalizar o espaço do usuário (`/var/home`) também já vêm **embutidos nativamente na imagem** (em `/usr/share/rynux/setup`) e podem ser executados a qualquer momento através da aplicação interativa TUI **`rynux-setup`** (ou pelo atalho **"Pós-Instalação do Fedora RYnux"** no menu de aplicativos do KDE Plasma), sem necessidade de clonar ou baixar scripts do GitHub.

## 🚀 Como utilizar a aplicação TUI (`rynux-setup`)

Basta abrir o terminal em qualquer diretório e executar:

```bash
rynux-setup
```

* Use as setas **`↑` / `↓`** para navegar entre os módulos;
* Pressione **`Espaço`** (ou **`x`**) para marcar/desmarcar quantos módulos desejar (ou selecione **🌟 Instalar TODOS os módulos**);
* Pressione **`Enter`** para confirmar e iniciar a instalação automatizada.

### Opções rápidas via linha de comando (CLI):
* `rynux-setup --list` — Lista todos os módulos disponíveis.
* `rynux-setup --all` — Executa todos os módulos sequencialmente sem abrir o menu.
* `rynux-setup --run 01` — Executa diretamente um módulo específico pelo número.

---

## 📦 O que cada módulo embutido faz:

* **`01-flatpaks-dev.sh`**: Instala IDEs e ferramentas essenciais para programação e hardware (Arduino IDE 2, Podman Desktop, SerialTest, Kontainer).
* **`02-flatpaks-media.sh`**: Instala reprodutores de vídeo/áudio, edição de imagem e modelagem 3D (FreeCAD, GIMP, VLC, Haruna, OBS Studio, Upscayl, Draw.io, KolourPaint, KColorChooser, Camera).
* **`03-flatpaks-produtividade.sh`**: Instala suítes de escritório, comunicação e utilitários de rede (LibreOffice, OnlyOffice, Foliate, Rclone Manager, KClock, Telegram, qBittorrent, Media Downloader, LocalSend, Brave Browser).
* **`04-flatpaks-academicos.sh`**: Instala softwares para computação numérica, simulação e visualização (Scilab, Octave, wxMaxima, ParaView).
* **`05-flatpaks-configs.sh`**: Instala utilitários de sistema, monitoramento e gerenciamento (Flatseal, Gear Lever, CPU-X, Mission Center, Fedora Media Writer).
* **`06-flatpaks-games.sh`**: Instala jogos casuais e o gerenciador de ambientes Wine (Bottles, SuperTuxKart, Space Cadet Pinball).
* **`07-microsoft-fonts.sh`**: Instala fontes essenciais da Microsoft via Homebrew (Office, Aptos, Arial, Times New Roman, Georgia, Courier New).
* **`08-distrobox-dev-env.sh`**: Cria um contêiner isolado de alta performance (`dev-lab`) com compiladores modernos, bibliotecas numéricas e ferramentas para simulações e cálculos avançados.

---

## 🛠️ Ambiente de Desenvolvimento (Distrobox)

Para manter a raiz do sistema (Fedora RYnux) limpa e estável, todo o fluxo de trabalho pesado de desenvolvimento é realizado dentro de um contêiner **Distrobox**.

### ⚠️ Considerações Importantes
- **Base do Container:** Este script foi projetado especificamente para uma imagem base **Fedora**. Caso opte por utilizar outra distribuição dentro do Distrobox (Ubuntu, Arch, etc.), os comandos de pacotes (`dnf`) deverão ser adaptados.
- **Perfil de Uso:** O ambiente é configurado com foco no fluxo de trabalho de **Rafael Yuri** (criador da distro), incluindo ferramentas específicas para Engenharia Química, CFD (Dinâmica dos Fluidos) e desenvolvimento C++/Qt. Usuários com outras necessidades podem copiar e editar `/usr/share/rynux/setup/08-distrobox-dev-env.sh`.

### Conteúdo do Container:
- **IDEs:** VS Code e Qt Creator.
- **Linguagens:** Arsenal completo C++ (GCC, Clang, OpenMP, MPI) e Python 3 (Pandas, Matplotlib, Aiohttp).
- **Bibliotecas Científicas:** OpenCV, Eigen3 (Álgebra Linear), FFTW3 (transformada rápida de Fourier), Boost e Gmsh (Geração de malhas).
- **Gráficos:** Gnuplot.
