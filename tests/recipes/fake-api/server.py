"""Answers like Peekaboot with one canned case per first path segment, such as /trace-read-401/orders/42.

Binds a port the system picks and prints it once listening.
"""
import json
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

TRACE_ID = "0123456789abcdef0123456789abcdef"


def stack(frame):
    return f"java.lang.IllegalStateException: boom\n\tat com.example.shop.{frame}.run({frame}.java:1)"


def span(span_id, exception=None, children=()):
    return {"spanId": span_id, "children": list(children), "exception": exception}


def error_log(span_id, message, stack_trace=None):
    return {"spanId": span_id, "level": "ERROR", "message": message, "stackTrace": stack_trace}


def trace(cause, root, orphans=(), logs=(), complete=True):
    return {
        "summary": {"complete": complete, "outcome": "ERROR" if cause else "OK", "cause": cause, "reasons": []},
        "data": {"rootSpan": root, "orphans": list(orphans), "logs": list(logs)},
    }


def cause(type_, message, span_id="a"):
    return {"type": type_, "message": message, "spanId": span_id}


EXCEPTION = "java.lang.IllegalStateException"
TRACES = {
    "cause-logged-with-stack": trace(cause(EXCEPTION, "boom"), span("a"),
                                     logs=[error_log("a", "Order failed", stack("Logged"))]),
    "cause-logged-without-stack": trace(cause(None, "Order failed"), span("a"), logs=[error_log("a", "Order failed")]),
    "cause-server-error-only": trace(cause(None, "Answered with status 500."), span("a")),
    "cause-type-without-stack": trace(cause(EXCEPTION, None), span("a", {"type": EXCEPTION, "stackTrace": None})),
    "cause-exception-without-type": trace(cause(None, "boom"),
                                          span("a", {"type": None, "message": "boom", "stackTrace": None})),
    # The root span never arrives, so the trace stays incomplete and the cause sits in an orphan.
    "cause-in-orphan": trace(
        cause(EXCEPTION, "boom", "b"), None, complete=False,
        orphans=[span("o", children=[span("b", {"type": EXCEPTION, "stackTrace": stack("Orphan")})])]),
    "request-succeeded": trace(None, span("a")),
}
STATUSES = {"trace-read-401": 401, "trace-read-404": 404, "trace-read-other-status": 503}


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        case, _, path = self.path.lstrip("/").partition("/")
        if path.startswith("peekaboot/api/traces/"):
            # Returning without a reply closes the connection, which curl reports as status 000.
            if case == "trace-read-000":
                return
            status = STATUSES.get(case, 200)
            self.reply(status, TRACES[case] if status == 200 else {"status": status})
        elif path.startswith("peekaboot/api/errors"):
            self.reply(200, {"errors": []})
        else:
            status = 200 if case == "request-succeeded" else 500
            self.reply(status, {}, f'trace;desc="00-{TRACE_ID}-0123456789abcdef-01"')

    def reply(self, status, body, server_timing=None):
        data = json.dumps(body).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        if server_timing:
            self.send_header("Server-Timing", server_timing)
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, *args):
        pass


server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
print(server.server_port, flush=True)
server.serve_forever()
