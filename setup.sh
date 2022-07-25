#!/bin/sh

### SCRIPT VARIABLES
SCRIPT_NAME="Void Linux Customization Script"
SCRIPT_SUBH="(c) 2022 Jeff Vos <jeff@jeffvos.dev>"
SCRIPT_DIR=$(dirname "$0")

MAIN_OPTIONS="config_nfs_repos config_shell config_xorg exit_script"

### SUPPORT FUNCTIONS

line_sep() {
  echo "------------------------------------------------------"
}

# Print a message with a prefix.
# format: print_msg style "Message 1" "Message 2"...
# does not print a newline
print_msg() {
  if [ $# -gt 1 ]; then
    case $1 in
      blank)
        prefix="   ";;
      info)
        prefix="[*]";;
      desc*)
        prefix=":::";;
      err)
        prefix="[!]";;
      prompt)
        prompt=true
        prefix="[?]";;
      action)
        prefix="-->";;
      cont)
        prompt=true
        prefix="-->";;
      number)
        number=true;;
      *)
        prefix="[?]";;
    esac
    shift 1
  else
    prefix="[*]"
  fi

  for lineno in $(seq $#)
  do
    eval message=\$$lineno
    [ $number ] && prefix="[$lineno]"
    echo -n "$prefix $message"
    [ $lineno -lt $# ] && echo
  done
  [ -z $prompt ] && echo || unset prompt
  [ $number ] && unset number
}

enter_continue() {
  line_sep
  print_msg cont "Press ENTER to continue..."
  read cont
  unset cont
  line_sep
}

# Print an error message an exit with code 1
error_abort() {
  error_msg="Error encountered. Aborting script."
  [ -n "$1" ] && error_msg="$1"
  print_msg err "$error_msg"
  exit 1
}

user_abort() {
  abort_msg="OK. Aborting script."
  [ -n "$1" ] && abort_msg="$1"
  print_msg info "$abort_msg"
  exit 2
}

# Print lines with a separator afterwards
print_subheader() {
  for line in "$@"
  do
    print_msg info "$line"
  done
  line_sep
}

# Print lines with a separator before and
# afterwards
print_header() {
  clear
  line_sep
  print_subheader "$@"
}

# Prompt the user for input
# format: question_prompt style "Question" ["option1" "option2"]
# note: options only needed if style=opts, not if style=yn
question_prompt() {
  case $1 in
    yn)
      shift 1
      print_msg prompt "$@"
      echo -n ' [y/N] '
      read yn
      line_sep
      case $yn in
        [Yy]*)
          return 0;;
        [Nn]*|*)
          return 255;;
      esac;;
    opts)
      question="$2"
      shift 2
      print_msg number "$@"
      line_sep
      print_msg prompt "$question "
      read opt
      line_sep
      if [ $opt -gt 0 ] 2>/dev/null && [ $opt -le $# ] 2>/dev/null
      then
        return $opt
      else
        return 255
      fi
  esac
}

input_prompt() {
  print_msg prompt "$1 "
  read input
}

install_pkgs() {
  for pkg in $@
  do
    print_msg action "Installing ${pkg}..."
    sudo xbps-install -Sy $pkg >/dev/null 2>&1
    case $? in
      0)
        print_msg info "Installed: $pkg";;
      *)
        error_abort "Cound not install ${pkg}. Aborting script.";;
    esac
  done
  line_sep
}

exit_script() {
  exit 0
}

### MAIN FUNCTIONS

main_menu() {
  print_header "$SCRIPT_NAME" "$SCRIPT_SUBH"
  question_prompt opts "Selected option:" $MAIN_OPTIONS
  case $? in
    1) config_nfs_repos;;
    2) config_shell;;
    3) config_xorg;;
    4) exit_script;;
    *) error_abort "Illegal option. Aborting script.";;
  esac
}

