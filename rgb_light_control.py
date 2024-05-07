from kasa import SmartBulb
import asyncio
from typing import Any, Union
import sys
import os
import colorsys
import librosa
from pygame.mixer import music
import pygame


bulbs: list[SmartBulb] = []


def error_exit(msg: str):
    print(msg)
    sys.exit(1)

def ask(prompt: str, answers: list[str], default: Union[str, None] = None) -> str:
    """Ask a question with a list of answers.

    Args:
        prompt: Question to ask.
        answers: List of acceptable answers. Should not include an empty string as an answer.
        default: Default answer to return if the user doesn't provide one. Will keep asking until an answer is given if
        the default is None.

    Returns:
        An answer from answers or the default.
    """
    default_str = "" if default is None else f" [{default}]"
    answer = None
    while answer not in answers:
        answer = input(f"{prompt} ({", ".join(answers)}){default_str}: ")
        if answer == "" and default is not None:
            return default
    return answer


def ask_int(prompt: str, default: Union[int, None] = None) -> int:
    """Ask a question with an int expected as an answer.

    Args:
        prompt: Question to ask.
        default: Default int to return, or None to not return until a proper answer is given.

    Returns:
        An int answer.
    """
    default_str = "" if default is None else f" [{default}]"
    answer = None
    while answer is None:
        answer = input(f"{prompt}{default_str}: ")
        if answer == "" and default is not None:
            return default
        else:
            try:
                return int(answer)
            except ValueError:
                answer = None


def ask_file_path(prompt: str) -> str:
    """Ask user for the path to a file.

    Args:
        prompt: Question to ask.

    Returns:
        A path to a file.
    """
    path = None
    while path is None or not os.path.isfile(path):
        path = os.path.expanduser(os.path.expandvars(prompt))
    return path


def is_valid_rgb_colors_string(color_str: str) -> str:
    """Check if the provided color string is valid.

    Args:
        color_str: The color string to check.

    Returns:
        An empty string if valid, or an error message if it isn't.
    """
    colors = color_str.split(";")
    for col in colors:
        components = col.split(",")
        if len(components) != 3:
            return f"{col} is not a comma-separated set of numbers."
        for component in components:
            try:
                val = int(component)
                if val < 0 or val > 255:
                    return f"{val} must be between 0 and 255 inclusive."
            except ValueError:
                return f"{component} is not a valid number."
    return ""


def ask_colors_rgb(prompt: str) -> str:
    """Ask the user for a list of RGB colors.

    Args:
        prompt: Question to ask.

    Returns:
        A valid string of RGB colors that convert_rgb_colors_string() can successfully convert.
    """
    is_valid = False
    while not is_valid:
        print("RGB values should be a semicolon separated set of comma-separated color values. For example, 255,0,"
              "0;0,0,255 is red, followed by green.")
        ans = input(prompt)
        err = is_valid_rgb_colors_string(ans)
        if err != "":
            print(err)
        else:
            return ans


def convert_rgb_colors_string(colors: str) -> list[tuple[int, int, int]]:
    """Converts a string of RGB colors, such as from ask_colors_rgb(), to a list of HSV values in tuples.

    Args:
        colors: The color string

    Returns:
        A list of HSV tuples.
    """
    err = is_valid_rgb_colors_string(colors)
    if err != "":
        error_exit(err)
    colors = colors.split(";")
    out = []
    for color in colors:
        rgb = color.split(",")
        vals = []
        for val in rgb:
            vals.append(int(val))
        hsv = colorsys.rgb_to_hsv(vals[0], vals[1], vals[2])
        out.append((int(hsv[0] * 360), int(hsv[1] * 100), int(hsv[2] * 100 / 255)))
    return out


async def load_bulbs():
    """Loads all bulbs into this module's bulbs array from a list of IP addresses in lights.txt."""
    bulbs.clear()
    with open("lights.txt", "r") as f:
        lines = f.readlines()
    for line in lines:
        line = line.strip()
        if line != "":
            bulbs.append(SmartBulb(line))
    await asyncio.gather(*[bulb.update() for bulb in bulbs], return_exceptions=True)


async def send_hsv(h: int, s: int, v: int, transition: int = 0) -> tuple[Any]:
    """Set a HSV value to all bulbs, ignoring errors,

    Args:
        h: HSV hue value.
        s: HSV saturation value.
        v: HSV value value.
        transition: The time to wait to transition in ms. Defaults to no time.

    Returns:
        A tuple of all return values from each bulb HSV set.
    """
    return await asyncio.gather(*[bulb.set_hsv(h, s, v, transition=transition) for bulb in bulbs], return_exceptions=True)


async def rainbow(speed: int):
    """Moves the bulbs through the rainbow as fast as possible.

    Args:
        speed: Speed to advance.

    Returns:
        This function does not return.
    """
    hue = 0
    while True:
        if hue > 360:
            hue = 0
        await send_hsv(hue, 100, 100)
        hue += speed


async def bpm(colors: list[tuple[int, int, int]], filepath: str):
    waveform, sampling_rate = librosa.load(filepath)
    tempo, beats = librosa.beat.beat_track(y=waveform, sr=sampling_rate)
    tempo = tempo[0]
    wait_time = tempo / 60 / 4  # Switch on every quarter note
    pygame.init()
    music.load(filepath)
    music.play()
    import time
    index = 0
    while True:
        hsv = colors[index]
        time.sleep(wait_time)
        await send_hsv(hsv[0], hsv[1], hsv[2])
        index += 1
        if index >= len(colors):
            index = 0

async def run_with_args(args: list[str]):
    """Run this script with the provided list of arguments.

    Args:
        args: Arguments to run this script with, not including the script name.

    Returns:
        This function does not return. This function either exits the program with an error code or runs until
        interrupted.
    """
    mode = args[0]
    if mode == "rainbow":
        speed = 5
        if len(args) >= 2:
            try:
                speed = int(args[1])
            except ValueError:
                error_exit(f"{speed} is not a number!")
        await rainbow(speed)
    elif mode == "music":
        if len(args) < 2:
            error_exit("Please specify a music submode!")
        submode = args[1]
        if submode == "bpm":
            if len(args) < 4:
                error_exit("Please specify an RGB color string and a filepath to the music.")
            colors = convert_rgb_colors_string(args[2])
            filepath = os.path.expanduser(os.path.expandvars(args[3]))
            if not os.path.isfile(filepath):
                error_exit(f"{filepath} is not a file!")
            await bpm(colors, filepath)
    else:
        error_exit(f"Invalid mode {mode}.")


async def init():
    if not os.path.isfile("lights.txt"):
        error_exit("lights.txt file not found! Please create it and input a list of bulbs to control, with one IP "
                   "address per line.")
    await load_bulbs()


async def main():
    await init()
    if len(sys.argv) == 1:
        args = []
        mode = ask("Which mode do you want to use?", ["rainbow", "music"], "rainbow")
        args.append(mode)
        if mode == "rainbow":
            speed = ask_int("Input a speed, where 360 goes through the entire rainbow", 5)
            args.append(str(speed))
        elif mode == "bpm":
            args.append(ask("Which submode of music sync do you want to use?", ["bpm"], "bpm"))
            args.append(ask_colors_rgb("Enter a list of RGB values to change between each beat: "))
            args.append(ask_file_path("Enter the file path to the music to play: "))
        await run_with_args(args)
    else:
        await run_with_args(sys.argv[1:])


if __name__ == "__main__":
    loop = asyncio.new_event_loop()
    loop.run_until_complete(main())
