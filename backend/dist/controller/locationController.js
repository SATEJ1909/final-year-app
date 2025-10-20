import { Server, Socket } from 'socket.io';
import redisClient from '../redisClient.js';
// --- Redis Keys ---
// Using constants prevents typos and makes the code easier to maintain.
const POLICE_GEO_KEY = 'police_locations'; // A Redis Geospatial set for police locations.
const USER_SOCKET_HASH_KEY = 'user_sockets'; // A Redis Hash mapping userId to their unique socket.id.
/**
 * Handles a new user connecting and identifying themselves.
 * @param socket The client's socket instance.
 * @param payload The data sent from the client (userId, role, location).
 */
export async function handleJoin(socket, payload) {
    const { userId, role, location } = payload;
    if (!userId || !role)
        return;
    console.log(`User joined: ${userId} with role ${role}`);
    // Map the user's ID to their unique socket ID for direct messaging later.
    await redisClient.hSet(USER_SOCKET_HASH_KEY, userId, socket.id);
    // If the user is a police officer, add them to the 'police' room and their location to Redis.
    if (role === 'police') {
        socket.join('police');
        if (location?.lat && location?.lng) {
            await redisClient.geoAdd(POLICE_GEO_KEY, {
                longitude: location.lng,
                latitude: location.lat,
                member: userId,
            });
            console.log(`[Redis] Added police officer ${userId} to geospatial index.`);
        }
    }
}
/**
 * Handles an ambulance's location update, broadcasting it and checking for proximity alerts.
 * @param io The main Socket.IO server instance.
 * @param payload The data from the ambulance (ambulanceId, lat, lng).
 */
export async function handleUpdateLocation(io, payload) {
    const { ambulanceId, lat, lng } = payload;
    if (!ambulanceId || !lat || !lng)
        return;
    console.log(`Location update from ${ambulanceId}: (${lat}, ${lng})`);
    // 1. Broadcast the new location to ALL clients in the 'police' room for general map updates.
    io.to('police').emit('ambulancePositionUpdate', { ambulanceId, lat, lng });
    // 2. Perform a geospatial search in Redis to find police within a 1km radius.
    try {
        const nearbyPolice = await redisClient.geoSearch(POLICE_GEO_KEY, { longitude: lng, latitude: lat }, { radius: 1, unit: 'km' });
        if (nearbyPolice.length > 0) {
            console.log(`Alert: Found nearby police: ${nearbyPolice.join(', ')}`);
            // 3. For each nearby officer, get their socket ID and send a targeted alert.
            for (const policeId of nearbyPolice) {
                const socketId = await redisClient.hGet(USER_SOCKET_HASH_KEY, policeId);
                if (socketId) {
                    io.to(socketId).emit('ambulanceProximityAlert', {
                        ambulanceId,
                        message: `Ambulance ${ambulanceId} is approaching your location!`,
                    });
                    console.log(`--> Sent proximity alert to ${policeId}`);
                }
            }
        }
    }
    catch (err) {
        console.error('Error during Redis GEOSEARCH:', err);
    }
}
/**
 * Handles cleanup when a user disconnects.
 * @param socket The client's socket instance that disconnected.
 */
export async function handleDisconnect(socket) {
    // To find out which user disconnected, we must do a reverse lookup.
    // We find the userId associated with the disconnected socket.id.
    const allUsers = await redisClient.hGetAll(USER_SOCKET_HASH_KEY);
    const userId = Object.keys(allUsers).find(key => allUsers[key] === socket.id);
    if (userId) {
        console.log(`User disconnected: ${userId}`);
        // Remove the user from our Redis data stores.
        await redisClient.hDel(USER_SOCKET_HASH_KEY, userId);
        await redisClient.zRem(POLICE_GEO_KEY, userId); // zRem removes from geo index
        console.log(`[Redis] Cleaned up data for ${userId}.`);
    }
}
//# sourceMappingURL=locationController.js.map