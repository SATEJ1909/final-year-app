import type { RedisClientType } from 'redis';
import dotenv from 'dotenv'
dotenv.config()
import { createClient } from 'redis';

// A self-invoking async function to initialize and connect the client.
// This pattern ensures we export a single, connected client instance.
const initializeRedisClient = async (): Promise<RedisClientType> => {
  const client: RedisClientType = createClient({
    // The Redis URL is now hardcoded for faster MVP setup.
    // This defaults to a standard local Redis installation.
    url: process.env.REDIS_URL as string,
  });

  client.on('error', (err : any) => console.error('Redis Client Error', err));

  try {
    await client.connect();
    console.log('Successfully connected to Redis.');
  } catch (err) {
    console.error('Could not connect to Redis:', err);
    // Exit the process if the connection fails, as it's a critical dependency.
    process.exit(1);
  }

  return client;
};

// We export the promise which resolves to the connected client.
// Any module importing this will await the connection.
const redisClient = await initializeRedisClient();

export default redisClient;

