import assert from "node:assert/strict";
import { Readable, Writable } from "node:stream";
import { pipeline } from "node:stream/promises";
import test from "node:test";

import { flattenNamespaceTools, NamespaceToolCallTransform } from "../src/namespace-relay.mjs";
import { EmptyCompletionGuard, EmptyCompletionTerminalGuard } from "../src/empty-completion-guard.mjs";

for (const shape of ["lifecycle", "item-done", "terminal-only"]) {
  test(`restored client tool search survives the empty guard: ${shape}`, async () => {
    const { namespaces } = flattenNamespaceTools([{
      type: "tool_search", execution: "client",
      parameters: {
        type: "object", properties: { query: { type: "string" } },
        required: ["query"], additionalProperties: false,
      },
    }]);
    const item = {
      type: "function_call", id: "fc_search_fixture", call_id: "search-fixture",
      name: "tool_search", arguments: '{"query":"calendar"}',
    };
    const events = [];
    if (shape === "lifecycle") events.push(
      { type: "response.output_item.added", item: { ...item, arguments: "" } },
      { type: "response.function_call_arguments.delta", item_id: item.id,
        call_id: item.call_id, delta: item.arguments },
      { type: "response.function_call_arguments.done", item_id: item.id,
        call_id: item.call_id, arguments: item.arguments },
    );
    if (shape !== "terminal-only") events.push({ type: "response.output_item.done", item });
    events.push({ type: "response.completed", response: {
      id: "resp_fixture", status: "completed", output: [item],
    } });
    const contentType = "text/event-stream";
    const guard = new EmptyCompletionGuard(contentType);
    let output = "";
    await pipeline(
      Readable.from(events.map(event => `event: ${event.type}\ndata: ${JSON.stringify(event)}\n\n`)),
      new NamespaceToolCallTransform(namespaces, contentType),
      guard,
      new EmptyCompletionTerminalGuard(guard, contentType),
      new Writable({ write(chunk, _encoding, done) { output += chunk.toString(); done(); } }),
    );
    assert.equal(guard.isEmpty(), false);
    assert.equal(guard.hasContent(), true);
    assert.equal(guard.suppressedPrologue(), false);
    const parsed = output.split(/\r?\n/).filter(line => line.startsWith("data:"))
      .map(line => JSON.parse(line.slice(5)));
    const completed = parsed.filter(event => event.type === "response.completed");
    assert.equal(completed.length, 1);
    const expected = {
      type: "tool_search_call", id: item.id, call_id: item.call_id,
      execution: "client", arguments: { query: "calendar" },
    };
    assert.deepEqual(completed[0].response.output, [expected]);
    const done = parsed.filter(event => event.type === "response.output_item.done");
    assert.equal(done.length, shape === "terminal-only" ? 0 : 1);
    if (done.length) assert.deepEqual(done[0].item, expected);
    assert.doesNotMatch(output, /response\.function_call_arguments/);
  });
}

for (const type of ["web_search_call", "future_tool_call", "reasoning", "message"]) {
  test(`terminal-only classification preserves native or unknown tools: ${type}`, async () => {
    const item = { type, id: "item_fixture", content: [] };
    const event = { type: "response.completed", response: { output: [item] } };
    const input = `event: response.completed\ndata: ${JSON.stringify(event)}\n\n`;
    const guard = new EmptyCompletionGuard("text/event-stream");
    let output = "";
    await pipeline(Readable.from([input]), guard,
      new EmptyCompletionTerminalGuard(guard, "text/event-stream"),
      new Writable({ write(chunk, _encoding, done) { output += chunk; done(); } }));
    const empty = type === "reasoning" || type === "message";
    assert.equal(guard.isEmpty(), empty);
    assert.equal(output, empty ? "" : input);
  });
}
