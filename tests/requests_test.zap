# Offline test driver for the requests library. Runs the three scripted
# requests against the mock server (tests/mockserver.zap) and prints what it
# observes for golden comparison against tests/requests_test.expected
# (tools/run-tests.sh diffs the two). Printing + golden comparison is how the
# Zap compiler's own suite and the aws-lambda-runtime test exercise string
# values. Deterministic: localhost only, no real network.
#
# Coverage: query-param encoding, custom request headers, a JSON request body
# with the auto Content-Type, Response.status_code / .text / .ok / .header() /
# .json(), and an error (404) status.

import requests
import requests.session
import mockserver

def main():
    auto portch = channel[int64]()
    auto obs = channel[str](4)
    spawn mockserver.serve(portch, obs)
    auto port = <-portch
    auto base = "http://127.0.0.1:" + str(port)

    # 1) GET with query params + a custom header.
    auto r1 = requests.get(base + "/search", {"X-Trace-Id": "t-42"}, [("q", "a b"), ("n", "2")])
    print("GET observed: " + <-obs)
    print("GET status: " + str(r1.status_code))
    print("GET ok: " + str(r1.ok))
    print("GET text: " + r1.text)
    print("GET header X-Demo: " + r1.header("X-Demo"))

    # 2) POST a JSON body (Content-Type set automatically); read JSON response.
    auto payload = JsonValue.Object({"name": JsonValue.Str("Ada"), "age": JsonValue.Int(36)})
    auto r2 = requests.post(base + "/items", {}, "", payload)
    print("POST observed: " + <-obs)
    print("POST status: " + str(r2.status_code))
    match r2.json():
        case JsonValue.Object(f):
            match f["n"]:
                case JsonValue.Int(i):
                    print("POST json n: " + str(i))
                case _:
                    print("POST json n: ?")
        case _:
            print("POST json: not an object")

    # 3) An error status.
    auto r3 = requests.get(base + "/missing", {}, [])
    print("ERR status: " + str(r3.status_code))
    print("ERR ok: " + str(r3.ok))
