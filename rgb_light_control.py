from kasa import SmartBulb, SmartDeviceException
import asyncio
from typing import Callable, Union
import sys
import os


bulbs: list[SmartBulb] = []


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


async def send_hsv(h: int, s: int, v: int):
    """Set a HSV value to all bulbs, ignoring errors,

    Args:
        h: HSV hue value.
        s: HSV saturation value.
        v: HSV value value.
    """
    await asyncio.gather(*[bulb.set_hsv(h, s, v) for bulb in bulbs], return_exceptions=True)


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


async def main():
    await load_bulbs()
    if not os.path.isfile("lights.txt"):
        print("lights.txt file not found! Please create it and input a list of bulbs to control, with one IP address "
              "per line.")
        sys.exit(1)
    mode = ask("Which mode do you want to use?", ["rainbow"], "rainbow")
    if mode == "rainbow":
        speed = ask_int("Input a speed, where 360 goes through the entire rainbow", 5)
        await rainbow(speed)


if __name__ == "__main__":
    loop = asyncio.new_event_loop()
    loop.run_until_complete(main())
