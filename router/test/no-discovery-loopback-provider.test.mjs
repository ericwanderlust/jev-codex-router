import assert from "node:assert/strict";
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from "node:fs";
import os from "node:os";
import path from "node:path";
import test from "node:test";

const testRoot = mkdtempSync(path.join(os.tmpdir(), "codex-router-no-discovery-loopback-"));
const stateDir = path.join(testRoot, "state");
mkdirSync(stateDir, { recursive: true });
process.env.MODEL_ROUTER_STATE_DIR = stateDir;
process.env.CODEX_HOME = path.join(testRoot, "codex");
process.env.CODEX_ROUTER_NO_DISCOVERY = "1";

const writeState = (name, value) => {
  writeFileSync(path.join(stateDir, name), `${JSON.stringify(value)}\n`, {
    encoding: "utf8",
    mode: 0o600,
  });
};

writeState("generic-providers.json", {
  version: 1,
  providers: [
    {
      id: "jev",
      displayName: "Jev Router",
      baseUrl: "http://127.0.0.1:4319/v1",
      adapter: "openai-responses",
      headers: {},
      credentialRef: "cred_jev_loopback_001",
      allowPrivate: true,
      enabled: true,
    },
    {
      id: "remote",
      displayName: "Remote Provider",
      baseUrl: "https://api.example.com/v1",
      adapter: "openai-responses",
      headers: {},
      allowPrivate: false,
      enabled: true,
    },
  ],
});
writeState("user-models.json", {
  version: 1,
  models: [
    {
      slug: "jev/auto",
      gatewayModel: "jev-auto",
      compHash: "jev-auto-user-v1",
      upstreamModel: "auto",
      provider: "jev",
      listed: true,
      displayName: "Auto (Jev)",
      description: "Local test route",
      priority: 95,
      contextWindow: 258400,
      autoCompact: 219640,
      defaultEffort: "medium",
      reasoningLevels: ["low", "medium", "high", "xhigh", "max"].map((effort) => ({
        effort,
        description: "Test reasoning level",
      })),
      inputModalities: ["text", "image"],
    },
  ],
});
writeState("enabled-providers.json", { version: 1, providers: [] });
writeState("discovery-mode.json", { version: 1, discovery: "disabled" });

const { addGenericProviderCredentialReference } = await import(
  "../src/provider-credential-store.mjs"
);
const { writeGenericProviderCredential } = await import("../src/provider-credentials.mjs");
addGenericProviderCredentialReference({
  id: "cred_jev_loopback_001",
  providerId: "jev",
  label: "Jev local transport",
});
writeGenericProviderCredential("jev", "test-only-local-transport-key");

const { configuredProviderIds, selectedConfiguredListedModels } = await import(
  "../src/provider-selection.mjs"
);

test("no-discovery publishes the explicit loopback Jev model only", () => {
  assert.deepEqual(configuredProviderIds(), ["jev"]);
  assert.deepEqual(
    selectedConfiguredListedModels().map((model) => model.slug),
    ["jev/auto"],
  );
});

test.after(() => {
  delete process.env.MODEL_ROUTER_STATE_DIR;
  delete process.env.CODEX_HOME;
  delete process.env.CODEX_ROUTER_NO_DISCOVERY;
  rmSync(testRoot, { recursive: true, force: true });
});
