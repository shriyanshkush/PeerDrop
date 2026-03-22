const express = require("express");
const http = require("http");
const { Server } = require("socket.io");
const cors = require("cors");

const app = express();
app.use(cors());

const server = http.createServer(app);

const io = new Server(server, {
  cors: { origin: "*" }
});

io.on("connection", (socket) => {
  console.log("User connected:", socket.id);

  socket.on("join-room", ({ roomId }) => {
    socket.join(roomId);
    console.log(`${socket.id} joined ${roomId}`);
  });

  // 🔥 OFFER
  socket.on("offer", (data) => {
    socket.to(data.roomId).emit("offer", data);
  });

  // 🔥 ANSWER
  socket.on("answer", (data) => {
    socket.to(data.roomId).emit("answer", data);
  });

  // 🔥 ICE
  socket.on("ice-candidate", (data) => {
    socket.to(data.roomId).emit("ice-candidate", data);
  });

  socket.on("disconnect", () => {
    console.log("Disconnected:", socket.id);
  });
});

server.listen(3000, () => {
  console.log("🚀 Server running on 3000");
});