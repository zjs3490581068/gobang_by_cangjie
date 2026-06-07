const SIZE = 15;
const EMPTY = 0;
const BLACK = 1;
const WHITE = 2;
const DRAW = 3;

const boardEl = document.querySelector("#board");
const statusLine = document.querySelector("#statusLine");
const turnBadge = document.querySelector("#turnBadge");
const modeTitle = document.querySelector("#modeTitle");
const modeSubtitle = document.querySelector("#modeSubtitle");
const onlinePanel = document.querySelector("#onlinePanel");
const roomInput = document.querySelector("#roomInput");
const roomInfo = document.querySelector("#roomInfo");
const createRoomBtn = document.querySelector("#createRoomBtn");
const joinRoomBtn = document.querySelector("#joinRoomBtn");
const copyRoomBtn = document.querySelector("#copyRoomBtn");
const restartBtn = document.querySelector("#restartBtn");
const undoBtn = document.querySelector("#undoBtn");
const modeButtons = [...document.querySelectorAll(".mode-btn")];
const gameOver = document.querySelector("#gameOver");
const gameOverTitle = document.querySelector("#gameOverTitle");
const gameOverText = document.querySelector("#gameOverText");
const gameOverRestartBtn = document.querySelector("#gameOverRestartBtn");

let mode = "local";
let board = freshBoard();
let turn = BLACK;
let winner = EMPTY;
let lastMove = { row: -1, col: -1 };
let history = [];
let busy = false;
let online = {
  roomId: "",
  player: EMPTY,
  polling: null,
  whiteJoined: false
};

function freshBoard() {
  return Array.from({ length: SIZE }, () => Array(SIZE).fill(EMPTY));
}

function cloneBoard(source) {
  return source.map((row) => row.slice());
}

function other(piece) {
  return piece === BLACK ? WHITE : BLACK;
}

function pieceName(piece) {
  if (piece === BLACK) return "黑棋";
  if (piece === WHITE) return "白棋";
  if (piece === DRAW) return "平局";
  return "无";
}

function boardCsv() {
  return board.flat().join(",");
}

function countDirection(row, col, dr, dc, piece) {
  let r = row + dr;
  let c = col + dc;
  let count = 0;
  while (r >= 0 && r < SIZE && c >= 0 && c < SIZE && board[r][c] === piece) {
    count += 1;
    r += dr;
    c += dc;
  }
  return count;
}

function winnerAfter(row, col) {
  const piece = board[row][col];
  if (!piece) return EMPTY;
  const directions = [
    [0, 1],
    [1, 0],
    [1, 1],
    [1, -1]
  ];
  for (const [dr, dc] of directions) {
    const total = 1 + countDirection(row, col, dr, dc, piece) + countDirection(row, col, -dr, -dc, piece);
    if (total >= 5) return piece;
  }
  return board.flat().every(Boolean) ? DRAW : EMPTY;
}

function findWinner() {
  for (let row = 0; row < SIZE; row += 1) {
    for (let col = 0; col < SIZE; col += 1) {
      if (board[row][col] && winnerAfter(row, col)) {
        return winnerAfter(row, col);
      }
    }
  }
  return EMPTY;
}

function inferTurn() {
  let black = 0;
  let white = 0;
  for (const row of board) {
    for (const cell of row) {
      if (cell === BLACK) black += 1;
      if (cell === WHITE) white += 1;
    }
  }
  return black <= white ? BLACK : WHITE;
}

function setStatus(message, danger = false) {
  statusLine.textContent = message;
  statusLine.classList.toggle("danger", danger);
}

function updateBadge() {
  if (winner === BLACK || winner === WHITE) {
    turnBadge.textContent = `${pieceName(winner)}获胜`;
    return;
  }
  if (winner === DRAW) {
    turnBadge.textContent = "平局";
    return;
  }
  turnBadge.textContent = `轮到${pieceName(turn)}`;
}

function gameOverMessage() {
  if (winner === BLACK || winner === WHITE) {
    return {
      title: `${pieceName(winner)}获胜`,
      text: `${pieceName(winner)}已经连成五子。点击按钮开始下一局。`
    };
  }
  if (winner === DRAW) {
    return {
      title: "平局",
      text: "棋盘已经下满。点击按钮重新开始。"
    };
  }
  return {
    title: "",
    text: ""
  };
}

function renderGameOver() {
  if (winner === EMPTY) {
    gameOver.classList.add("hidden");
    return;
  }
  const message = gameOverMessage();
  gameOverTitle.textContent = message.title;
  gameOverText.textContent = message.text;
  gameOver.classList.remove("hidden");
}

