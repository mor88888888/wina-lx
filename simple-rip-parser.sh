#!/bin/bash

mkdir output

regripper -r REG/NTUSER.DAT -a > output/ntuserdat.txt
regripper -r REG/SYSTEM -a > output/system.txt
regripper -r REG/SOFTWARE -a > output/software.txt
regripper -r REG/Amcache.hve -p amcache > output/amcache.txt
regripper -r REG/UsrClass.dat -p shellbags > output/shellbags.txt
