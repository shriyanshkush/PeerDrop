const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');

const app = express();
app.use(cors());

const server = http.createServer(app);
const io = new Server(server, {
  cors: { origin: '*' },
});

const roomOccupants = new Map();

function log(message, extra = {}) {
  console.log(`[${new Date().toISOString()}] ${message}`, extra);
}

function updateRoomOccupants(roomId) {
  const room = io.sockets.adapter.rooms.get(roomId);
  const count = room?.size ?? 0;

  if (count === 0) {
    roomOccupants.delete(roomId);
    return 0;
  }

  roomOccupants.set(roomId, count);
  return count;
}

io.on('connection', (socket) => {
  log('User connected.', { socketId: socket.id });

  socket.on('join-room', ({ roomId }) => {
    socket.join(roomId);
    const count = updateRoomOccupants(roomId);
    log('Socket joined room.', { socketId: socket.id, roomId, occupants: count });
    io.to(roomId).emit('room-members', { roomId, occupants: count });
  });

  socket.on('offer', (data) => {
    log('Relaying offer.', { socketId: socket.id, roomId: data.roomId });
    socket.to(data.roomId).emit('offer', data);
  });

  socket.on('answer', (data) => {
    log('Relaying answer.', { socketId: socket.id, roomId: data.roomId });
    socket.to(data.roomId).emit('answer', data);
  });

  socket.on('ice-candidate', (data) => {
    log('Relaying ICE candidate.', { socketId: socket.id, roomId: data.roomId });
    socket.to(data.roomId).emit('ice-candidate', data);
  });

  socket.on('disconnecting', () => {
    for (const roomId of socket.rooms) {
      if (roomId === socket.id) {
        continue;
      }

      const remaining = Math.max(updateRoomOccupants(roomId) - 1, 0);
      log('Socket leaving room.', { socketId: socket.id, roomId, occupantsAfterDisconnect: remaining });
      io.to(roomId).emit('room-members', { roomId, occupants: remaining });
    }
  });

  socket.on('disconnect', (reason) => {
    log('User disconnected.', { socketId: socket.id, reason });
  });
});

server.listen(3000, () => {
  log('Server running on port 3000.');
});
