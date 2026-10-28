# requests

A Python-[`requests`](https://requests.readthedocs.io/)-style ergonomic HTTP
client for [Zap](https://github.com/zaplang-io/zap). A small, faithful wrapper
over the Zap stdlib `http` client (transport, TLS, the netpoller) and `json` —
it adds the familiar verbs, a `Response` object, query-param encoding and JSON
bodies, but **reimplements no transport**: every request goes through
`http.get` / `http.post` / `http.request`.

`requests` is a non-core, official-tier package (D-0056): developed under
`zaplang-io`, installed and managed by the Zap package manager, not bundled in
the standard library.

## Quick start

```python
import requests

def main():
    auto r = requests.get("http://example.com/search",
                          {"Accept": "application/json"},     # headers
                          [("q", "zap"), ("n", "10")])        # query params
    if r.ok:
        print(r.status_code)      # 200
        print(r.text)             # body as text
        auto doc = r.json()       # parsed JsonValue
```

## API

All verbs return a `requests.Response` and take explicit arguments (Zap does not
have optional/keyword defaults yet — see [Language friction](#language-friction)):

| Function | Signature |
| --- | --- |
| `requests.get`     | `get(url, headers, params)` |
| `requests.post`    | `post(url, headers, data, json)` |
| `requests.put`     | `put(url, headers, data, json)` |
| `requests.delete`  | `delete(url, headers)` |
| `requests.head`    | `head(url, headers)` |
| `requests.request` | `request(method, url, headers, params, data, json)` |

Argument conventions (pass the empty value for "none"):

- **`url`** `str` — e.g. `"http://host:port/path"`. `http://` and `https://` are
  both supported; the path (including any existing `?query`) is sent verbatim.
- **`headers`** `dict[str, str]` — custom request headers; `{}` for none. Sent
  verbatim by the http client. A caller `Content-Type` overrides the default;
  `Host` / `Content-Length` / `Connection` are always computed by the transport.
- **`params`** `list[(str, str)]` — query parameters as `(name, value)` pairs;
  `[]` for none. Percent-encoded with `application/x-www-form-urlencoded` rules
  (unreserved kept, space → `+`, else `%XX` over UTF-8 bytes), then appended to
  the URL (respecting an existing `?`). A list of pairs — a form Python requests
  also accepts — rather than a dict, because Zap dicts are not iterable yet.
- **`data`** `str` — a raw request body; `""` for none.
- **`json`** `JsonValue` — a JSON body; `JsonValue.Null` for none (as Python
  requests treats `json=None`). When set, it is serialized with `json.dumps` and
  `Content-Type: application/json` is applied.

### `Response`

Built over the stdlib `http` response accessors:

| Member | Kind | Meaning |
| --- | --- | --- |
| `r.status_code` | `int64` attribute | HTTP status, e.g. `200` |
| `r.text`        | `str` attribute   | response body as text |
| `r.ok`          | `bool` attribute  | `True` when `status_code < 400` |
| `r.json()`      | method → `JsonValue` | body parsed as JSON (raises if invalid) |
| `r.header(name)`| method → `str`    | one response header, case-insensitive (`""` if absent) |

### `Session`

A `Session` applies a base URL and default headers to every request:

```python
import requests.session

def main():
    auto s = session.new("http://api.example.com",
                         {"Authorization": "Bearer t"})     # default headers
    auto r = s.get("/users", [("page", "2")])
    print(str(r.status_code))
```

Methods: `s.get(path, params)`, `s.post(path, data, json)`,
`s.put(path, data, json)`, `s.delete(path)`.

## Build & test

There is no local LLVM on most dev machines, so build and test through the
prebuilt Zap toolchain image (`ghcr.io/zaplang-io/zap`, zaplang-io/zap#277),
which is anonymously pullable. It ships no git/node, so run it via `docker run`
over the mounted workspace rather than a `container:` job:

```bash
# Offline mock-server test suite (compiles + runs against a local mock server):
docker run --rm -v "$PWD":/w -w /w ghcr.io/zaplang-io/zap:latest sh tools/run-tests.sh

# Compile-smoke the examples:
docker run --rm -v "$PWD":/w -w /w ghcr.io/zaplang-io/zap:latest sh tools/build-examples.sh
```

Both scripts honor `$ZAP` to point at a different `zap` binary (e.g. one built
from a sibling `zap` checkout), in which case run them directly:

```bash
ZAP=/path/to/zap sh tools/run-tests.sh
```

The toolchain image must include the string surface (#284), f-strings/conversions
(#285), request headers (#280) and module imports (#283); `latest` has carried
these since the main build at rev `72f4aff`.

### How the test exercises the library

`tests/requests_test.zap` drives `tests/mockserver.zap` — a scripted mock HTTP
server on an ephemeral localhost port (a goroutine parked on the netpoller) — and
golden-compares its stdout against `tests/requests_test.expected`. It is fully
offline and deterministic. It covers:

- a **GET** with query params + a custom header → the server echoes the method,
  the full path+query, and the header back, proving param encoding and header
  travel;
- a **POST** with a JSON body → the server echoes the (auto) `Content-Type` and
  the serialized body, and replies with a JSON document read back via `r.json()`;
- `Response.status_code` / `.text` / `.ok` / `.header()` / `.json()`;
- an **error (404)** status (`r.ok == False`).

`tools/run-tests.sh` assembles a build root holding the library modules next to
the test driver and mock server, because Zap resolves intra-project imports
relative to the entry file's directory (#283). This is real multi-module
compilation — no source concatenation.

## Layout

```
src/requests.zap          the public API (verbs + request)
src/requests/response.zap  the Response type
src/requests/encode.zap    query-string + JSON body encoding
src/requests/session.zap   the Session type
tests/                     offline mock-server test + golden
examples/                  runnable examples (compile-smoked by CI)
tools/                     test + example harness scripts
```

## Language friction

Building this on the hardened stdlib surfaced gaps in the Zap language/stdlib.
The API above is shaped around them; each is filed against `zaplang-io/zap`:

1. **No default / keyword arguments in codegen.** `SPEC.md` documents default
   arguments (D-0038) and by-name arguments, and sema accepts them, but codegen
   does not fill omitted defaults or reorder out-of-order keyword args — such
   calls emit an invalid LLVM module (wrong arg count / type). This is why every
   verb takes a fixed, fully-positional argument list instead of Python's
   `get(url, params=..., headers=...)`.
2. **Dicts are not iterable and have no `keys()`/`items()`.** A `dict` can be
   constructed, indexed, and `len`'d, but not walked — and `x in d` does not
   codegen (only `x in set`). So query params are taken as a `list` of pairs
   (iterable) rather than a dict, and a dict of params/headers cannot be merged
   or copied at the library level (hence `Session` sends exactly its default
   headers, and a `json=` body sets `Content-Type` on the passed headers dict
   in place).
3. **No full response-header mapping.** The stdlib `http` response exposes only
   per-name lookup (`http.header(resp, name)`), not the raw header block, so
   `Response` offers `r.header(name)` rather than a full case-insensitive
   `.headers` dict. (Companion to the server-side gap #279.)
