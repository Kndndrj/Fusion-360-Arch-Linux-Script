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
USAGE="usage"
FAIL_MESSAGE="${RED}Installation failed!${NC}\n\
  The file may be corrupt!\n\
  Please consider doing a clean install (use the \"-c\" flag).\n"

###########################################################
## Parse Arguments                                       ##
###########################################################
while getopts ":p:t:ch" option; do
  case "${option}" in
    p) 
      INSTALLDIR=${OPTARG};;
    t) 
      TEMPDIR=${OPTARG};;
    c)
      CLEAN_INSTALL=1;;
    h)
      printf "${USAGE}\n"
      exit;;
    :)
      printf "${RED}Error${NC}: -${OPTARG} requires an argument.\nUsage:\n${USAGE}\n"
      exit 1;;
    *)
      printf "${RED}Error${NC}: invalid argument: \"-${OPTARG}\".\nUsage:\n${USAGE}\n"
      exit 1;;
  esac
done

# Check for $INSTALLDIR and $TEMPDIR, use defaults if not specified
if [ -z "$INSTALLDIR" ]; then
  INSTALLDIR="$HOME/.local/share/fusion360"
  printf "${BROWN}Warning${NC}: No Prefix directory specified. The default \"$INSTALLDIR\" will be used.\n"
fi
if [ -z "$TEMPDIR" ]; then
  TEMPDIR="$HOME/.local/share/fusion360_temp/"
  printf "${BROWN}Warning${NC}: No Temp directory specified. The default \"$TEMPDIR\" will be used.\n"
fi

# Clean install procedure
if [ $CLEAN_INSTALL -eq 1 ]; then
  printf "Performing a clean install!\n"
  rm -rf $INSTALLDIR $TEMPDIR
fi

# Check if the $INSTALLDIR already exists
if [ -d "$INSTALLDIR" ]; then
  printf "${BROWN}Warning${NC}: The directory \"$INSTALLDIR\" already exists!\n"
  printf "         Do you want to overwrite this directory anyway? [y/N] "
  read answer
  if [ "$answer" != "y" ] && [ "$answer" != "Y" ]; then
    printf "Aborting install!\n"
    exit
  else
    printf "Moving on with the install!\n"
    rm -rf $INSTALLDIR
  fi
fi

###########################################################
## Directories                                           ##
###########################################################
LOGDIR="$INSTALLDIR/install_logs/"

# Make the directories
mkdir -p $TEMPDIR
mkdir -p $LOGDIR

###########################################################
## System Update and Install Prerequisites               ##
###########################################################
printf "${GREEN}Updating the system and installing prerequisites!${NC}\n"

sudo pacman -Syyu wine wine-gecko wine-mono p7zip curl wget
if [ $? -ne 0 ]; then
  printf "${RED}Required packages could not be installed!${NC}\n"
  printf "Please make sure that you have enabled the \"multilib\" repository for pacman!\n"
  printf "To do this, uncomment the following lines in \"/etc/pacman.conf\":\n"
  printf "\t[multilib]\n"
  printf "\tInclude = /etc/pacman.d/mirrorlist\n\n"
  exit 1
fi

###########################################################
## Winetricks                                            ##
###########################################################
# Download winetricks if it isn't in the temporary directory already
if [ ! -e "$TEMPDIR/winetricks" ]; then
  printf "${BLUE}Downloading Winetricks!${NC}\n"
  wget -P "$TEMPDIR" "https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks"
  chmod +x $TEMPDIR/winetricks
fi

# Run winetricks (automatically makes a prefix in $INSTALLDIR)
printf "${GREEN}Running Winetricks!${NC}\n"
WINEPREFIX=$INSTALLDIR $TEMPDIR/winetricks atmlib gdiplus msxml3 msxml6 vcrun2017 corefonts fontsmooth=rgb winhttp win10
if [ $? -ne 0 ]; then
  printf "$FAIL_MESSAGE"
  exit 1
fi

###########################################################
## DXVK Install                                          ##
###########################################################
# Download DXVK if it isn't in the temporary directory already
if [ ! -e "$TEMPDIR/dxvk_extracted/setup_dxvk.sh" ]; then
  printf "${BLUE}Downloading DXVK!${NC}\n"
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
printf "${GREEN}Installing DXVK!${NC}\n"
WINEPREFIX=$INSTALLDIR $TEMPDIR/dxvk*/setup_dxvk.sh install
if [ $? -ne 0 ]; then
  printf "$FAIL_MESSAGE"
  exit 1
fi

###########################################################
## Fusion 360 Install                                    ##
###########################################################
# Download Fusion 360 if it isn't in the temporary directory already
if [ ! -e "$TEMPDIR/setup/streamer.exe" ]; then
  printf "${BLUE}Downloading Fusion 360!${NC}\n"
  # Download the installer and unzip to setup directory
  wget -P $TEMPDIR https://dl.appstreaming.autodesk.com/production/installers/Fusion%20360%20Admin%20Install.exe
  7z x -o$TEMPDIR/setup/ "$TEMPDIR/Fusion 360 Admin Install.exe"
fi

# Install Fusion 360
printf "${GREEN}Installing Fusion 360!${NC}\n"
WINEPREFIX=$INSTALLDIR wine $TEMPDIR/setup/streamer.exe -p deploy -g -f $LOGDIR/fusion360_install.log --quiet
if [ $? -ne 0 ]; then
  printf "$FAIL_MESSAGE"
  exit 1
fi
#rm -r $TEMPDIR

###########################################################
## Create Fusion 360 Launching Script                    ##
###########################################################
printf "env WINEPREFIX='$INSTALLDIR' wine C:\\windows\\command\\start.exe /Unix /$HOME/.fusion360/dosdevices/c:/ProgramData/Microsoft/Windows/Start\ Menu/Programs/Autodesk/Autodesk\ Fusion\ 360.lnk\n" > $INSTALLDIR/fusion360
printf "#Sometimes the first command doesn't work and you need to launch it with this one:\n" >> $INSTALLDIR/fusion360
printf "#env WINEPREFIX='$INSTALLDIR' wine '$INSTALLDIR/drive_c/Program Files/Autodesk/webdeploy/production/6a0c9611291d45bb9226980209917c3d/FusionLauncher.exe'\n" >> $INSTALLDIR/fusion360
chmod +x $INSTALLDIR/fusion360

###########################################################
## Exit Message                                          ##
###########################################################
printf "\n\n\n"
printf "${GREEN}Fusion 360 has been installed!${NC}\n"
printf "\n\n"
printf "The executable for Fusion360 has been placed in $INSTALLDIR named fusion360.\n"
printf "You can move this to somethere in your \$PATH for auto tab completion or just launch it from this directory\n"
printf "If you are having trouble with this app launcher, just open launcher file with a text editor ;)\n"
printf "\n\n"
printf "The first launch of the application is usually laggy when signing in, just be patient and it will work!\n"
printf "${BROWN}Quirk${NC}: Sometimes the Fusion 360 logo gets stuck in the work area after launching,\n"
printf "to fix this, set your Graphics mode to OpenGL and restart\n"
printf "\n\n"
