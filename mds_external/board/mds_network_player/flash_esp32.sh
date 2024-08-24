#!/bin/sh

# Set gpio9 to low to enable flash mode PD2 : 3×32+2 = 98
echo 98 > /sys/class/gpio/export

# Set ESP_RST to low to enable flash mode PD1 : 3×32+1 = 97
echo 97 > /sys/class/gpio/export

echo out > /sys/class/gpio/gpio98/direction
echo out > /sys/class/gpio/gpio97/direction

# Set gpio9 to low to enable flash mode
echo 0 > /sys/class/gpio/gpio98/value

# Reset ESP32
echo 0 > /sys/class/gpio/gpio97/value
sleep 1
echo 1 > /sys/class/gpio/gpio97/value

echo 98 > /sys/class/gpio/unexport
echo 97 > /sys/class/gpio/unexport
