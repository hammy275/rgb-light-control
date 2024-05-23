# rgb-light-control

Some Python scripts I use for controlling my smart lights at home to run in patterns. Usable with Kasa smart lights, since that's what I use. NOT an official product of Kasa or anything of the sort.

## Warning

This program flashes lights, sometimes rapidly! If you are photosensitive and/or have discomfort with rapidly-changing lights, I highly recommend you not use this program. If you experience symptoms related to photosensitive epilepsy while using this program, you should immediately stop using this program and talk with a medical professional! Those symptoms are, in fact, bad for your health!

## Files

- `rgb_light_control.py`: Main script to control lights on a pattern. Expects a list of IP addresses to be provided in a file named `lights.txt`, separated by newlines.
- `old_rgb_light_control.py`: An old version of `rgb_light_control.py`. A much, much messier control script that only supports one light. The light's IP address should go into a file named `old_config.txt`.
- `web_server.py`: A web server that implements an API to handle RGB light control from within your network. Does NOT have authentication! You can optionally create a file named `web_server_config.txt`, which can contain any of the lines specified below. Any lines that don't follow any format below are ignored.
    - `discovery_ip=IP_HERE`: `IP_HERE` should be replaced with the IP address to discover lights on (usually your gateway, but ending in `.255` instead of `.1`). If not specified, defaults to `255.255.255.255`.