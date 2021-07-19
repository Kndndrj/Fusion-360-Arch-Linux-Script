#!/bin/bash

# This short script will help you install Autodesk Fusion 360 on your Arch based Linux distribution
# Forked from https://github.com/link12765/Fusion-360-Arch-Linux-Script
# Original Author: Dylan Dean Goebel - Contact: goebeld @ https://www.reddit.com/user/goebeld
# 
# Modified by Andrej Kenda (Kndndrj)

###########################################################
## Get wineprefix                                        ##
###########################################################
INSTALLDIR="$HOME/.fusion360"
TEMPDIR="$INSTALLDIR/tmp/"
printf "default installation directory: $INSTALLDIR\n"

#Make wine prefix directory
mkdir -p $INSTALLDIR
mkdir $TEMPDIR

###########################################################
## Perform a System update and install prerequisites     ##
###########################################################
echo "Now updating system and installing prerequisites"
sudo pacman -Syyu wine wine-gecko wine-mono p7zip git curl wget
if [ $? -ne 0 ]; then
  printf "Required packages could not be installed!\n"
  printf "Please make sure that you have enabled the \"multilib\" repository for pacman!\n"
  printf "To do this, uncomment the following lines in \"/etc/pacman.conf\":\n"
  printf "\t[multilib]\n"
  printf "\tInclude = /etc/pacman.d/mirrorlist\n\n"
  exit 1
fi

wget -P "$TEMPDIR" "https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks"
chmod a+x $TEMPDIR/winetricks

###########################################################
## Install wineprefix prerequisites                      ##
###########################################################
echo "Now populating new wineprefix with the required prerequisites"
WINEPREFIX=$INSTALLDIR $TEMPDIR/winetricks atmlib gdiplus msxml3 msxml6 vcrun2017 corefonts fontsmooth=rgb winhttp win10

# Get the latest release of "dxvk"
DXVK_INFO=$(curl --silent "https://api.github.com/repos/doitsujin/dxvk/releases/latest")
DXVK_TAG=$(printf "${DXVK_INFO}\n" | grep -E "\"tag_name\":" | sed -E "s/.*\"([^\"]+)\".*/\1/")
DXVK_DLNAME=$(printf "${DXVK_INFO}\n" | grep -E "\"name\":.*\.tar\.gz" | sed -E "s/.*\"([^\"]+)\".*/\1/")
DXVK_LINK="https://github.com/doitsujin/dxvk/releases/download/${DXVK_TAG}/${DXVK_DLNAME}"

wget -O "$TEMPDIR/DXVK.tar.gz" "$DXVK_LINK"
tar xvzf "$TEMPDIR/DXVK.tar.gz" -C "$TEMPDIR"

# Install "dxvk" in our wineprefix
WINEPREFIX=$INSTALLDIR $TEMPDIR/dxvk*/setup_dxvk.sh install

###########################################################
## Install Fusion 360                                    ##
###########################################################
echo "NOW INSTALLING FUSION 360!!!"
# Download the installer
wget -P $TEMPDIR https://dl.appstreaming.autodesk.com/production/installers/Fusion%20360%20Admin%20Install.exe
# Unzip to setup directory
7z x -o$TEMPDIR/setup/ "$TEMPDIR/Fusion 360 Admin Install.exe"
# 
curl -Lo $TEMPDIR/setup/platform.py https://github.com/python/cpython/raw/3.5/Lib/platform.py
sed -i "s/winver._platform_version or //" $TEMPDIR/setup/platform.py	

WINEPREFIX=$INSTALLDIR wine $TEMPDIR/setup/streamer.exe -p deploy -g -f log.txt --quiet
#rm -r $TEMPDIR

###########################################################
## Create Fusion 360 launching script                    ##
###########################################################
echo "env WINEPREFIX='$INSTALLDIR' wine C:\\windows\\command\\start.exe /Unix /$HOME/.fusion360/dosdevices/c:/ProgramData/Microsoft/Windows/Start\ Menu/Programs/Autodesk/Autodesk\ Fusion\ 360.lnk" > $INSTALLDIR/fusion360
echo "#Sometimes the first command doesn't work and you need to launch it with this one:" >> $INSTALLDIR/fusion360
echo "#env WINEPREFIX='$INSTALLDIR' wine '$INSTALLDIR/drive_c/Program Files/Autodesk/webdeploy/production/6a0c9611291d45bb9226980209917c3d/FusionLauncher.exe'" >> $INSTALLDIR/fusion360
chmod a+x $INSTALLDIR/fusion360
echo
echo
echo "The executable for Fusion360 has been placed in $INSTALLDIR named fusion360. You can move this to somethere in your PATH for auto tab completion or just launch it from this directory"
echo "If you are having trouble with this app launcher, just open launcher file with a text editor ;)"
echo 
echo "The first launch of the application is usually laggy when signing in, just be patient and it will work!"
echo "Quirk: Sometimes the Fusion 360 logo gets stuck in the work area after launching. To fix this, set your Graphics mode to OpenGL and restart"
echo 
echo	
