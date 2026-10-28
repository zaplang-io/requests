# requests.response — the Response object returned by every request verb.
#
# A thin, ergonomic view over the stdlib `http` response handle. `status_code`,
# `text` and `ok` are plain attributes (read them directly, as in Python
# requests); `json()` and `header()` are methods.

struct Response:
    int64 status_code      # HTTP status code, e.g. 200
    str text               # response body as text (requests' r.text)
    bool ok                # True when status_code < 400 (requests' r.ok)
    bytes _raw             # underlying stdlib http response handle

    # Parse the response body as JSON, returning the JsonValue DOM (r.json()).
    # Raises if the body is not valid JSON, like requests.
    def json(self) -> JsonValue:
        return json.loads(self.text)

    # Look up a single response header by name, case-insensitively; returns ""
    # when absent. Python requests exposes a full case-insensitive `.headers`
    # mapping, but the stdlib http response only offers per-name lookup today
    # (see the README "Language friction" section), so this is the v1 surface.
    def header(self, str name) -> str:
        return http.header(self._raw, name)

# Build a Response from a stdlib http response handle (reads status + body once).
def make(bytes raw) -> Response:
    auto code = http.status(raw)
    return Response(status_code=code, text=http.body(raw), ok=code < 400, _raw=raw)