function renderBoard() {
  boardEl.innerHTML = "";
  for (let row = 0; row < SIZE; row += 1) {
    for (let col = 0; col < SIZE; col += 1) {
      const cell = document.createElement("button");
      cell.className = "cell";
      cell.type = "button";
      cell.dataset.row = String(row);
      cell.dataset.col = String(col);
      cell.style.setProperty("--row", String(row));
      cell.style.setProperty("--col", String(col));
      cell.disabled = busy || winner !== EMPTY || board[row][col] !== EMPTY;
      cell.setAttribute("aria-label", `${row + 1} 行 ${col + 1} 列`);
      if (lastMove.row === row && lastMove.col === col) {
        cell.classList.add("last");
      }
      if (board[row][col] !== EMPTY) {
        const stone = document.createElement("span");
        stone.className = `stone ${board[row][col] === BLACK ? "black" : "white"}`;
        cell.appendChild(stone);
      }
      boardEl.appendChild(cell);
    }
  }
  updateBadge();
  renderGameOver();
  undoBtn.disabled = mode === "online" || history.length === 0 || busy;
}

function resetLocalState() {
  board = freshBoard();
  turn = BLACK;
  winner = EMPTY;
  lastMove = { row: -1, col: -1 };
  history = [];
  busy = false;
}

function modeText() {
  if (mode === "ai") {
    modeTitle.textContent = "人机对战";
    modeSubtitle.textContent = "你执黑棋，仓颉后端负责白棋 AI 落子。";
  } else if (mode === "online") {
    modeTitle.textContent = "局域网联机";
    modeSubtitle.textContent = "一台设备创建房间，另一台设备输入房间号加入。";
  } else {
    modeTitle.textContent = "本地双人";
    modeSubtitle.textContent = "同一台设备轮流落子，黑棋先手。";
  }
}

function updateModeUi() {
  modeButtons.forEach((button) => button.classList.toggle("active", button.dataset.mode === mode));
  onlinePanel.classList.toggle("hidden", mode !== "online");
  modeText();
}

function localStatus() {
  if (winner === BLACK || winner === WHITE) {
    return `${pieceName(winner)}获胜。`;
  }
  if (winner === DRAW) {
    return "棋盘已满，平局。";
  }
  if (mode === "ai") {
    return turn === BLACK ? "轮到你落子。" : "AI 正在思考。";
  }
  return `轮到${pieceName(turn)}落子。`;
}

function renderAll(message = "") {
  renderBoard();
  if (message) {
    setStatus(message);
  } else if (mode === "online" && online.roomId) {
    setStatus(onlineStatus());
  } else {
    setStatus(localStatus());
  }
  renderRoomInfo();
}

function applyServerState(data) {
  if (Array.isArray(data.board)) {
    board = data.board;
  }
  if (typeof data.turn === "number") {
    turn = data.turn;
  }
  if (typeof data.winner === "number") {
    winner = data.winner;
  }
  if (data.lastMove) {
    lastMove = data.lastMove;
  }
  if (typeof data.whiteJoined === "boolean") {
    online.whiteJoined = data.whiteJoined;
  }
}

async function postJson(url, payload = {}) {
  const response = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload)
  });
  return response.json();
}

async function getJson(url) {
  const response = await fetch(url);
  return response.json();
}

function placeLocal(row, col) {
  history.push(cloneBoard(board));
  board[row][col] = turn;
  lastMove = { row, col };
  winner = winnerAfter(row, col);
  if (winner === EMPTY) {
    turn = other(turn);
  }
  renderAll();
}

async function placeAi(row, col) {
  history.push(cloneBoard(board));
  busy = true;
  renderAll("AI 正在思考。");
  try {
    const data = await postJson("/api/ai/move", {
      board: boardCsv(),
      row,
      col
    });
    if (!data.ok) {
      history.pop();
      setStatus(data.message || "AI 请求失败。", true);
    } else {
      applyServerState(data);
      setStatus(localStatus());
    }
  } catch (_) {
    history.pop();
    setStatus("无法连接仓颉后端。", true);
  } finally {
    busy = false;
    renderBoard();
    renderRoomInfo();
  }
}

async function placeOnline(row, col) {
  if (!online.roomId || !online.player) {
    setStatus("请先创建或加入房间。", true);
    return;
  }
  if (!online.whiteJoined) {
    setStatus("等待另一位玩家加入房间。", true);
    return;
  }
  if (turn !== online.player) {
    setStatus("还没轮到你。", true);
    return;
  }

  busy = true;
  renderAll("正在提交落子。");
  try {
    const data = await postJson(`/api/rooms/${online.roomId}/move`, {
      player: online.player,
      row,
      col
    });
    applyServerState(data);
    setStatus(data.message || onlineStatus(), !data.ok);
  } catch (_) {
    setStatus("无法连接仓颉后端。", true);
  } finally {
    busy = false;
    renderBoard();
    renderRoomInfo();
  }
}

