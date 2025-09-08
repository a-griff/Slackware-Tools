#!/bin/bash
#
# installed_pkgs.sh
#
# List installed packages on Slackware, with options to filter and format output.
#
# -----------------------------------------------------------------------------
# USAGE:
#   ./installed_pkgs.sh [options]
#
# OPTIONS:
#   -b    Show only base (official) packages
#   -3    Show only 3rd-party packages
#   -s    Show short names only (strip version, arch, build/tag)
#   -l    Show short names as a space-separated list (for sbotools reload, etc.)
#   -c    Show counts only (number of base and/or 3rd-party packages)
#   -h    Show this help
#
# DEFAULT BEHAVIOR:
#   If no options are given, show all installed packages (base + 3rd-party),
#   grouped into "Base packages installed" and "3rd-party packages installed".
#
# DEFINITIONS:
#   - Base (official) package: tag is purely numeric (e.g. "-1", "-2")
#   - 3rd-party package: tag is non-numeric (e.g. "_SBo", "_alien", "_ponce")
#
# EXAMPLES:
#   Show all installed packages (default grouping):
#       ./installed_pkgs.sh
#
#   Show only 3rd-party packages, short names only:
#       ./installed_pkgs.sh -3 -s
#
#   Show only base packages, as a space-separated list (good for sbotools):
#       ./installed_pkgs.sh -b -l
#
#   Show count of base vs 3rd-party:
#       ./installed_pkgs.sh -c
# -----------------------------------------------------------------------------

PKGLOG="/var/log/packages"

show_base=false
show_3rd=false
short_names=false
list_mode=false
count_mode=false

# Parse arguments
while getopts "b3slch" opt; do
  case $opt in
    b) show_base=true ;;
    3) show_3rd=true ;;
    s) short_names=true ;;
    l) list_mode=true; short_names=true ;;  # -l implies short names
    c) count_mode=true ;;
    h)
      grep '^# ' "$0" | sed 's/^# //'
      exit 0
      ;;
  esac
done

# Helper: get package name, version, arch, build/tag
parse_pkg() {
  local pkg=$1
  local name=$(echo "$pkg" | rev | cut -d- -f4- | rev)
  local ver=$(echo "$pkg" | rev | cut -d- -f3 | rev)
  local arch=$(echo "$pkg" | rev | cut -d- -f2 | rev)
  local tag=$(echo "$pkg" | rev | cut -d- -f1 | rev)
  echo "$name" "$ver" "$arch" "$tag"
}

base_pkgs=()
third_pkgs=()

# Classify installed packages
for pkg in $(ls -1 "$PKGLOG"); do
  read -r name ver arch tag <<<"$(parse_pkg "$pkg")"
  if [[ "$tag" =~ ^[0-9]+$ ]]; then
    base_pkgs+=("$pkg")
  else
    third_pkgs+=("$pkg")
  fi
done

format_pkglist() {
  local pkgs=("$@")
  local out=()
  for pkg in "${pkgs[@]}"; do
    if $short_names; then
      out+=("$(echo "$pkg" | rev | cut -d- -f4- | rev)")
    else
      out+=("$pkg")
    fi
  done
  if $list_mode; then
    echo "${out[*]}"
  else
    printf "%s\n" "${out[@]}"
  fi
}

# Count-only mode
if $count_mode; then
  if $show_base && ! $show_3rd; then
    echo "Base packages: ${#base_pkgs[@]}"
  elif $show_3rd && ! $show_base; then
    echo "3rd-party packages: ${#third_pkgs[@]}"
  else
    echo "Base packages: ${#base_pkgs[@]}"
    echo "3rd-party packages: ${#third_pkgs[@]}"
    echo "Total: $(( ${#base_pkgs[@]} + ${#third_pkgs[@]} ))"
  fi
  exit 0
fi

# Decide what to display
if $show_base && ! $show_3rd; then
  format_pkglist "${base_pkgs[@]}"
elif $show_3rd && ! $show_base; then
  format_pkglist "${third_pkgs[@]}"
else
  echo "Base packages installed:"
  format_pkglist "${base_pkgs[@]}"
  echo
  echo "3rd-party packages installed:"
  format_pkglist "${third_pkgs[@]}"
fi

