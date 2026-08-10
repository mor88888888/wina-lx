#!/bin/bash

mkdir artifacts
mkdir artifacts/REG
mkdir artifacts/FS
mkdir artifacts/EVTX
#mkdir artifacts/FS/LNK
#mkdir artifacts/WEB

# OS
cp -r ./C/Windows/System32/config/* artifacts/REG/
cp ./C/Windows/appcompat/Programs/Amcache.hve artifacts/REG/
#cp ./C/ProgramData/Microsoft/Windows/Start Menu/Programs/StartUp/*.lnk FS/LNK
cp ./C/Windows/System32/winevt/Logs/* artifacts/EVTX/
cp './C/$MFT' artifacts/FS/

# Users - ToDo iterator
cp ./C/Users/username/NTUSER.DAT artifacts/REG/NTUSER-username.DAT
cp ./C/Users/username/AppData/Local/Microsoft/Windows/usrClass.dat artifacts/REG/UsrClass-username.dat
