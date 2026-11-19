const allowedCodes = new Set([
  "40001", // Serialization failure
  "40P01", // Deadlock
  "42501", // Insufficient privilege
  "55P03", // Lock unavailable
  "57014", // Query canceled
  "P0001", // Raised exception, including the write budget
  "PGRST000", // Database connection error
  "PGRST001", // Database connection error
  "PGRST002", // Schema cache connection error
  "PGRST003", // Connection pool timeout
]);

// SDK error diagnostics can contain request URLs with token filters.
export function postgrestErrorCodeForLog(code: unknown): string {
  return typeof code === "string" && allowedCodes.has(code) ? code : "unknown";
}
