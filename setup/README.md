# ⚙️ Scripts de Pós-instalação do Fedora RYnux

Esta pasta contém scripts modulares para personalizar o espaço do usuário (`/var/home`) sem interferir na imutabilidade do sistema base. Você pode rodar apenas os scripts que fazem sentido para o seu fluxo de trabalho.

## 📦 O que cada script faz:

* **`01-oh-my-bash.sh`**: Instala e configura o Oh My Bash para um terminal mais produtivo.
* **`02-homebrew.sh`**: Configura o gerenciador de pacotes Homebrew no espaço do usuário.
* **`03-flatpaks-dev.sh`**: Instala IDEs e ferramentas essenciais para programação.
* **`04-flatpaks-media.sh`**: Instala reprodutores de vídeo, áudio e ferramentas gráficas.
* **`05-flatpaks-produtividade.sh`**: Instala suítes de escritório, comunicação e utilitários de rede.
* **`06-flatpaks-academicos.sh`**: Instala softwares para computação numérica, simulação e visualização.
* **`07-flatpaks-configs.sh`**: Instala utilitários de sistema, monitoramento e gerenciamento.
* **`08-flatpaks-games.sh`**: Instala jogos casuais e o gerenciador de ambientes Wine (Bottles).
* **`09-microsoft-fonts.sh`**: Instala fontes essenciais da Microsoft via Homebrew (certifique-se de ter instalado o Homebrew).
* **`10-distrobox-dev-env.sh`**: Cria um contêiner isolado de alta performance com compiladores modernos, bibliotecas numéricas e ferramentas para simulações e cálculos avançados.

## 🚀 Como utilizar

1. Abra o terminal nesta pasta.
2. Dê permissão de execução aos scripts: `chmod +x *.sh`
3. Execute o script desejado: `./03-flatpaks-dev.sh`

## 🛠️ Ambiente de Desenvolvimento (Distrobox)

Para manter a raiz do sistema (Fedora RYnux) limpa e estável, todo o fluxo de trabalho pesado de desenvolvimento é realizado dentro de um contêiner **Distrobox**.

### ⚠️ Considerações Importantes
- **Base do Container:** Este script foi projetado especificamente para uma imagem base **Fedora**. Caso opte por utilizar outra distribuição dentro do Distrobox (Ubuntu, Arch, etc.), os comandos de pacotes (`dnf`) deverão ser adaptados.
- **Perfil de Uso:** O ambiente é configurado com foco no fluxo de trabalho de **Rafael Yuri** (criador da distro), incluindo ferramentas específicas para Engenharia Química, CFD (Dinâmica dos Fluidos) e desenvolvimento C++/Qt. Usuários com outras necessidades devem editar o script `10-distrobox-dev-env.sh` antes da execução.

### Conteúdo do Container:
- **IDEs:** Windsurf e Qt Creator.
- **Linguagens:** Arsenal completo C++ (GCC, Clang, OpenMP, MPI) e Python 3 (Pandas, Matplotlib, Aiohttp).
- **Bibliotecas Científicas:** OpenCV, Eigen3 (Álgebra Linear), FFTW3 (transformada rápida de Fourier), Boost e Gmsh (Geração de malhas).
- **Gráficos:** Gnuplot.
