package gomoku

import std.fs.*
import std.net.*

let SERVER_PORT: UInt16 = 8080

class Request {
    let method: String
    let path: String
    let body: String

    init(method: String, path: String, body: String) {
        this.method = method
        this.path = path
        this.body = body
    }
}

class Response {
    let status: String
    let contentType: String
    let body: String

    init(status: String, contentType: String, body: String) {
        this.status = status
        this.contentType = contentType
        this.body = body
    }
}

func parseRequest(raw: String): Request {
    if (raw.size == 0) {
        return Request("", "", "")
    }

    let sections = raw.split("\r\n\r\n")
    let header = sections[0]
    var body = ""
    if (sections.size > 1) {
        body = sections[1]
    }

    let lines = header.split("\r\n")
    let firstLine = lines[0]
    let parts = firstLine.split(" ")
    var method = ""
    var path = "/"
    if (parts.size > 0) {
        method = parts[0]
    }
    if (parts.size > 1) {
        path = parts[1]
    }
    let queryIndex = indexOfOrMinusOne(path, "?")
    if (queryIndex >= 0) {
        path = path[0..queryIndex]
    }

    return Request(method, path, body)
}

func mimeType(path: String): String {
    if (path.endsWith(".css")) {
        return "text/css; charset=utf-8"
    }
    if (path.endsWith(".js")) {
        return "application/javascript; charset=utf-8"
    }
    if (path.endsWith(".html")) {
        return "text/html; charset=utf-8"
    }
    return "text/plain; charset=utf-8"
}

func staticResponse(path: String): Response {
    var filePath = "public/index.html"
    if (path != "/") {
        if (!path.startsWith("/assets/") || path.contains("..")) {
            return Response("404 Not Found", "application/json; charset=utf-8", errorJson("Not found."))
        }
        filePath = "public${path}"
    }

    if (!exists(filePath)) {
        return Response("404 Not Found", "application/json; charset=utf-8", errorJson("Static file not found."))
    }
    let body = String.fromUtf8(File.readFrom(filePath))
    return Response("200 OK", mimeType(filePath), body)
}

func apiResponse(request: Request): Response {
    if (request.method == "OPTIONS") {
        return Response("204 No Content", "text/plain; charset=utf-8", "")
    }

    if (request.method == "POST" && request.path == "/api/ai/move") {
        return Response("200 OK", "application/json; charset=utf-8", resultToJson(apiAiMove(request.body)))
    }
    if (request.method == "POST" && request.path == "/api/rooms") {
        return Response("200 OK", "application/json; charset=utf-8", createRoomJson())
    }

    if (request.path.startsWith("/api/rooms/")) {
        let parts = request.path.split("/")
        if (parts.size < 4) {
            return Response("404 Not Found", "application/json; charset=utf-8", errorJson("Room route not found."))
        }
        let roomId = parts[3]
        if (request.method == "GET" && parts.size == 4) {
            return Response("200 OK", "application/json; charset=utf-8", getRoomJson(roomId))
        }
        if (request.method == "POST" && parts.size == 5 && parts[4] == "join") {
            return Response("200 OK", "application/json; charset=utf-8", joinRoomJson(roomId))
        }
        if (request.method == "POST" && parts.size == 5 && parts[4] == "move") {
            return Response("200 OK", "application/json; charset=utf-8", moveRoomJson(roomId, request.body))
        }
        if (request.method == "POST" && parts.size == 5 && parts[4] == "reset") {
            return Response("200 OK", "application/json; charset=utf-8", resetRoomJson(roomId))
        }
    }

    return Response("404 Not Found", "application/json; charset=utf-8", errorJson("API route not found."))
}

func route(request: Request): Response {
    if (request.path.startsWith("/api/")) {
        return apiResponse(request)
    }
    return staticResponse(request.path)
}

func readRequest(socket: TcpSocket): String {
    let buffer = Array<Byte>(65536, repeat: 0)
    let count = socket.read(buffer)
    if (count <= 0) {
        return ""
    }
    return String.fromUtf8(buffer[0..count])
}

func writeResponse(socket: TcpSocket, response: Response): Unit {
    let bodyBytes = response.body.toArray()
    let header = "HTTP/1.1 ${response.status}\r\n" +
        "Content-Type: ${response.contentType}\r\n" +
        "Content-Length: ${bodyBytes.size}\r\n" +
        "Connection: close\r\n" +
        "Access-Control-Allow-Origin: *\r\n" +
        "Access-Control-Allow-Headers: Content-Type\r\n" +
        "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n" +
        "\r\n"
    socket.write((header + response.body).toArray())
}

func handleClient(socket: TcpSocket): Unit {
    let raw = readRequest(socket)
    let request = parseRequest(raw)
    let response = route(request)
    writeResponse(socket, response)
}

func runServer(): Unit {
    let server = TcpServerSocket(bindAt: SERVER_PORT)
    server.bind()
    println("Gomoku server running on http://0.0.0.0:${SERVER_PORT}")
    println("Open http://localhost:${SERVER_PORT} on this computer.")
    println("For LAN play, open http://<this-computer-ip>:${SERVER_PORT} on another device.")
    while (true) {
        let socket = server.accept()
        handleClient(socket)
        socket.close()
    }
}
