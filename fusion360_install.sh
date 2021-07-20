#!/bin/sh

# This short script will help you install Autodesk Fusion 360 on your Arch based Linux distribution
# Forked from https://github.com/link12765/Fusion-360-Arch-Linux-Script
# Original Author: Dylan Dean Goebel - Contact: goebeld @ https://www.reddit.com/user/goebeld
# 
# Modified by Andrej Kenda (Kndndrj)

###########################################################
## Presets                                               ##
###########################################################
RED="\033[1;31m"
GREEN="\033[1;32m"
BROWN="\033[1;33m"
BLUE="\033[1;34m"
NC="\033[0m"
USAGE="$0 [-p <wine_prefix>] [-t <temp_dir>] [-c] [-h] [-l <logfile>]\n\
  -p wine_prefix  -- Path to directory to put a wineprefix in (basically an install directory),\n\
                     must be an absolute path!\n\
  -t temp_dir     -- Path to temporary directory (where to store downloads).\n\
  -c              -- Clean install (delete old files before installing).\n\
  -l logfile      -- Specify your own log file.\n\
  -h              -- Print this message and exit\n"
FAIL_MESSAGE="${RED}Installation failed!${NC}\n\
  The file may be corrupt!\n\
  Please consider doing a clean install (use the \"-c\" flag).\n\
  If you already tried that, check that you have the appropriate drivers installed.\n"

###########################################################
## Helper functions                                      ##
###########################################################
packages_install() {
  printf "\n${GREEN}Updating the system and installing prerequisites!${NC}\n\n"

  sudo pacman -Syu wine wine-gecko wine-mono p7zip curl wget
  if [ $? -ne 0 ]; then
    printf "${RED}Required packages could not be installed!${NC}\n"
    printf "Please make sure that you have enabled the \"multilib\" repository for pacman!\n"
    printf "To do this, uncomment the following lines in \"/etc/pacman.conf\":\n"
    printf "\t[multilib]\n"
    printf "\tInclude = /etc/pacman.d/mirrorlist\n\n"
    exit 1
  fi
}

winetricks_install() {
  # Download winetricks if it isn't in the temporary directory already
  if [ ! -e "$TEMPDIR/winetricks" ]; then
    printf "\n${BLUE}Downloading Winetricks!${NC}\n\n"
    # Download
    wget -P "$TEMPDIR" "https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks"
    chmod +x $TEMPDIR/winetricks
  fi

  # Run winetricks (automatically makes a prefix in $INSTALLDIR)
  printf "\n${GREEN}Running Winetricks!${NC}\n\n"
  WINEPREFIX=$INSTALLDIR $TEMPDIR/winetricks atmlib gdiplus msxml3 msxml6 vcrun2017 corefonts fontsmooth=rgb \
                                             winhttp win10 | tee $LOGDIR/winetricks_setup.log
  if [ $? -ne 0 ]; then
    printf "$FAIL_MESSAGE"
    exit 1
  fi
}

dxvk_install() {
  # Download DXVK if it isn't in the temporary directory already
  if [ ! -e "$TEMPDIR/dxvk_extracted/setup_dxvk.sh" ]; then
    printf "\n${BLUE}Downloading DXVK!${NC}\n\n"
    # If this file is already downloaded, delete it (might be corrupt)
    rm -rf "$TEMPDIR/DXVK.tar.gz"
    # Get the latest release of "DXVK"
    DXVK_INFO=$(curl --silent "https://api.github.com/repos/doitsujin/dxvk/releases/latest")
    DXVK_TAG=$(printf "${DXVK_INFO}\n" | grep -E "\"tag_name\":" | sed -E "s/.*\"([^\"]+)\".*/\1/")
    DXVK_DLNAME=$(printf "${DXVK_INFO}\n" | grep -E "\"name\":.*\.tar\.gz" | sed -E "s/.*\"([^\"]+)\".*/\1/")
    DXVK_LINK="https://github.com/doitsujin/dxvk/releases/download/${DXVK_TAG}/${DXVK_DLNAME}"
    # Download and extract to $TEMPDIR
    wget -O "$TEMPDIR/DXVK.tar.gz" "$DXVK_LINK"
    tar xvzf "$TEMPDIR/DXVK.tar.gz" -C "$TEMPDIR"
    mv $TEMPDIR/dxvk-* $TEMPDIR/dxvk_extracted
    chmod +x $TEMPDIR/dxvk_extracted/setup_dxvk.sh
  fi

  # Install "DXVK" in the wineprefix
  printf "\n${GREEN}Installing DXVK!${NC}\n\n"
  WINEPREFIX=$INSTALLDIR $TEMPDIR/dxvk_extracted/setup_dxvk.sh install | tee $LOGDIR/dxvk_setup.log
  if [ $? -ne 0 ]; then
    printf "$FAIL_MESSAGE"
    exit 1
  fi
}

