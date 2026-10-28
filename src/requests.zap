# requests — a Python-requests-style ergonomic HTTP client for Zap.
#
# A small, faithful wrapper over the stdlib `http` client (transport, TLS, the
# netpoller) and `json`. It does not reimplement transport — it composes:
#   requests.get / post / put / delete / head / request  ->  http.{get,post,request}
#   requests.Response                                     ->  http.{status,body,header}
#
# Example:
#   auto r = requests.get("http://example.com/search",
#                         {"Accept": "application/json"},     # headers
#                         [("q", "zap"), ("n", "10")])        # query params
#   if r.ok:
#       print(r.status_code)      # 200
#       print(r.text)             # body as text
#       auto doc = r.json()       # parsed JsonValue
#
# Argument conventions (see the README "Language friction" section for why these
# are explicit positionals rather than Python's optional keyword arguments —
# Zap does not codegen default arguments yet):
#   * headers : dict[str, str]        — pass {} for none. Sent verbatim by the
#                                       http client (which walks the dict in C).
#   * params  : list[(str, str)]      — query parameters as (name, value) pairs;
#                                       pass [] for none. A list, not a dict,
#                                       because dicts are not iterable in Zap
#                                       yet; this is a form Python requests also
#                                       accepts. Values are percent-encoded.
#   * data    : str                   — a raw request body; pass "" for none.
#   * json    : JsonValue             — a JSON body; pass JsonValue.Null for
#                                       none. When set, it is serialized and
#                                       Content-Type is set to application/json.

import requests.encode
import requests.response

# The general request. `method` is the HTTP verb ("GET", "POST", ...).
def request(str method, str url, dict[str, str] headers, list[(str, str)] params, str data, JsonValue json) -> response.Response:
    auto full = encode.build_url(url, params)
    match json:
        case JsonValue.Null:
            return response.make(http.request(method, full, data, headers))
        case _:
            headers["Content-Type"] = "application/json"
            return response.make(http.request(method, full, encode.dumps(json), headers))

# GET url with custom headers and query parameters ({} / [] for none).
def get(str url, dict[str, str] headers, list[(str, str)] params) -> response.Response:
    return request("GET", url, headers, params, "", JsonValue.Null)

# POST url with a string body (`data`, "" for none) or a JSON body (`json`,
# JsonValue.Null for none) and custom headers ({} for none).
def post(str url, dict[str, str] headers, str data, JsonValue json) -> response.Response:
    return request("POST", url, headers, [], data, json)

# PUT url with a string body (`data`) or a JSON body (`json`) and headers.
def put(str url, dict[str, str] headers, str data, JsonValue json) -> response.Response:
    return request("PUT", url, headers, [], data, json)

# DELETE url with custom headers ({} for none).
def delete(str url, dict[str, str] headers) -> response.Response:
    return request("DELETE", url, headers, [], "", JsonValue.Null)

# HEAD url with custom headers ({} for none).
def head(str url, dict[str, str] headers) -> response.Response:
    return request("HEAD", url, headers, [], "", JsonValue.Null)
