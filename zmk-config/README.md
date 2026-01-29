# ZMK Config for Corne Choc

This is my ZMK firmware configuration for the Corne Choc keyboard.

## ZMK Studio Unlocking

To unlock the keyboard in ZMK Studio, press the **top left two keys together** (Q + W on the default layer).

## Building

This repository uses GitHub Actions to automatically build the firmware. Check the Actions tab for the latest builds.

## Flashing

1. Download the firmware from GitHub Actions
2. Put your keyboard into bootloader mode
3. Copy the `.uf2` file to the mounted drive
4. Repeat for the other half

## Layout

- Layer 0: Base QWERTY
- Layer 1: Lower (Numbers, Bluetooth controls, Navigation)
- Layer 2: Raise (Symbols)
