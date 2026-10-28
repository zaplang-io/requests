# requests.session — a Session that applies a base URL and default headers to
# every request.
#
#   import requests.session
#   auto s = session.new("http://api.example.com", {"Authorization": "Bearer t"})
#   auto r = s.get("/users", [("page", "2")])
#
# v1 sends exactly the session's default headers on each request; per-call
# headers are not merged in, because Zap cannot iterate or copy a dict yet (see
# the README "Language friction" section). `base_url` is prepended to the path
# passed to each verb.

import requests
import requests.response

struct Session:
    str base_url
    dict[str, str] headers

    def get(self, str path, list[(str, str)] params) -> response.Response:
        return requests.get(self.base_url + path, self.headers, params)

    def post(self, str path, str data, JsonValue json) -> response.Response:
        return requests.post(self.base_url + path, self.headers, data, json)

    def put(self, str path, str data, JsonValue json) -> response.Response:
        return requests.put(self.base_url + path, self.headers, data, json)

    def delete(self, str path) -> response.Response:
        return requests.delete(self.base_url + path, self.headers)

# Construct a Session from a base URL and default headers ({} for none).
def new(str base_url, dict[str, str] headers) -> Session:
    return Session(base_url=base_url, headers=headers)
