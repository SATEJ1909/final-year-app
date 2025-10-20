import { Server, Socket } from 'socket.io';
interface JoinPayload {
    userId: string;
    role: 'police' | 'driver';
    location?: {
        lat: number;
        lng: number;
    };
}
interface LocationUpdatePayload {
    ambulanceId: string;
    lat: number;
    lng: number;
}
/**
 * Handles a new user connecting and identifying themselves.
 * @param socket The client's socket instance.
 * @param payload The data sent from the client (userId, role, location).
 */
export declare function handleJoin(socket: Socket, payload: JoinPayload): Promise<void>;
/**
 * Handles an ambulance's location update, broadcasting it and checking for proximity alerts.
 * @param io The main Socket.IO server instance.
 * @param payload The data from the ambulance (ambulanceId, lat, lng).
 */
export declare function handleUpdateLocation(io: Server, payload: LocationUpdatePayload): Promise<void>;
/**
 * Handles cleanup when a user disconnects.
 * @param socket The client's socket instance that disconnected.
 */
export declare function handleDisconnect(socket: Socket): Promise<void>;
export {};
//# sourceMappingURL=locationController.d.ts.map