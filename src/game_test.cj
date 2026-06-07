package gomoku

import std.unittest.*
import std.unittest.testmacro.*

@Test
func horizontalWin(): Unit {
    let board = newBoard()
    for (col in 0..5) {
        board[7][col] = BLACK
    }
    @Expect(winnerAfter(board, 7, 4), BLACK)
}

@Test
func verticalWin(): Unit {
    let board = newBoard()
    for (row in 3..8) {
        board[row][8] = WHITE
    }
    @Expect(winnerAfter(board, 7, 8), WHITE)
}

@Test
func diagonalWins(): Unit {
    let board = newBoard()
    for (offset in 0..5) {
        board[2 + offset][2 + offset] = BLACK
    }
    @Expect(winnerAfter(board, 6, 6), BLACK)

    let anti = newBoard()
    for (offset in 0..5) {
        anti[2 + offset][10 - offset] = WHITE
    }
    @Expect(winnerAfter(anti, 6, 6), WHITE)
}

@Test
func rejectIllegalMove(): Unit {
    let board = newBoard()
    let first = placeMove(board, 7, 7, BLACK, EMPTY)
    @Expect(first.ok, true)
    let second = placeMove(board, 7, 7, WHITE, EMPTY)
    @Expect(second.ok, false)
    let outside = placeMove(board, 20, 0, WHITE, EMPTY)
    @Expect(outside.ok, false)
}

@Test
func aiTakesImmediateWin(): Unit {
    let board = newBoard()
    for (col in 3..7) {
        board[7][col] = WHITE
    }
    let move = chooseAiMove(board)
    @Expect(move.row, 7)
    @Expect(move.col, 2)
}

@Test
func aiBlocksImmediateLoss(): Unit {
    let board = newBoard()
    for (col in 4..8) {
        board[8][col] = BLACK
    }
    let move = chooseAiMove(board)
    @Expect(move.row, 8)
    @Expect(move.col, 3)
}

@Test
func roomCreateJoinAndMove(): Unit {
    createRoomJson()
    let id = "${nextRoomId}"
    @Expect(findRoomIndex(id) >= 0, true)
    joinRoomJson(id)
    let moved = moveRoomJson(id, "{\"player\":1,\"row\":7,\"col\":7}")
    @Expect(moved.contains("\"ok\":true"), true)
    @Expect(rooms[findRoomIndex(id)].board[7][7], BLACK)
}
