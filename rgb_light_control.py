from kasa import SmartBulb
import asyncio
from typing import Any, Union
import sys
import os
import colorsys
import librosa
from pygame.mixer import music
import pygame
import time


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


def ask_file_path(prompt: str, optional: bool = False) -> Union[str, None]:
    """Ask user for the path to a file.

    Args:
        prompt: Question to ask.
        optional: Whether to return None on an empty input.

    Returns:
        A path to a file, or None if the input was empty and optional is True.
    """
    path = None
    while path is None or not os.path.isfile(path):
        path = os.path.expanduser(os.path.expandvars(input(prompt)))
        if path == "" and optional:
            return None
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
    while True:
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


async def estimate_send_delay(num_tests=40):
    """Roughly estimate the delay waiting for bulbs to get the color data.

    Args:
        num_tests: Number of tests to run for the average delay. Must be between 1 and 360, inclusive.

    Returns:
        An estimate, in seconds, of the time for a bulb to change its color.
    """
    if num_tests < 1 or num_tests > 360:
        error_exit("Can only estimate with 1-360 tests, inclusive.")
    print("Estimating delay to send light info")
    avg = 0
    h = 0
    for i in range(num_tests):
        start = time.time()
        await send_hsv(h, 100, 100)
        end = time.time()
        avg += end - start
        h += 1
    delay = avg / num_tests
    print(f"Estimated delay to be {(avg / num_tests):.3f}")
    return delay / 2  # Delay is cut in half to ignore the return-trip time.


async def send_hsv(h: int, s: int, v: int, transition: int = 0) -> tuple[Any]:
    """Set an HSV value to all bulbs, ignoring errors,

    Args:
        h: HSV hue value.
        s: HSV saturation value.
        v: HSV value value.
        transition: The time to wait to transition in ms. Defaults to no time.

    Returns:
        A tuple of all return values from each bulb HSV set.
    """
    return await asyncio.gather(*[bulb.set_hsv(h, s, v, transition=transition) for bulb in bulbs], return_exceptions=True)


async def cycle_rainbow(speed: int):
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


async def cycle_music(colors_in: list[tuple[int, int, int]], filepath: str, calc_filepath: str):
    """Change lights to the notes of the song.

    Args:
        colors_in: Colors to cycle between as a list of HSV tuples.
        filepath: Filepath to music
        calc_filepath: Filepath to file to use for beats/peaks calculations. Helpful to pass an instrumental here.

    Returns:
        Returns None once the song is done playing
    """
    # Calculate beat timings
    waveform, sampling_rate = librosa.load(calc_filepath)
    bpm = librosa.beat.beat_track(y=waveform, sr=sampling_rate)[0][0]
    duration = librosa.get_duration(y=waveform, sr=sampling_rate)
    max_notes = int(bpm / 60 * duration * 2 / 3)
    # Get all notes that are significantly louder than the average of the song and the very close neighbors
    frames1 = []
    delta = 0.07
    while delta < 0.3:
        frames1 = librosa.onset.onset_detect(y=waveform, sr=sampling_rate, units="frames", backtrack=False, sparse=True,
                                             pre_max=3, post_max=3, pre_avg=sampling_rate, post_avg=sampling_rate,
                                             delta=delta)
        if len(frames1) < max_notes:
            break
        delta += 0.01
    # Get notes on the automatically determined beat that aren't super close to the frames from above
    frames2 = list(librosa.beat.beat_track(y=waveform, sr=sampling_rate)[1])
    to_remove = []
    for f in frames2:
        for i in range(-3, 4):
            if f - i in frames1:
                to_remove.append(f)
                break
    for f in to_remove:
        frames2.remove(f)
    # Merge the two lists of notes
    frames = sorted(set(list(frames1) + list(frames2)))
    print(f"Using delta {delta:.2f}. We have {len(frames)} light switches.")
    times = librosa.frames_to_time(frames)
    colors = []
    for i in range(len(times)):
        colors.append(colors_in[i % len(colors_in)])

    # Pygame init
    pygame.init()
    music.load(filepath)

    # Estimate delay for light changes, and apply to all elements of the times list
    send_delay = await estimate_send_delay()
    for i in range(len(times)):
        times[i] -= send_delay

    index = 0
    music.play()
    start = time.time()

    # Use a tight loop to send a light change request the instant we're supposed to. This way, we don't need
    # to time the rest of the code.
    while True:
        # Get next time to play at and the color to play at that time.
        next_time = times[index]
        hsv = colors[index]
        # Tight loop until ready to do light change
        while time.time() - start < next_time:
            pass
        # Send HSV and advances index.
        await send_hsv(hsv[0], hsv[1], hsv[2])
        index += 1
        # Tight loop to wait until end of song once we're through with all the lights, then return
        if index >= len(times):
            while music.get_busy():
                pass
            return


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
        await cycle_rainbow(speed)
    elif mode == "music":
        if len(args) < 4:
            error_exit("Please specify an RGB color string, a filepath to the music, and a filepath to the music "
                       "for calculations (either the same path again, or the path to an instrumental ideally).")
        colors = convert_rgb_colors_string(args[1])
        filepath = os.path.expanduser(os.path.expandvars(args[2]))
        calc_filepath = os.path.expanduser(os.path.expandvars(args[3]))
        if not os.path.isfile(filepath):
            error_exit(f"{filepath} is not a file!")
        elif not os.path.isfile(calc_filepath):
            error_exit(f"{calc_filepath} is not a file!")
        await cycle_music(colors, filepath, calc_filepath)

    else:
        error_exit(f"Invalid mode {mode}.")


async def verify_and_init():
    """Verify things are ready to go, then initialize the lights."""
    if not os.path.isfile("lights.txt"):
        error_exit("lights.txt file not found! Please create it and input a list of bulbs to control, with one IP "
                   "address per line.")
    await load_bulbs()


async def main():
    """Main entrypoint"""
    await verify_and_init()
    if len(sys.argv) == 1:
        args = []
        mode = ask("Which mode do you want to use?", ["rainbow", "music"], "rainbow")
        args.append(mode)
        if mode == "rainbow":
            speed = ask_int("Input a speed, where 360 goes through the entire rainbow", 5)
            args.append(str(speed))
        elif mode == "music":
            args.append(ask("Which submode of music sync do you want to use?",
                            ["bpm", "onset_detect"], "onset_detect"))
            args.append(ask_colors_rgb("Enter a list of RGB values to change between each beat: "))
            args.append(ask_file_path("Enter the file path to the music to play: "))
            args.append(ask_file_path("Enter the file path to the instrumental if you have one: ", optional=True))
            if args[1] == "bpm":
                args.append(str(ask_int("Enter a BPM, or don't specify one to try to determine it automatically.", 0)))
        await run_with_args(args)
    else:
        await run_with_args(sys.argv[1:])


if __name__ == "__main__":
    loop = asyncio.new_event_loop()
    loop.run_until_complete(main())
