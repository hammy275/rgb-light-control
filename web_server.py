from quart import Quart, request, jsonify, send_from_directory
import os
import kasa
from typing import Any, Union
import asyncio
import json

import rgb_light_control

REQUEST_METHODS: list[str] = ["GET", "POST"]

discovery_ip = "255.255.255.255"
if os.path.isfile("web_server_config.txt"):
    with open("web_server_config.txt", "r") as f:
        lines: list[str] = f.readlines()
        for line in lines:
            if line.startswith("discovery_ip="):
                discovery_ip = line[len("discovery_ip="):].strip()

lghts = asyncio.run(kasa.Discover.discover(target=discovery_ip))
all_bulbs = {}
all_bulbs_data = []
for ip, lght in lghts.items():
    if isinstance(lght, kasa.SmartBulb) and lght.is_color:
        all_bulbs[lght.alias] = lght
        all_bulbs_data.append({"ip": ip, "name": lght.alias})

app: Quart = Quart(__name__)


def make_message(message: str, status_code: int = 200, data: Any = None):
    if data is not None:
        return jsonify({"message": message, "data": data}), status_code
    else:
        return jsonify({"message": message}), status_code


async def get_data() -> Union[dict, None]:
    """Get a dictionary of data from the request, or None if data isn't provided.

    Returns: A dictionary of the data from the request, or None if none could be parsed.
    """
    if request.method == "GET":
        return dict(request.args)
    else:
        data = await request.json
        if data is not None:
            return data
        form = await request.form
        if "json" in form:
            return json.loads(form["json"])
        return None


def get_list(lst: Union[str, list]):
    if isinstance(lst, str):
        return lst.split(",")
    return lst


def get_bulbs_list(data: dict):
    lights = get_list(data["lights"])
    bulbs_list = []
    for light in lights:
        if light in all_bulbs:
            bulbs_list.append(all_bulbs[light])
    return bulbs_list


@app.after_request
async def cors(resp):
    resp.headers.add("Access-Control-Allow-Origin", "*")
    resp.headers.add("Access-Control-Allow-Headers", "*")
    resp.headers.add("Access-Control-Allow-Methods", "*")
    return resp


@app.route("/api/calculate_music_timings", methods=REQUEST_METHODS)
async def calculate_music_timings():
    try:
        if request.method == "GET":
            return make_message("Due to requiring file uploads, this endpoint only accepts POST requests.", status_code=405)
        data = await get_data()
        files = await request.files
        if "file" not in files:
            return make_message("No 'file' supplied.", status_code=400)
        file = files["file"]
        if file.filename == "":
            return make_message("Your music file does not have a name! Did you not select one?", status_code=400)

        mode = data["mode"]
        if mode not in ["cycle", "gradient"]:
            return make_message("Mode must be either 'cycle' or 'gradient'.", status_code=400)

        colors = get_list(data["colors"])
        send_delay = float(data["send_delay"])

        try:
            times, colors, transition_time = await rgb_light_control.calculate_music_timings(mode, colors, file, send_delay)
        except ValueError:
            return make_message("Invalid audio file!", status_code=400)
        data = {"times": times, "colors": colors, "transition_time": transition_time}
        return make_message("Calculated music timings!", data=data)
    except (KeyError, TypeError, ValueError):
        return make_message("'mode', 'colors', and/or 'send_delay' were not provided or invalid.")


@app.route("/api/estimate_light_delay", methods=REQUEST_METHODS)
async def estimate_light_delay():
    try:
        data = await get_data()
        bulbs_to_test = get_bulbs_list(data)
        num_tests = 40
        if "num_tests" in data:
            try:
                num_tests = int(data["num_tests"])
                if num_tests < 1 or num_tests > 50:
                    return make_message("Please only request 1-50 tests inclusive.")
            except ValueError:
                pass
        res = await rgb_light_control.estimate_send_delay(num_tests=num_tests, bulbs_to_test=bulbs_to_test)
        return make_message("Estimated send delay in seconds successfully!", data=res)
    except (KeyError, TypeError, ValueError):
        return make_message("Please provide 'lights' and optionally 'num_tests' in a valid format.", status_code=400)


@app.route("/api/get_lights", methods=REQUEST_METHODS)
async def get_lights():
    return make_message("Got light info!", data=all_bulbs_data)


@app.route("/api/set_hsv", methods=REQUEST_METHODS)
async def set_hsv():
    data = await get_data()
    try:
        h = int(data["h"])
        s = int(data["s"])
        v = int(data["v"])
        if h > 360 or h < 0:
            return make_message("h value must be between 0 and 360 inclusive!")
        elif s < 0 or s > 100 or v < 0 or v > 100:
            return make_message("s and v must be between 0 and 100 inclusive!")
        try:
            transition = int(data["transition"]) if "transition" in data else 0
        except ValueError:
            transition = 0
        bulbs_to_set = get_bulbs_list(data)
        await rgb_light_control.send_hsv(h, s, v, transition=transition, bulbs_to_send=bulbs_to_set)
        return make_message("Light HSV set!", 200)
    except (KeyError, TypeError, ValueError):
        return make_message("Please provide 'h', 's', 'v', and 'lights' in a valid format.", status_code=400)


@app.route("/api/ping", methods=REQUEST_METHODS)
async def ping():
    return make_message("Pong!")


@app.route("/")
async def home():
    return await send_from_directory("rgb_light_control_ui/build/web", "index.html")


@app.route("/<path:path>")
async def site(path):
    return await send_from_directory("rgb_light_control_ui/build/web", path)


if __name__ == "__main__":
    app.run(port=11647)
