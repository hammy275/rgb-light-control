from quart import Quart, request, jsonify
import os
import kasa
from typing import Any, Union
import asyncio

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
        return await request.json


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


@app.route("/estimate_light_delay")
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


@app.route("/get_lights", methods=REQUEST_METHODS)
async def get_lights():
    return make_message("Got light info!", data=all_bulbs_data)


@app.route("/set_hsv", methods=REQUEST_METHODS)
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


@app.route("/ping", methods=REQUEST_METHODS)
async def ping():
    return make_message("Pong!")


if __name__ == "__main__":
    app.run(port=11647)
