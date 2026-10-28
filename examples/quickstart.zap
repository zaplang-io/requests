# A quickstart example for the requests library. Compile-smoked by CI
# (tools/build-examples.sh); to actually run it, point it at a reachable server.
#
#   import requests
#   import requests.session

import requests
import requests.session

def main():
    # A plain GET with a custom header and query parameters. `params` is a list
    # of (name, value) pairs; `headers` is a dict (pass {} / [] for none).
    auto r = requests.get("http://httpbin.org/get",
                          {"Accept": "application/json"},
                          [("q", "zap lang"), ("n", "5")])
    print(str(r.status_code))      # e.g. 200
    print(str(r.ok))               # True for < 400
    print(r.text)                  # body as text
    print(r.header("Content-Type"))

    # Parse a JSON response body.
    match r.json():
        case JsonValue.Object(fields):
            print("got a JSON object")
        case _:
            print("some other JSON")

    # POST a JSON body (Content-Type is set to application/json automatically).
    auto payload = JsonValue.Object({"name": JsonValue.Str("Ada")})
    auto created = requests.post("http://httpbin.org/post", {}, "", payload)
    print(str(created.status_code))

    # A Session applies a base URL and default headers to every request.
    auto s = session.new("http://httpbin.org", {"Authorization": "Bearer token"})
    auto who = s.get("/headers", [])
    print(str(who.status_code))
