# A tiny offline mock HTTP server for the requests test suite.
#
# It serves a fixed script of responses on an ephemeral localhost port and
# reports, over a channel, what it saw on each request (method, path+query, and
# selected request headers / body) so the test can prove that params, headers
# and bodies travelled correctly. Deterministic: localhost only, no real
# network. Mirrors the approach used by the aws-lambda-runtime offline test.
#
# Responses are written with raw `net.send` rather than `http.respond` because
# http.respond cannot set custom response headers yet (stdlib gap #279) and the
# header-accessor test needs the server to emit one.

# Write a raw HTTP/1.1 response and close the connection. `extra` is any extra
# header lines, each ending in CRLF ("" for none).
def _send(bytes c, int64 status, str reason, str extra, str body):
    auto resp = "HTTP/1.1 " + str(status) + " " + reason + "\r\n" + extra + "Content-Length: " + str(len(body)) + "\r\nConnection: close\r\n\r\n" + body
    net.send(c, resp)
    net.close_conn(c)

# Request 1: a GET. Report method, full path (incl. query) and the X-Trace-Id
# request header; reply 200 with a custom X-Demo response header and a body.
def _serve_get(bytes l, channel[str] obs):
    auto c = net.accept(l)
    auto req = http.read_request(c)
    obs <- (http.method(req) + " " + http.path(req) + " trace=" + http.req_header(req, "x-trace-id"))
    _send(c, 200, "OK", "X-Demo: hello\r\n", "pong")

# Request 2: a POST. Report the Content-Type and the request body; reply 200
# with a JSON body so the test can exercise Response.json().
def _serve_post(bytes l, channel[str] obs):
    auto c = net.accept(l)
    auto req = http.read_request(c)
    obs <- ("ct=" + http.req_header(req, "content-type") + " body=" + http.req_body(req))
    _send(c, 200, "OK", "", "{\"ok\": true, \"n\": 7}")

# Request 3: anything -> 404, to exercise an error status.
def _serve_404(bytes l):
    auto c = net.accept(l)
    http.read_request(c)
    _send(c, 404, "Not Found", "", "nope")

# The scripted server: publish the bound port, then serve the three requests in
# order and close the listener.
def serve(channel[int64] portch, channel[str] obs):
    auto l = net.listen("127.0.0.1", 0)
    portch <- net.port(l)
    _serve_get(l, obs)
    _serve_post(l, obs)
    _serve_404(l)
    net.close_listener(l)
