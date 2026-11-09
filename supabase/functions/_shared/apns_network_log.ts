/** Log fetch failures without the APNs URL, which includes the device token. */
export function apnsNetworkFailureLog(error: unknown): string {
  return error instanceof Error ? error.name : "Error";
}
