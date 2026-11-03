# ==============================================================================
# 1. Módulo KCM (Plugin do System Settings do KDE Plasma 6)
# ==============================================================================
kcmutils_add_qml_kcm(kcm_bootc
    SOURCES
        kcm_bootc.cpp
        kcm_bootc.h
)

target_link_libraries(kcm_bootc PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    Qt6::Quick
    Qt6::DBus
    KF6::CoreAddons
    KF6::I18n
    KF6::KCMUtilsQuick
    KF6::AuthCore
)

# ==============================================================================
# 2. Helper KAuth (Binário efêmero sob demanda via D-Bus System Activation)
# ==============================================================================
add_executable(kcm_bootc_authhelper
    helper/bootchelper.cpp
    helper/bootchelper.h
)

target_link_libraries(kcm_bootc_authhelper PRIVATE
    Qt6::Core
    KF6::AuthCore
    KF6::CoreAddons
)

install(
    TARGETS kcm_bootc_authhelper
    DESTINATION ${KAUTH_HELPER_INSTALL_DIR}
)

kauth_install_helper_files(
    kcm_bootc_authhelper
    org.fedoraproject.rynux.bootc
    root
)

kauth_install_actions(
    org.fedoraproject.rynux.bootc
    helper/org.fedoraproject.rynux.bootc.actions
)
