# requests.encode — URL query-string and JSON body encoding helpers.
#
# These back the `params=` and `json=` arguments of the request verbs.
#
# Query parameters are taken as a `list[(str, str)]` of (name, value) pairs —
# one of the forms Python `requests` accepts — rather than a `dict`, because the
# built-in `dict` cannot be iterated or copied in Zap today (see the README
# "Language friction" section): a dict of params could not be walked here to
# build the query string. Values are percent-encoded with the
# application/x-www-form-urlencoded rules (unreserved kept, space -> '+',
# everything else -> %XX over the UTF-8 bytes), matching requests' urlencode
# with the default quote_via=quote_plus.

# Is `o` (a codepoint value from ord()) an RFC 3986 unreserved character?
def _unreserved(int64 o) -> bool:
    if o >= 65 and o <= 90:            # A-Z
        return True
    if o >= 97 and o <= 122:           # a-z
        return True
    if o >= 48 and o <= 57:            # 0-9
        return True
    return o == 45 or o == 46 or o == 95 or o == 126   # - . _ ~

# Percent-encode one string with x-www-form-urlencoded rules (space -> '+').
def quote_plus(str s) -> str:
    auto out = ""
    for c in s:
        auto o = ord(c)
        if _unreserved(o):
            out = out + str(c)
        elif o == 32:
            out = out + "+"
        else:
            for b in str(c).encode():
                out = out + f"%{b:02X}"
    return out

# Encode (name, value) pairs into an `a=1&b=2` query string (already encoded).
def urlencode(list[(str, str)] params) -> str:
    list[str] parts = []
    for p in params:
        parts.append(quote_plus(p[0]) + "=" + quote_plus(p[1]))
    return "&".join(parts)

# Join a base URL with encoded query parameters, respecting an existing query.
def build_url(str url, list[(str, str)] params) -> str:
    if len(params) == 0:
        return url
    auto qs = urlencode(params)
    if url.contains("?"):
        return url + "&" + qs
    return url + "?" + qs

# Serialize a JsonValue to a compact JSON string (request body).
#
# Kept here, rather than inline in requests.zap, so the request verbs can name
# their body parameter `json` (faithful to Python requests) without shadowing
# the stdlib `json` module.
def dumps(JsonValue v) -> str:
    return json.dumps(v)