fusion360_install() {
  # Download Fusion 360 if it isn't in the temporary directory already
  if [ ! -e "$TEMPDIR/setup/streamer.exe" ]; then
    printf "\n${BLUE}Downloading Fusion 360!${NC}\n\n"
    # If this file is already downloaded, delete it (might be corrupt)
    rm -rf "$TEMPDIR/Fusion 360 Admin Install.exe"
    # Download the installer and unzip to setup directory
    wget -P $TEMPDIR https://dl.appstreaming.autodesk.com/production/installers/Fusion%20360%20Admin%20Install.exe
    7z x -o$TEMPDIR/setup/ "$TEMPDIR/Fusion 360 Admin Install.exe"
  fi

  # Install Fusion 360
  printf "\n${GREEN}Installing Fusion 360!${NC}\n\n"
  WINEPREFIX=$INSTALLDIR wine $TEMPDIR/setup/streamer.exe -p deploy -g -f $LOGDIR/fusion360_setup.log --quiet
  if [ $? -ne 0 ]; then
    printf "$FAIL_MESSAGE"
    exit 1
  fi
}

backup_launch_script() {
  printf "env WINEPREFIX='$INSTALLDIR' wine C:\\windows\\command\\start.exe /Unix /$HOME/.fusion360/dosdevices/c:/ProgramData/Microsoft/Windows/Start\ Menu/Programs/Autodesk/Autodesk\ Fusion\ 360.lnk\n" > $INSTALLDIR/fusion360
  printf "#Sometimes the first command doesn't work and you need to launch it with this one:\n" >> $INSTALLDIR/fusion360
  printf "#env WINEPREFIX='$INSTALLDIR' wine '$INSTALLDIR/drive_c/Program Files/Autodesk/webdeploy/production/6a0c9611291d45bb9226980209917c3d/FusionLauncher.exe'\n" >> $INSTALLDIR/fusion360
  chmod +x $INSTALLDIR/fusion360
}

end_message() {
  printf "\n\n\n"
  printf "${GREEN}Fusion 360 has been installed!${NC}\n"
  printf "\n\n"
  printf "Wine should have automatically created a \".desktop\" file in ~/.local/share/applications/wine/Programs/Autodesk/\n"
  printf "If that's not the case, a backup start script has been placed in $INSTALLDIR named \"fusion360\".\n"
  printf "You can move this to somethere in your \$PATH for auto tab completion or just launch it from this directory\n"
  printf "If you are having trouble with this app launcher, just open the file with a text editor and follow the instructions there\n"
  printf "\n\n"
  printf "The first launch of the application is usually laggy when signing in, just be patient and it will work!\n"
  printf "${BROWN}Quirk${NC}: Sometimes the Fusion 360 logo gets stuck in the work area after launching,\n"
  printf "       to fix this, set your Graphics mode to OpenGL (User icon >> Preferences >> General >> Graphics driver) and restart the program.\n"
  printf "\n\n"

  # Removing temporary directory
  printf "One more thing. If the installation didn't go according to plan, you don't have to download all the files again if you keep the temporary directory.\n"
  printf "Do you want to keep it (\"$TEMPDIR\")? [y/N] "
  read answer
  if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
    printf "Removing $TEMPDIR!\n"
    rm -rf $TEMPDIR
  fi

  printf "Done!\n"
}

