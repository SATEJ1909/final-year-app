import express from 'express';
import mongoose from 'mongoose';
import http from 'http';
import { Server } from 'socket.io';
import jwt from 'jsonwebtoken';
import userRouter from './routes/routes.js';
import { handleJoin, handleUpdateLocation, handleDisconnect } from './controller/locationController.js';
const app = express();
const JWT_SECRET = process.env.JWT_SECRET || 'secret';
app.use(express.json());
app.use("/api/v1/user", userRouter);
async function main() {
    await mongoose.connect("mongodb://localhost:27017/ats");
    const server = http.createServer(app);
    // Create Socket.IO server attached to our HTTP server.
    const io = new Server(server, {
        cors: {
            origin: '*',
            methods: ['GET', 'POST']
        }
    });
    // Authenticate socket connections using a provided JWT token in the query.
    io.use((socket, next) => {
        try {
            const token = socket.handshake.auth?.token || socket.handshake.query?.token;
            if (!token)
                return next(); // Allow unauthenticated sockets for now.
            const payload = jwt.verify(token, JWT_SECRET);
            // Attach user info to socket for later use.
            socket.userId = payload.id;
            socket.role = payload.role;
            return next();
        }
        catch (err) {
            console.warn('Socket authentication failed:', err);
            return next();
        }
    });
    io.on('connection', (socket) => {
        console.log('New socket connected', socket.id);
        // Listen for 'join' events from clients.
        socket.on('join', async (payload) => {
            await handleJoin(socket, payload);
        });
        // Update location events from ambulances/drivers.
        socket.on('updateLocation', async (payload) => {
            await handleUpdateLocation(io, payload);
        });
        socket.on('disconnect', async () => {
            await handleDisconnect(socket);
        });
    });
    server.listen(5000, '0.0.0.0', () => {
        console.log('Server running on http://0.0.0.0:5000');
    });
}
main();
//# sourceMappingURL=index.js.map