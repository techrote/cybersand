#!/usr/bin/env node
import { mkdirSync, writeFileSync } from "node:fs";
import { dirname, resolve } from "node:path";

const values = new Map();
for (let index = 2; index < process.argv.length; index += 2) {
  values.set(process.argv[index], process.argv[index + 1]);
}
const port = Number(values.get("--port"));
const url = values.get("--url");
const output = resolve(values.get("--output"));
const screenshot = resolve(values.get("--screenshot"));
const elementId = values.get("--element-id") ?? "cybersand-water-result";
const timeoutMs = Number(values.get("--timeout-ms") ?? "180000");
if (!port || !url || !output || !screenshot) {
  throw new Error("usage: --port N --url URL --output FILE --screenshot FILE [--timeout-ms N]");
}

const delay = (milliseconds) => new Promise((resolveDelay) => setTimeout(resolveDelay, milliseconds));
let page;
for (let attempt = 0; attempt < 80; attempt += 1) {
  try {
    const pages = await fetch("http://127.0.0.1:" + port + "/json/list").then((response) => response.json());
    page = pages.find((candidate) => candidate.type === "page");
    if (page) break;
  } catch {
    // Chrome may still be opening its debugging endpoint.
  }
  await delay(250);
}
if (!page) throw new Error("Chrome debugging page did not become available");

const socket = new WebSocket(page.webSocketDebuggerUrl);
await new Promise((resolveOpen, rejectOpen) => {
  socket.addEventListener("open", resolveOpen, { once: true });
  socket.addEventListener("error", rejectOpen, { once: true });
});
let nextId = 1;
const pending = new Map();
socket.addEventListener("message", (event) => {
  const message = JSON.parse(event.data);
  if (!message.id || !pending.has(message.id)) return;
  const { resolveCommand, rejectCommand } = pending.get(message.id);
  pending.delete(message.id);
  if (message.error) rejectCommand(new Error(JSON.stringify(message.error)));
  else resolveCommand(message.result);
});
const command = (method, params = {}) => new Promise((resolveCommand, rejectCommand) => {
  const id = nextId++;
  pending.set(id, { resolveCommand, rejectCommand });
  socket.send(JSON.stringify({ id, method, params }));
});

await command("Page.enable");
await command("Runtime.enable");
await command("Page.navigate", { url });
const deadline = Date.now() + timeoutMs;
let text = "";
while (Date.now() < deadline) {
  try {
    const evaluated = await command("Runtime.evaluate", {
      expression: "document.getElementById(" + JSON.stringify(elementId) + ")?.textContent ?? ''",
      returnByValue: true,
    });
    text = evaluated.result?.value ?? "";
    if (text) break;
  } catch {
    // A navigation can replace the execution context while Godot starts.
  }
  await delay(250);
}
if (!text) throw new Error("Browser probe " + elementId + " timed out after " + timeoutMs + " ms");
const browser = await command("Runtime.evaluate", {
  expression: "({userAgent:navigator.userAgent,isolated:crossOriginIsolated})",
  returnByValue: true,
});
const captured = await command("Page.captureScreenshot", { format: "png", fromSurface: true });
mkdirSync(dirname(output), { recursive: true });
mkdirSync(dirname(screenshot), { recursive: true });
const envelope = {
  userAgent: browser.result.value.userAgent,
  isolated: browser.result.value.isolated,
  result: JSON.parse(text),
};
writeFileSync(output, JSON.stringify(envelope, null, 2) + "\n");
writeFileSync(screenshot, Buffer.from(captured.data, "base64"));
console.log(JSON.stringify(envelope));
await command("Browser.close");
