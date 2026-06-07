package gomoku

let BOARD_SIZE: Int64 = 15
let EMPTY: Int64 = 0
let BLACK: Int64 = 1
let WHITE: Int64 = 2
let DRAW: Int64 = 3

class Move {
    let row: Int64
    let col: Int64

    init(row: Int64, col: Int64) {
        this.row = row
        this.col = col
    }
}

class GameResult {
    let ok: Bool
    let message: String
    let board: Array<Array<Int64>>
    let turn: Int64
    let winner: Int64
    let lastRow: Int64
    let lastCol: Int64

    init(
        ok: Bool,
        message: String,
        board: Array<Array<Int64>>,
        turn: Int64,
        winner: Int64,
        lastRow: Int64,
        lastCol: Int64
    ) {
        this.ok = ok
        this.message = message
        this.board = board
        this.turn = turn
        this.winner = winner
        this.lastRow = lastRow
        this.lastCol = lastCol
    }
}

func newBoard(): Array<Array<Int64>> {
    return Array<Array<Int64>>(BOARD_SIZE, { _ => Array<Int64>(BOARD_SIZE, repeat: EMPTY) })
}

func inBounds(row: Int64, col: Int64): Bool {
    return row >= 0 && row < BOARD_SIZE && col >= 0 && col < BOARD_SIZE
}

func otherPlayer(piece: Int64): Int64 {
    if (piece == BLACK) {
        return WHITE
    }
    return BLACK
}

func abs64(value: Int64): Int64 {
    if (value < 0) {
        return -value
    }
    return value
}

func countDirection(board: Array<Array<Int64>>, row: Int64, col: Int64, dr: Int64, dc: Int64, piece: Int64): Int64 {
    var r = row + dr
    var c = col + dc
    var count: Int64 = 0
    while (inBounds(r, c) && board[r][c] == piece) {
        count++
        r += dr
        c += dc
    }
    return count
}

func winnerAfter(board: Array<Array<Int64>>, row: Int64, col: Int64): Int64 {
    if (!inBounds(row, col)) {
        return EMPTY
    }
    let piece = board[row][col]
    if (piece == EMPTY) {
        return EMPTY
    }

    let directions = [
        Move(0, 1),
        Move(1, 0),
        Move(1, 1),
        Move(1, -1)
    ]
    for (direction in directions) {
        let total = 1 +
            countDirection(board, row, col, direction.row, direction.col, piece) +
            countDirection(board, row, col, -direction.row, -direction.col, piece)
        if (total >= 5) {
            return piece
        }
    }
    return EMPTY
}

func isBoardFull(board: Array<Array<Int64>>): Bool {
    for (row in 0..BOARD_SIZE) {
        for (col in 0..BOARD_SIZE) {
            if (board[row][col] == EMPTY) {
                return false
            }
        }
    }
    return true
}

func validateMove(board: Array<Array<Int64>>, row: Int64, col: Int64, winner: Int64): String {
    if (winner != EMPTY) {
        return "Game is already over."
    }
    if (!inBounds(row, col)) {
        return "Move is outside the board."
    }
    if (board[row][col] != EMPTY) {
        return "This point is already occupied."
    }
    return ""
}

func placeMove(board: Array<Array<Int64>>, row: Int64, col: Int64, piece: Int64, winner: Int64): GameResult {
    let error = validateMove(board, row, col, winner)
    if (error != "") {
        return GameResult(false, error, board, piece, winner, row, col)
    }

    board[row][col] = piece
    var nextWinner = winnerAfter(board, row, col)
    var nextTurn = otherPlayer(piece)
    var message = "Move accepted."
    if (nextWinner == BLACK) {
        message = "Black wins."
        nextTurn = BLACK
    } else if (nextWinner == WHITE) {
        message = "White wins."
        nextTurn = WHITE
    } else if (isBoardFull(board)) {
        nextWinner = DRAW
        message = "Draw."
        nextTurn = piece
    }
    return GameResult(true, message, board, nextTurn, nextWinner, row, col)
}

func hasNeighbor(board: Array<Array<Int64>>, row: Int64, col: Int64): Bool {
    for (dr in -1..2) {
        for (dc in -1..2) {
            if (dr == 0 && dc == 0) {
                continue
            }
            let nr = row + dr
            let nc = col + dc
            if (inBounds(nr, nc) && board[nr][nc] != EMPTY) {
                return true
            }
        }
    }
    return false
}

