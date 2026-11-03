cmake_minimum_required(VERSION 3.22)

project(kcm-bootc VERSION 1.0.0 LANGUAGES CXX)

set(QT_MIN_VERSION "6.6.0")
set(KF6_MIN_VERSION "6.0.0")

find_package(ECM ${KF6_MIN_VERSION} REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)
include(FeatureSummary)

remove_definitions(-DQT_NO_CAST_FROM_ASCII)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 ${QT_MIN_VERSION} CONFIG REQUIRED COMPONENTS
    Core
    Gui
    Qml
    Quick
    DBus
)

find_package(KF6 ${KF6_MIN_VERSION} REQUIRED COMPONENTS
    CoreAddons
    I18n
    KCMUtils
    Auth
)

add_subdirectory(src)

# Regra Polkit para permitir leitura de status sem senha para sessões locais ativas
install(
    FILES polkit/90-rynux-kcm-bootc.rules
    DESTINATION ${KDE_INSTALL_DATADIR}/polkit-1/rules.d
)

# Script e unidades systemd user (daemonless via PathExists=/run/reboot-required)
install(
    PROGRAMS desktop/rynux-bootc-desktop-notify.sh
    DESTINATION ${KDE_INSTALL_BINDIR}
)

install(
    FILES
        systemd/rynux-bootc-reboot-notify.path
        systemd/rynux-bootc-reboot-notify.service
    DESTINATION ${CMAKE_INSTALL_PREFIX}/lib/systemd/user
)

feature_summary(WHAT ALL INCLUDE_QUIET_PACKAGES FATAL_ON_MISSING_REQUIRED_PACKAGES)
