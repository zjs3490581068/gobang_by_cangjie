package gomoku

import std.collection.ArrayList

var rooms = ArrayList<RoomState>()
var nextRoomId: Int64 = 1000

class RoomState {
    let id: String
    let board: Array<Array<Int64>>
    var turn: Int64
    var winner: Int64
    var lastRow: Int64
    var lastCol: Int64
    var whiteJoined: Bool

    init(id: String) {
        this.id = id
        this.board = newBoard()
        this.turn = BLACK
        this.winner = EMPTY
        this.lastRow = -1
        this.lastCol = -1
        this.whiteJoined = false
    }
}

func findRoomIndex(id: String): Int64 {
    for (index in 0..rooms.size) {
        if (rooms[index].id == id) {
            return index
        }
    }
    return -1
}

func errorJson(message: String): String {
    return "{\"ok\":false,\"message\":\"${escapeJson(message)}\"}"
}

func roomToJson(room: RoomState, ok: Bool, message: String, player: Int64): String {
    return "{" +
        "\"ok\":${ok}," +
        "\"message\":\"${escapeJson(message)}\"," +
        "\"roomId\":\"${room.id}\"," +
        "\"player\":${player}," +
        "\"board\":${boardToJson(room.board)}," +
        "\"turn\":${room.turn}," +
        "\"winner\":${room.winner}," +
        "\"lastMove\":{\"row\":${room.lastRow},\"col\":${room.lastCol}}," +
        "\"whiteJoined\":${room.whiteJoined}" +
        "}"
}

func createRoomJson(): String {
    nextRoomId++
    let id = "${nextRoomId}"
    let room = RoomState(id)
    rooms.add(room)
    return roomToJson(room, true, "Room created. Share the room id with another player.", BLACK)
}

func joinRoomJson(id: String): String {
    let index = findRoomIndex(id)
    if (index < 0) {
        return errorJson("Room not found.")
    }
    let room = rooms[index]
    if (room.whiteJoined) {
        return errorJson("Room already has two players.")
    }
    room.whiteJoined = true
    return roomToJson(room, true, "Joined as white.", WHITE)
}

func getRoomJson(id: String): String {
    let index = findRoomIndex(id)
    if (index < 0) {
        return errorJson("Room not found.")
    }
    return roomToJson(rooms[index], true, "Room state loaded.", EMPTY)
}

func moveRoomJson(id: String, body: String): String {
    let index = findRoomIndex(id)
    if (index < 0) {
        return errorJson("Room not found.")
    }
    let room = rooms[index]
    let player = jsonInt(body, "player", EMPTY)
    let row = jsonInt(body, "row", -1)
    let col = jsonInt(body, "col", -1)

    if (player != BLACK && player != WHITE) {
        return roomToJson(room, false, "Invalid player.", player)
    }
    if (player == WHITE && !room.whiteJoined) {
        return roomToJson(room, false, "White has not joined this room yet.", player)
    }
    if (player == BLACK && !room.whiteJoined) {
        return roomToJson(room, false, "Waiting for the white player to join.", player)
    }
    if (room.winner != EMPTY) {
        return roomToJson(room, false, "Game is already over.", player)
    }
    if (room.turn != player) {
        return roomToJson(room, false, "It is not your turn.", player)
    }

    let result = placeMove(room.board, row, col, player, room.winner)
    if (result.ok) {
        room.turn = result.turn
        room.winner = result.winner
        room.lastRow = result.lastRow
        room.lastCol = result.lastCol
    }
    return roomToJson(room, result.ok, result.message, player)
}

func resetRoomJson(id: String): String {
    let index = findRoomIndex(id)
    if (index < 0) {
        return errorJson("Room not found.")
    }
    let room = rooms[index]
    for (row in 0..BOARD_SIZE) {
        for (col in 0..BOARD_SIZE) {
            room.board[row][col] = EMPTY
        }
    }
    room.turn = BLACK
    room.winner = EMPTY
    room.lastRow = -1
    room.lastCol = -1
    return roomToJson(room, true, "Room reset.", EMPTY)
}
