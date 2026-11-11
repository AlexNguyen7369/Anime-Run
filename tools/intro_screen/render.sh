#!/bin/zsh
# usage: render.sh X  -> X_backdrop.png, X_mockup.png, X_phone.png
D=${0:A:h}; X=$1; C="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
shot(){ "$C" --headless=new --hide-scrollbars --force-device-scale-factor=1 --window-size=$1 --screenshot=$2 "file://$3" 2>/dev/null; }
shot 1920,1080 $D/${X}_backdrop.png $D/$X.html
sed "s#BG#${X}_backdrop.png#" $D/mock.html > $D/${X}_mock.html
shot 1920,1080 $D/${X}_mockup.png $D/${X}_mock.html
shot 1334,750 $D/${X}_phone_1334x750.png $D/${X}_mock.html
shot 1624,750 $D/${X}_phone_wide_1624x750.png $D/${X}_mock.html
shot 1024,768 $D/${X}_tablet_1024x768.png $D/${X}_mock.html
ls -la $D/${X}_*.png | awk '{print $5,$9}'