function handleCellClick(event) {
  const cell = event.target.closest(".cell");
  if (!cell || busy) return;
  const row = Number(cell.dataset.row);
  const col = Number(cell.dataset.col);
  if (board[row][col] !== EMPTY || winner !== EMPTY) return;

  if (mode === "online") {
    placeOnline(row, col);
  } else if (mode === "ai") {
    if (turn !== BLACK) return;
    placeAi(row, col);
  } else {
    placeLocal(row, col);
  }
}

function stopPolling() {
  if (online.polling) {
    window.clearInterval(online.polling);
    online.polling = null;
  }
}

function startPolling() {
  stopPolling();
  online.polling = window.setInterval(pollRoom, 1000);
  pollRoom();
}

function onlineStatus() {
  if (!online.roomId) return "尚未进入房间。";
  if (winner === BLACK || winner === WHITE) return `${pieceName(winner)}获胜。`;
  if (winner === DRAW) return "棋盘已满，平局。";
  if (!online.whiteJoined) return "等待白棋玩家加入。";
  if (turn === online.player) return "轮到你落子。";
  return `等待${pieceName(turn)}落子。`;
}

function renderRoomInfo() {
  if (!online.roomId) {
    roomInfo.textContent = "尚未进入房间";
    return;
  }
  const color = online.player ? pieceName(online.player) : "观战";
  roomInfo.innerHTML = `房间号：<strong>${online.roomId}</strong><br>你的身份：${color}<br>${onlineStatus()}`;
}

async function createRoom() {
  mode = "online";
  updateModeUi();
  resetLocalState();
  try {
    const data = await postJson("/api/rooms");
    if (data.ok) {
      online.roomId = data.roomId;
      online.player = data.player;
      applyServerState(data);
      roomInput.value = data.roomId;
      startPolling();
      renderAll("房间已创建，等待另一台设备加入。");
    } else {
      setStatus(data.message || "创建房间失败。", true);
    }
  } catch (_) {
    setStatus("无法连接仓颉后端。", true);
  }
}

async function joinRoom() {
  const roomId = roomInput.value.trim();
  if (!roomId) {
    setStatus("请输入房间号。", true);
    return;
  }
  mode = "online";
  updateModeUi();
  resetLocalState();
  try {
    const data = await postJson(`/api/rooms/${roomId}/join`);
    if (data.ok) {
      online.roomId = data.roomId;
      online.player = data.player;
      applyServerState(data);
      startPolling();
      renderAll("已加入房间。");
    } else {
      setStatus(data.message || "加入房间失败。", true);
    }
  } catch (_) {
    setStatus("无法连接仓颉后端。", true);
  }
}

async function pollRoom() {
  if (!online.roomId) return;
  try {
    const data = await getJson(`/api/rooms/${online.roomId}`);
    if (data.ok) {
      applyServerState(data);
      renderAll();
    } else {
      setStatus(data.message || "房间同步失败。", true);
    }
  } catch (_) {
    setStatus("房间同步中断。", true);
  }
}

async function resetOnlineRoom() {
  if (!online.roomId) return;
  try {
    const data = await postJson(`/api/rooms/${online.roomId}/reset`);
    applyServerState(data);
    renderAll(data.message || "房间已重开。");
  } catch (_) {
    setStatus("无法重开房间。", true);
  }
}

function restart() {
  if (mode === "online" && online.roomId) {
    resetOnlineRoom();
    return;
  }
  resetLocalState();
  renderAll("新棋局已开始。");
}

function undo() {
  if (mode === "online" || history.length === 0 || busy) return;
  board = history.pop();
  turn = inferTurn();
  winner = findWinner();
  lastMove = { row: -1, col: -1 };
  renderAll("已悔棋。");
}

function switchMode(nextMode) {
  mode = nextMode;
  stopPolling();
  online = { roomId: "", player: EMPTY, polling: null, whiteJoined: false };
  resetLocalState();
  updateModeUi();
  renderAll();
}

async function copyRoomId() {
  if (!online.roomId) {
    setStatus("当前没有可复制的房间号。", true);
    return;
  }
  try {
    await navigator.clipboard.writeText(online.roomId);
    setStatus("房间号已复制。");
  } catch (_) {
    setStatus(`房间号：${online.roomId}`);
  }
}

boardEl.addEventListener("click", handleCellClick);
createRoomBtn.addEventListener("click", createRoom);
joinRoomBtn.addEventListener("click", joinRoom);
copyRoomBtn.addEventListener("click", copyRoomId);
restartBtn.addEventListener("click", restart);
gameOverRestartBtn.addEventListener("click", restart);
undoBtn.addEventListener("click", undo);
modeButtons.forEach((button) => {
  button.addEventListener("click", () => switchMode(button.dataset.mode));
});

updateModeUi();
renderAll();