###########################################################
## Parse arguments                                       ##
###########################################################
get_variables() {
  # Parse additional arguments
  while getopts ":p:t:l:h" option; do
    case "${option}" in
      p) 
        INSTALLDIR=${OPTARG};;
      t) 
        TEMPDIR=${OPTARG};;
      l)
        LOGDIR=${OPTARG};;
      h)
        printf "${USAGE}\n"
        exit;;
      :)
        printf "${RED}Error${NC}: Option \"-${OPTARG}\" requires an argument.\nUsage:\n${USAGE}\n"
        exit 1;;
      *)
        printf "${RED}Error${NC}: invalid argument: \"-${OPTARG}\".\nUsage:\n${USAGE}\n"
        exit 1;;
    esac
  done

  # Check for $INSTALLDIR and $TEMPDIR, use defaults if not specified
  if [ -z "$INSTALLDIR" ]; then
    INSTALLDIR="$HOME/.local/share/fusion360"
  fi
  if [ -z "$TEMPDIR" ]; then
    TEMPDIR="$HOME/.local/share/fusion360_temp/"
  fi
  if [ -z "$LOGDIR" ]; then
    LOGDIR="$TEMPDIR/logs"
  fi

  printf "Specified directories are:\n"
  printf "Prefix directory:     $INSTALLDIR\n"
  printf "Temporary directory:  $TEMPDIR\n"
  printf "Log directory:        $LOGDIR\n"
  printf "Continue with the installation? [y/N]"
  read answer
  if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
    printf "Aborting install!\n"
    exit 1
  fi
  # Make the required directories
  mkdir -p $INSTALLDIR
  mkdir -p $TEMPDIR
  mkdir -p $LOGDIR

  # Store directories in a file for uninstall
  printf "$INSTALLDIR\n$TEMPDIR\n$LOGDIR\n" > $INSTALLDIR/fusion360_uninstall_data.txt
}

###########################################################
## Procedures                                            ##
###########################################################
install() {
  get_variables "$@"

  # Check if the $INSTALLDIR already exists
  if [ -d "$INSTALLDIR" ]; then
    printf "${BROWN}Warning${NC}: The directory \"$INSTALLDIR\" already exists!\n"
    printf "         Do you want to overwrite this directory anyway? [y/N] "
    read answer
    if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
      printf "         Aborting install!\n"
      exit 1
    else
      printf "         Moving on with the install!\n"
      rm -rf $INSTALLDIR
    fi
  fi

  packages_install
  winetricks_install
  dxvk_install
  fusion360_install
  backup_launch_script
  end_message
}

uninstall() {
  # Find the uninstall file
  uninstall_file="$(find $HOME/ -name "fusion360_uninstall_data.txt" -type f 2>/dev/null)"
  num_of_uninstalls=$(printf "$uninstall_file\n" | wc -l)

  if [ -z "$uninstall_file" ]; then
    printf "It seems that you don't have Fusion 360 installed on your system!\n"
    exit 1
  fi

  # If there are more than one "fusion360_uninstall_data.txt" found, let the user choose.
  if [ $num_of_uninstalls -gt 1 ]; then
    printf "More than one instance of fusion360 found.\n"
    printf "$uninstall_file\n" | nl
    printf "Which one do you want to remove? [1-]\n"
    read answer
    if [ $answer -gt $num_of_uninstalls ] || [ $answer -lt 1 ]; then
      printf "Not a valid choice! Try uninstalling again.\n"
      exit 1
    fi
    uninstall_file=$(printf "$uninstall_file\n" | sed -n ${answer}p)
  fi

  printf "The following directories will be removed:\n"
  cat $uninstall_file
  printf "Continue? [y/N] "
  read answer
  if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
    printf "Aborting uninstallation!\n"
    exit 1
  fi

  # Remove the files
  for file in $(cat $uninstall_file); do
    printf "Removed file: $file"
    rm -rf "$file"
  done
  printf "${GREEN}Fusion 360 is now uninstalled!${NC}\n"
}

###########################################################
## Entry point                                           ##
###########################################################
case "$1" in
  install)
    shift
    install "$@"
    exit;;
  install-clean)
    shift
    uninstall
    install "$@"
    exit;;
  uninstall)
    uninstall
    exit;;
  -h)
    printf "${USAGE}\n"
    exit;;
  *)
    printf "Invalid usage: $0 $1\n"
    printf "Only use \"$0 install\", \"$0 install-clean\" or \"$0 uninstall\"\n"
    exit 1
esac