func openEnd(board: Array<Array<Int64>>, row: Int64, col: Int64, dr: Int64, dc: Int64, distance: Int64): Int64 {
    let r = row + dr * distance
    let c = col + dc * distance
    if (inBounds(r, c) && board[r][c] == EMPTY) {
        return 1
    }
    return 0
}

func scoreLine(board: Array<Array<Int64>>, row: Int64, col: Int64, dr: Int64, dc: Int64, piece: Int64): Int64 {
    let left = countDirection(board, row, col, -dr, -dc, piece)
    let right = countDirection(board, row, col, dr, dc, piece)
    let run = left + right + 1
    let open = openEnd(board, row, col, -dr, -dc, left + 1) +
        openEnd(board, row, col, dr, dc, right + 1)

    if (run >= 5) {
        return 100000
    }
    if (run == 4 && open == 2) {
        return 20000
    }
    if (run == 4 && open == 1) {
        return 8000
    }
    if (run == 3 && open == 2) {
        return 2500
    }
    if (run == 3 && open == 1) {
        return 700
    }
    if (run == 2 && open == 2) {
        return 250
    }
    if (run == 2 && open == 1) {
        return 80
    }
    return run * 10 + open * 4
}

func scorePosition(board: Array<Array<Int64>>, row: Int64, col: Int64, piece: Int64): Int64 {
    if (board[row][col] != EMPTY) {
        return -1
    }
    board[row][col] = piece
    var score: Int64 = 0
    let directions = [
        Move(0, 1),
        Move(1, 0),
        Move(1, 1),
        Move(1, -1)
    ]
    for (direction in directions) {
        score += scoreLine(board, row, col, direction.row, direction.col, piece)
    }
    board[row][col] = EMPTY

    let center = BOARD_SIZE / 2
    let distance = abs64(row - center) + abs64(col - center)
    return score + (30 - distance)
}

func hasAnyPiece(board: Array<Array<Int64>>): Bool {
    for (row in 0..BOARD_SIZE) {
        for (col in 0..BOARD_SIZE) {
            if (board[row][col] != EMPTY) {
                return true
            }
        }
    }
    return false
}

func chooseAiMove(board: Array<Array<Int64>>): Move {
    let center = BOARD_SIZE / 2
    if (!hasAnyPiece(board) && board[center][center] == EMPTY) {
        return Move(center, center)
    }

    for (row in 0..BOARD_SIZE) {
        for (col in 0..BOARD_SIZE) {
            if (board[row][col] == EMPTY && hasNeighbor(board, row, col)) {
                board[row][col] = WHITE
                let winner = winnerAfter(board, row, col)
                board[row][col] = EMPTY
                if (winner == WHITE) {
                    return Move(row, col)
                }
            }
        }
    }

    for (row in 0..BOARD_SIZE) {
        for (col in 0..BOARD_SIZE) {
            if (board[row][col] == EMPTY && hasNeighbor(board, row, col)) {
                board[row][col] = BLACK
                let winner = winnerAfter(board, row, col)
                board[row][col] = EMPTY
                if (winner == BLACK) {
                    return Move(row, col)
                }
            }
        }
    }

    var best = Move(center, center)
    var bestScore: Int64 = -1
    for (row in 0..BOARD_SIZE) {
        for (col in 0..BOARD_SIZE) {
            if (board[row][col] == EMPTY && (hasNeighbor(board, row, col) || !hasAnyPiece(board))) {
                let attack = scorePosition(board, row, col, WHITE)
                let defense = scorePosition(board, row, col, BLACK)
                let score = attack * 2 + defense
                if (score > bestScore) {
                    bestScore = score
                    best = Move(row, col)
                }
            }
        }
    }
    if (board[best.row][best.col] == EMPTY) {
        return best
    }
    for (row in 0..BOARD_SIZE) {
        for (col in 0..BOARD_SIZE) {
            if (board[row][col] == EMPTY) {
                return Move(row, col)
            }
        }
    }
    return Move(-1, -1)
}

func boardToJson(board: Array<Array<Int64>>): String {
    var text = "["
    for (row in 0..BOARD_SIZE) {
        if (row > 0) {
            text += ","
        }
        text += "["
        for (col in 0..BOARD_SIZE) {
            if (col > 0) {
                text += ","
            }
            text += "${board[row][col]}"
        }
        text += "]"
    }
    text += "]"
    return text
}

