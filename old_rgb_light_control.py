#!/usr/bin/python3

import time
import asyncio
import colorsys
from random import randint, shuffle
from kasa import SmartBulb, SmartDeviceException

# This codebase is a freaking mess xD

with open("old_config.txt", "r") as f:
    bulb = SmartBulb(f.readline().strip())

async def get_input(question, answers, default):
    answer = " "
    while not(answer in answers) and answer != "":
        answer = input(question).lower()
    if answer == "":
        return default
    else:
        return answer


async def to_hsv(r, g, b): # Converts RGB value to HSV value for the bulb
    hsv = colorsys.rgb_to_hsv(r, g, b)
    return (int(hsv[0]*360), int(hsv[1]*100), int(hsv[2] * (100/255)))

async def send_hsv(h, s, v): # Sends the bulb an hsv signal but ignores communication errors
    try:
        await bulb.set_hsv(h, s, v)
    except SmartDeviceException:
        pass

###########################################################################


async def cycle_colors():
    answer = "originally on line 21"
    colors = []
    while answer.lower() != "start":
        color = input("Enter RGB value, seperated by , (ex. 255, 128, 0): ") # Gets a list of RGB values from the user
        shouldnt_append = False
        if color == "start" or color == "":
            break
        color_list = color.rstrip().split(",")
        new_color_list = []
        for i in color_list:
            try:
                new_color_list.append(int(i))
            except ValueError:
                print("Bad input!")
                shouldnt_append = True
                continue
        if shouldnt_append:
            shouldnt_append = False
        else:
            colors.append(await to_hsv(new_color_list[0], new_color_list[1], new_color_list[2])) # Adds color to list of colors converted to hsv
    modes = ["shuffle", "order"]
    print("Modes: {}".format(", ".join(modes)))
    mode = await get_input("Pick a mode: ", modes, "random") # Get mode
    sleep_time = input("Enter time in between color changes [1]: ") # Get time between each color
    try:
        sleep_time = int(sleep_time)
    except ValueError:
        print("Setting sleep time to 1!")
        sleep_time = 1
    while True:
        if mode == "shuffle":
            shuffle(colors)
        for color in colors:
            await send_hsv(color[0], color[1], color[2])
            time.sleep(sleep_time)


async def rainbow(speed=5):
    col = bulb.hsv.hue
    while True:
        if col > 360:
            col = 0
        await send_hsv(col, 100, 100)
        col += speed


async def random(time_delay):
    while True:
        await send_hsv(randint(0,360), randint(0,100), randint(0,100))
        time.sleep(time_delay)

async def main():
    await bulb.update()
    modes = ["rainbow", "random", "custom"]
    print("Available modes: {}".format(", ".join(modes)))
    mode = await get_input("Select mode: ", modes, "rainbow")
    print("Running mode: {}".format(mode))
    if mode == "rainbow":
        speed = input("Enter speed [5]: ")
        if speed == "":
            speed = 5
        else:
            try:
                speed = int(speed)
            except ValueError:
                print("Defaulting to 5")
                speed = 5
        await rainbow(speed)
    elif mode == "random":
        sleep_time = input("Enter sleep time [0]: ")
        if sleep_time == "":
            sleep_time = 0.0
        else:
            try:
                sleep_time = float(sleep_time)
            except ValueError:
                print("Defaulting to 0.0")
                sleep_time = 0.0
        await random(sleep_time)
    elif mode == "custom":
        await cycle_colors()


if __name__ == "__main__":
    loop = asyncio.new_event_loop()
    loop.run_until_complete(main())
