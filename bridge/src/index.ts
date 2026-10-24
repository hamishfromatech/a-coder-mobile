// Barrel export for the serve bridge package
export { runServe, startServe, parseArgs, DEFAULT_TOKEN_FILE } from './serve/serve-command.js'
export type { CliFlags, ServeHandle } from './serve/serve-command.js'
export { isEADDRINUSE } from './serve/net-utils.js'
export { serializeBridgeFrame, parseBridgeFrame } from './serve/control-frames.js'
export type { BridgeEvent } from './serve/control-frames.js'
export {
  generateToken, loadOrPersistToken, rotateToken, isValidToken,
  buildQrPayload, parseQrPayload, chunkToken, reassembleToken, machineIdFor,
} from './serve/pairing.js'
export type { QrPayload } from './serve/pairing.js'
export { createAnnounce, createDiscovery } from './serve/announce.js'
export type { AnnounceHandle, AnnounceOptions, DiscoveryHandle, DiscoveredService } from './serve/announce.js'
export { WsServer, RateLimiter } from './serve/ws-server.js'
export type { AuthenticatedClient, WsServerOptions, MessageHandler, CloseHandler } from './serve/ws-server.js'
export { EnginePump } from './serve/engine-pump.js'
export type { EnginePumpOptions } from './serve/engine-pump.js'
export { splitLines, parseLine, serializeLine, LineAccumulator } from './serve/wire.js'