func escapeJson(value: String): String {
    var escaped = ""
    for (byte in value.toArray()) {
        if (byte == 34) {
            escaped += "\\\""
        } else if (byte == 92) {
            escaped += "\\\\"
        } else if (byte == 10) {
            escaped += "\\n"
        } else if (byte == 13) {
            escaped += "\\r"
        } else {
            escaped += String.fromUtf8([byte])
        }
    }
    return escaped
}

func resultToJson(result: GameResult): String {
    return "{" +
        "\"ok\":${result.ok}," +
        "\"message\":\"${escapeJson(result.message)}\"," +
        "\"board\":${boardToJson(result.board)}," +
        "\"turn\":${result.turn}," +
        "\"winner\":${result.winner}," +
        "\"lastMove\":{\"row\":${result.lastRow},\"col\":${result.lastCol}}" +
        "}"
}

func indexOfOrMinusOne(source: String, needle: String): Int64 {
    match (source.indexOf(needle)) {
        case Some(value) => return value
        case None => return -1
    }
}

func parseIntAt(source: String, start: Int64, fallback: Int64): Int64 {
    let bytes = source.toArray()
    var i = start
    while (i < bytes.size && (bytes[i] == 32 || bytes[i] == 9 || bytes[i] == 10 || bytes[i] == 13 || bytes[i] == 34)) {
        i++
    }

    var sign: Int64 = 1
    if (i < bytes.size && bytes[i] == 45) {
        sign = -1
        i++
    }

    var value: Int64 = 0
    var seenDigit = false
    while (i < bytes.size && bytes[i] >= 48 && bytes[i] <= 57) {
        seenDigit = true
        value = value * 10 + Int64(bytes[i] - 48)
        i++
    }

    if (!seenDigit) {
        return fallback
    }
    return value * sign
}

func jsonInt(body: String, key: String, fallback: Int64): Int64 {
    let marker = "\"${key}\""
    let keyIndex = indexOfOrMinusOne(body, marker)
    if (keyIndex < 0) {
        return fallback
    }
    let tail = body[(keyIndex + marker.size)..body.size]
    let colonIndex = indexOfOrMinusOne(tail, ":")
    if (colonIndex < 0) {
        return fallback
    }
    return parseIntAt(tail, colonIndex + 1, fallback)
}

func jsonString(body: String, key: String): String {
    let marker = "\"${key}\""
    let keyIndex = indexOfOrMinusOne(body, marker)
    if (keyIndex < 0) {
        return ""
    }
    let tail = body[(keyIndex + marker.size)..body.size]
    let colonIndex = indexOfOrMinusOne(tail, ":")
    if (colonIndex < 0) {
        return ""
    }
    let afterColon = tail[(colonIndex + 1)..tail.size]
    let firstQuote = indexOfOrMinusOne(afterColon, "\"")
    if (firstQuote < 0) {
        return ""
    }
    let afterQuote = afterColon[(firstQuote + 1)..afterColon.size]
    let endQuote = indexOfOrMinusOne(afterQuote, "\"")
    if (endQuote < 0) {
        return ""
    }
    return afterQuote[0..endQuote]
}

func parseBoardCsv(csv: String): Array<Array<Int64>> {
    let board = newBoard()
    let bytes = csv.toArray()
    var index: Int64 = 0
    var value: Int64 = 0
    var seenDigit = false
    for (byte in bytes) {
        if (byte >= 48 && byte <= 57) {
            seenDigit = true
            value = value * 10 + Int64(byte - 48)
        } else if (seenDigit) {
            if (index < BOARD_SIZE * BOARD_SIZE) {
                board[index / BOARD_SIZE][index % BOARD_SIZE] = value
            }
            index++
            value = 0
            seenDigit = false
        }
    }
    if (seenDigit && index < BOARD_SIZE * BOARD_SIZE) {
        board[index / BOARD_SIZE][index % BOARD_SIZE] = value
    }
    return board
}

func apiAiMove(body: String): GameResult {
    let board = parseBoardCsv(jsonString(body, "board"))
    let row = jsonInt(body, "row", -1)
    let col = jsonInt(body, "col", -1)
    var result = placeMove(board, row, col, BLACK, EMPTY)
    if (!result.ok || result.winner != EMPTY) {
        return result
    }

    let aiMove = chooseAiMove(board)
    if (!inBounds(aiMove.row, aiMove.col)) {
        return GameResult(true, "Draw.", board, BLACK, DRAW, row, col)
    }
    result = placeMove(board, aiMove.row, aiMove.col, WHITE, EMPTY)
    return GameResult(result.ok, result.message, result.board, result.turn, result.winner, aiMove.row, aiMove.col)
}
