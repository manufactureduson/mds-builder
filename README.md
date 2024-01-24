## Build firmware for f1c200s

`make build`

## Update build firmware for esp-hosted-ng solution

0. enter `src/esp-hosted/esp_hosted_ng/esp/esp_driver`

1. run `cmake .` to setup enviornment, it will setup esp-idf as submodule to be used by `network_adapter`

2. setup compiling environment by `. ./export.sh` in esp-idf directory

3. In the `network_adapter` directory of this project, input command `idf.py set-target <chip_name>` to set target.

4. Use `idf.py build` to recompile `network_adapter` and generate new firmware.

## Checks

Power sources : 
3v3 : OK
5v : OK
2.5v : OK
1.1v : NOK

Communication with ESP32-C2 : OK
Used Arduino + UART, after pressing the reset button on the board, the ESP32-C2 sends a message on the UART.