config_nfs_repos() {
  print_header "Configure NFS Void Repos"
  print_msg desc "This module configures the system to utilize a LAN" \
    "NFS server as the XBPS repository. It will install" \
    "necessary dependencies, configure options, and" \
    "install a service to manage the repos."
  line_sep
  question_prompt yn "Run setup script now?"
  [ $? -ne 0 ] && user_abort

  deps="libnfs nfs-utils"
  print_msg info "Required dependencies to be installed are:"
  print_msg action $deps
  enter_continue

  install_pkgs $deps

  question_prompt yn "Is this a Musl installation?"
  if [ $? -eq 0 ]; then
    musl=true
    print_msg action "Setting changed: libc"
    print_msg action "set to: musl"
    line_sep
  fi

  question_prompt yn "Do you want to install nonfree repos?"
  if [ $? -eq 0 ]; then
    nonfree=true
    print_msg action "Setting changed: nonfree repos"
    print_msg action "set to: active"
    line_sep
  fi


  question_prompt yn "Do you want to change any of the default server" "and directory settings?"
  if [ $? -eq 0 ]; then
    print_msg info "Default NFS server IP: ${nfs_repo_ip:=10.20.30.2}"
    question_prompt yn "Change the NFS server IP?"
    if [ $? -eq 0 ]; then
      input_prompt "IP address:"
      nfs_repo_ip="$input"
      print_msg action "Setting changed: NFS server IP"
      print_msg blank "set to: $nfs_repo_ip"
      line_sep
    fi

    print_msg info "Default NFS server path: ${nfs_repo_dir:=/srv/void}"
    question_prompt yn "Change the NFS server path?"
    if [ $? -eq 0 ]; then
      input_prompt "Server path:"
      nfs_repo_dir="$input"
      print_msg action "Setting changed: NFS server path"
      print_msg blank "set to: $nfs_repo_dir"
      line_sep
    fi

    print_msg info "Default repo mount point: ${local_mount:=/mnt/void-nfs-repos}"
    question_prompt yn "Change the repo mount point?"
    if [ $? -eq 0 ]; then
      input_prompt "Mount point:"
      local_mount="$input"
      print_msg action "Setting changed: repo mount point"
      print_msg blank "set to: $local_mount"
      line_sep
    fi

    print_msg info "Default XBPS conf directory: ${nfs_conf_dir:=/usr/local/share/xbps.nfs.d}"
    question_prompt yn "Change the XBPS conf directory?"
    if [ $? -eq 0 ]; then
      input_prompt "XBPS conf dir:"
      nfs_conf_dir="$input"
      print_msg action "Setting changed: XBPS conf dir"
      print_msg blank "set to: $nfs_conf_dir"
      line_sep
    fi
  fi

  print_msg info "NFS repo settings are ready to install."
  enter_continue

  print_msg action "Installing void-nfs-repos service..."
  sudo cp -r $SCRIPT_DIR/deps/sv/void-nfs-repos /etc/sv/ && \
    sudo ln -sf /run/runit/supervise.void-nfs-repos /etc/sv/void-nfs-repos/supervise && \
    print_msg info "Installed service: void-nfs-repos"

  print_msg action "Configuring void-nfs-repos service..."
  conf_file=/etc/sv/void-nfs-repos/conf
  [ $musl ] && sudo sh -c "echo 'MUSL=true' >> $conf_file"
  [ $nonfree ] && sudo sh -c "echo 'NONFREE=true' >> $conf_file"
  [ $nfs_repo_ip ] && sudo sh -c "echo \"NFS_REPO_IP=${nfs_repo_ip}\" >> $conf_file"
  [ $nfs_repo_dir ] && sudo sh -c "echo \"NFS_REPO_DIR=${nfs_repo_dir}\" >> $conf_file"
  [ $local_mount ] && sudo sh -c "echo \"LOCAL_MOUNT=${local_mount}\" >> $conf_file"
  [ $nfs_conf_dir ] && sudo sh -c "echo \"NFS_CONF_DIR=${nfs_conf_dir}\" >> $conf_file"
  print_msg info "Configured service: void-nfs-repos"
  line_sep

  question_prompt yn "Activate the service now?"
  if [ $? -eq 0 ]; then
    print_msg action "Activating void-nfs-repos service..."
    sudo ln -sf /etc/sv/void-nfs-repos /var/service/void-nfs-repos && \
      print_msg info "Activated service: void-nfs-repos"
  fi

  enter_continue
  main_menu
}

config_shell() {
  error_abort "Module NYI. Aborting script."
}

config_xorg() {
  error_abort "Module NYI. Aborting script."
}



main_menu
