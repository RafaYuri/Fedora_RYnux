#!/bin/bash
# ==============================================================================
# Script: 40-sysusers-and-initramfs.sh
# Descrição: Consolida contas de sistema (/etc/passwd e /etc/group) em
#            /usr/lib/passwd e /usr/lib/group (nss-altfiles) para evitar colisões
#            de UID/GID dinâmicos (como rtkit vs systemd-oom no Fedora 45) e
#            reconstrói o initramfs enxuto com suporte completo a nss-altfiles.
# ==============================================================================
set -euo pipefail

echo "👥 [40-sysusers-and-initramfs] Materializando sysusers.d e consolidando contas de sistema..."
systemd-sysusers || true

python3 - << 'PYEOF'
from pathlib import Path

etc_passwd = Path("/etc/passwd")
lib_passwd = Path("/usr/lib/passwd")
etc_group = Path("/etc/group")
lib_group = Path("/usr/lib/group")

# ----------------------------------------------------------------------
# 1. Consolidação de /etc/group -> /usr/lib/group
# ----------------------------------------------------------------------
lib_groups = {}
lib_group_lines = []
used_gids = set()

for raw in lib_group.read_text(encoding="utf-8").splitlines():
    if not raw.strip() or raw.startswith("#"):
        continue
    parts = raw.split(":")
    if len(parts) >= 4:
        name, pw, gid_s, members = parts[0], parts[1], parts[2], parts[3]
        gid = int(gid_s)
        lib_groups[name] = [name, pw, gid, [m for m in members.split(",") if m]]
        lib_group_lines.append(name)
        used_gids.add(gid)

kept_etc_groups = []
gid_remap = {}

for raw in etc_group.read_text(encoding="utf-8").splitlines():
    if not raw.strip() or raw.startswith("#"):
        continue
    parts = raw.split(":")
    if len(parts) < 4:
        continue
    name, pw, gid_s, members = parts[0], parts[1], parts[2], parts[3]
    gid = int(gid_s)
    mem_list = [m for m in members.split(",") if m]

    # Mantém root, adm, wheel (e grupos de usuário >= 1000 exceto nobody) em /etc/group
    if name in ("root", "adm", "wheel") or (gid >= 1000 and gid != 65534):
        kept_etc_groups.append(f"{name}:{pw}:{gid}:{','.join(mem_list)}")
        used_gids.add(gid)
        continue

    if name in lib_groups:
        # Mescla membros adicionais caso existam
        existing_members = lib_groups[name][3]
        for m in mem_list:
            if m not in existing_members:
                existing_members.append(m)
        if gid != lib_groups[name][2]:
            gid_remap[gid] = lib_groups[name][2]
    else:
        new_gid = gid
        if new_gid in used_gids:
            # Aloca o maior GID livre < 1000
            for candidate in range(999, 100, -1):
                if candidate not in used_gids:
                    new_gid = candidate
                    break
            gid_remap[gid] = new_gid
        used_gids.add(new_gid)
        lib_groups[name] = [name, pw, new_gid, mem_list]
        lib_group_lines.append(name)

lib_group.write_text(
    "\n".join(
        f"{g[0]}:{g[1]}:{g[2]}:{','.join(g[3])}"
        for name in lib_group_lines
        for g in [lib_groups[name]]
    ) + "\n",
    encoding="utf-8",
)
etc_group.write_text("\n".join(kept_etc_groups) + "\n", encoding="utf-8")

# ----------------------------------------------------------------------
# 2. Consolidação de /etc/passwd -> /usr/lib/passwd
# ----------------------------------------------------------------------
lib_users = {}
lib_user_lines = []
used_uids = set()

for raw in lib_passwd.read_text(encoding="utf-8").splitlines():
    if not raw.strip() or raw.startswith("#"):
        continue
    parts = raw.split(":")
    if len(parts) >= 7:
        name = parts[0]
        uid = int(parts[2])
        gid = int(parts[3])
        lib_users[name] = [name, parts[1], uid, gid, parts[4], parts[5], parts[6]]
        lib_user_lines.append(name)
        used_uids.add(uid)

kept_etc_users = []

for raw in etc_passwd.read_text(encoding="utf-8").splitlines():
    if not raw.strip() or raw.startswith("#"):
        continue
    parts = raw.split(":")
    if len(parts) < 7:
        continue
    name = parts[0]
    uid = int(parts[2])
    gid = gid_remap.get(int(parts[3]), int(parts[3]))

    # Mantém apenas root (e contas humanas >= 1000 exceto nobody) em /etc/passwd
    if name == "root" or (uid >= 1000 and uid != 65534):
        kept_etc_users.append(f"{name}:{parts[1]}:{uid}:{gid}:{parts[4]}:{parts[5]}:{parts[6]}")
        used_uids.add(uid)
        continue

    if name not in lib_users:
        new_uid = uid
        if new_uid in used_uids:
            for candidate in range(999, 100, -1):
                if candidate not in used_uids:
                    new_uid = candidate
                    break
        used_uids.add(new_uid)
        # Se existe um grupo homônimo em lib_groups, alinha o GID primário
        if name in lib_groups:
            gid = lib_groups[name][2]
        lib_users[name] = [name, parts[1], new_uid, gid, parts[4], parts[5], parts[6]]
        lib_user_lines.append(name)

lib_passwd.write_text(
    "\n".join(
        f"{u[0]}:{u[1]}:{u[2]}:{u[3]}:{u[4]}:{u[5]}:{u[6]}"
        for name in lib_user_lines
        for u in [lib_users[name]]
    ) + "\n",
    encoding="utf-8",
)
etc_passwd.write_text("\n".join(kept_etc_users) + "\n", encoding="utf-8")
print(f"Consolidados {len(lib_user_lines)} usuários em /usr/lib/passwd e {len(lib_group_lines)} grupos em /usr/lib/group.")
PYEOF

echo "⚙️ [40-sysusers-and-initramfs] Configurando ZRAM e Dracut (com suporte a nss-altfiles no initramfs)..."
cat << 'EOF' > /etc/systemd/zram-generator.conf
[zram0]
zram-size = ram
compression-algorithm = zstd
EOF

mkdir -p /etc/dracut.conf.d
cat << 'EOF' > /etc/dracut.conf.d/01-lean-initramfs.conf
hostonly="no"
reproducible="yes"
do_strip="yes"
omit_drivers+=" amdgpu nouveau i915 xe "
omit_dracutmodules+=" network network-manager lvm mdraid multipath fips iscsi nfs cifs qemu qemu-net "
install_items+=" /usr/lib/passwd /usr/lib/group /etc/nsswitch.conf /etc/authselect/nsswitch.conf /usr/lib64/libnss_altfiles.so.2 "
EOF

echo "📦 [40-sysusers-and-initramfs] Gerando initramfs enxuto com compressão zstd -19..."
kver="$(rpm -q kernel-core --queryformat '%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort -V | tail -n 1)"
dracut -vf --compress "zstd -19 -T0" "/usr/lib/modules/${kver}/initramfs.img" "${kver}"

echo "✅ [40-sysusers-and-initramfs] Concluído com sucesso."
