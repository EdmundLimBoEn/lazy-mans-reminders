import { assertEquals } from "jsr:@std/assert";
import { apnsNetworkFailureLog } from "./apns_network_log.ts";

Deno.test("APNs network logs keep the error name and drop the device URL", () => {
  const token = "a".repeat(64);
  const error = new TypeError(
    `error sending request for url (https://api.push.apple.com/3/device/${token}): client error (Connect)`,
  );
  const logged = apnsNetworkFailureLog(error);
  assertEquals(logged, "TypeError");
  assertEquals(logged.includes(token), false);
  assertEquals(logged.includes("apple.com"), false);
});

Deno.test("APNs network logs still name a non-Error throw", () => {
  assertEquals(apnsNetworkFailureLog("offline"), "Error");
});
