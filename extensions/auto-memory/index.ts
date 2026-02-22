/**
 * OpenClaw Auto-Memory Plugin
 *
 * Automatically extracts and updates long-term memory from conversations.
 * Listens to agent_end and after_compaction hooks, uses Claude to identify
 * important facts about the user, and writes them to categorized memory/*.md files.
 *
 * Memory categories:
 *   memory/preferences.md  - language, tools, style, communication preferences
 *   memory/work.md         - projects, tasks, technical context, goals
 *   memory/habits.md       - daily patterns, routines, typical approaches
 *   memory/decisions.md    - important choices, commitments, conclusions
 */

import Anthropic from "@anthropic-ai/sdk";
import fs from "node:fs/promises";
import path from "node:path";
import type { OpenClawPluginApi } from "openclaw/plugin-sdk";

// ============================================================================
// Constants
// ============================================================================

const PLUGIN_ID = "auto-memory";

const CATEGORIES = ["preferences", "work", "habits", "decisions"] as const;
type Category = (typeof CATEGORIES)[number];

const CATEGORY_FILES: Record<Category, string> = {
  preferences: "preferences.md",
  work: "work.md",
  habits: "habits.md",
  decisions: "decisions.md",
};

const CATEGORY_DESCRIPTIONS: Record<Category, string> = {
  preferences:
    "coding languages, tools, style choices, communication style, things the user likes or dislikes",
  work: "current projects, job context, technical stack, tasks in progress, goals",
  habits: "daily routines, patterns, how the user typically approaches problems or work",
  decisions:
    "important choices made, conclusions reached, commitments, agreements with the AI",
};

const DEFAULT_MODEL = "claude-haiku-4-5-20251001";
const DEFAULT_MIN_MESSAGES = 4;
const DEFAULT_COOLDOWN_MINUTES = 5;

// ============================================================================
// Types
// ============================================================================

type PluginConfig = {
  apiKey?: string;
  model?: string;
  minMessages?: number;
  cooldownMinutes?: number;
  enabled?: boolean;
};

type MemoryUpdate = {
  action: "add" | "update";
  text: string;
  old?: string;
};

type ExtractionResult = Partial<Record<Category, MemoryUpdate[]>>;

type SessionState = {
  lastExtractedAt: number;
  lastMessageCount: number;
};

// ============================================================================
// Message extraction
// ============================================================================

function extractMessagesFromArray(messages: unknown[]): Array<{ role: string; text: string }> {
  const result: Array<{ role: string; text: string }> = [];

  for (const msg of messages) {
    if (!msg || typeof msg !== "object") continue;
    const m = msg as Record<string, unknown>;
    const role = m.role;
    if (role !== "user" && role !== "assistant") continue;

    const content = m.content;
    let text = "";

    if (typeof content === "string") {
      text = content;
    } else if (Array.isArray(content)) {
      for (const block of content) {
        if (block && typeof block === "object" && "type" in block) {
          const b = block as Record<string, unknown>;
          if (b.type === "text" && typeof b.text === "string") {
            text += b.text + " ";
          }
        }
      }
    }

    const trimmed = text.trim();
    if (trimmed) {
      result.push({ role: String(role), text: trimmed });
    }
  }

  return result;
}

function formatConversation(messages: Array<{ role: string; text: string }>): string {
  return messages
    .map((m) => `[${m.role.toUpperCase()}]: ${m.text}`)
    .join("\n\n");
}

// ============================================================================
// Session JSONL parsing
// ============================================================================

async function readSessionMessages(
  sessionFile: string,
): Promise<Array<{ role: string; text: string }>> {
  try {
    const raw = await fs.readFile(sessionFile, "utf-8");
    const lines = raw.split("\n").filter((l) => l.trim());
    const allMessages: unknown[] = [];

    for (const line of lines) {
      try {
        const obj = JSON.parse(line);
        if (obj && typeof obj === "object" && "role" in obj) {
          allMessages.push(obj);
        }
      } catch {
        // Skip malformed lines
      }
    }

    return extractMessagesFromArray(allMessages);
  } catch {
    return [];
  }
}

// ============================================================================
// Memory file I/O
// ============================================================================

async function readMemoryFile(memoryDir: string, filename: string): Promise<string> {
  try {
    return await fs.readFile(path.join(memoryDir, filename), "utf-8");
  } catch {
    return "";
  }
}

async function writeMemoryFile(
  memoryDir: string,
  filename: string,
  content: string,
): Promise<void> {
  await fs.mkdir(memoryDir, { recursive: true });
  await fs.writeFile(path.join(memoryDir, filename), content, "utf-8");
}

async function readAllMemory(
  memoryDir: string,
): Promise<Record<Category, string>> {
  const result = {} as Record<Category, string>;
  await Promise.all(
    CATEGORIES.map(async (cat) => {
      result[cat] = await readMemoryFile(memoryDir, CATEGORY_FILES[cat]);
    }),
  );
  return result;
}

// ============================================================================
// Memory update application
// ============================================================================

function applyUpdatesToContent(existingContent: string, updates: MemoryUpdate[]): string {
  const lines = existingContent
    .split("\n")
    .filter((l) => l !== undefined) as string[];

  // Remove trailing empty lines
  while (lines.length > 0 && !lines[lines.length - 1]!.trim()) {
    lines.pop();
  }

  for (const update of updates) {
    if (!update.text?.trim()) continue;

    if (update.action === "add") {
      lines.push(`- ${update.text.trim()}`);
    } else if (update.action === "update" && update.old) {
      // Try to find the old entry (with or without leading dash)
      const oldNormalized = update.old.trim().replace(/^-\s*/, "");
      const idx = lines.findIndex((l) => {
        const normalized = l.trim().replace(/^-\s*/, "");
        return normalized === oldNormalized;
      });

      if (idx >= 0) {
        lines[idx] = `- ${update.text.trim()}`;
      } else {
        // Old entry not found - add as new
        lines.push(`- ${update.text.trim()}`);
      }
    }
  }

  return lines.join("\n") + (lines.length > 0 ? "\n" : "");
}

// ============================================================================
// Claude extraction
// ============================================================================

async function extractMemoryUpdates(
  client: Anthropic,
  model: string,
  conversationText: string,
  existingMemory: Record<Category, string>,
): Promise<ExtractionResult> {
  const existingSection = CATEGORIES.map((cat) => {
    const content = existingMemory[cat]?.trim() || "(empty)";
    return `### ${cat}\n${content}`;
  }).join("\n\n");

  const categoryDescriptions = CATEGORIES.map(
    (cat) => `- **${cat}**: ${CATEGORY_DESCRIPTIONS[cat]}`,
  ).join("\n");

  const prompt = `You are extracting persistent personal memory from a conversation to update long-term memory files.

## Existing Memory
${existingSection}

## Conversation
${conversationText}

## Task
Identify important, persistent facts about the USER (not the AI assistant) from this conversation.

Categories:
${categoryDescriptions}

Return ONLY a valid JSON object. No explanation, no markdown fences, just JSON:
{
  "preferences": [
    {"action": "add", "text": "concise fact about user preference"},
    {"action": "update", "old": "exact existing bullet text to replace (without leading dash)", "text": "improved version"}
  ],
  "work": [],
  "habits": [],
  "decisions": []
}

Rules:
- Only extract facts you are CONFIDENT about from THIS conversation
- "add" for genuinely new facts not already in memory
- "update" for correcting, expanding or replacing an existing entry ("old" must match an existing bullet exactly, without the leading dash)
- Each "text" entry: max 120 characters, plain statement (no leading dash)
- Omit categories with no updates, or use empty arrays
- If nothing meaningful was learned about the user, return {}
- Focus on the USER's actual statements, preferences, and context - not the AI's suggestions
- Ignore technical ephemera (specific file contents, one-off errors) unless they reveal persistent user context`;

  const response = await client.messages.create({
    model,
    max_tokens: 1024,
    messages: [{ role: "user", content: prompt }],
  });

  const responseText = response.content
    .filter((b) => b.type === "text")
    .map((b) => (b as { type: "text"; text: string }).text)
    .join("");

  // Extract JSON from response
  const jsonMatch = responseText.match(/\{[\s\S]*\}/);
  if (!jsonMatch) return {};

  try {
    return JSON.parse(jsonMatch[0]) as ExtractionResult;
  } catch {
    return {};
  }
}

// ============================================================================
// Core extraction pipeline
// ============================================================================

async function runExtraction(params: {
  client: Anthropic;
  model: string;
  workspaceDir: string;
  messages: Array<{ role: string; text: string }>;
  logger: OpenClawPluginApi["logger"];
  label: string;
}): Promise<void> {
  const { client, model, workspaceDir, messages, logger, label } = params;

  const userMessages = messages.filter((m) => m.role === "user");
  const conversationText = formatConversation(messages);

  if (!conversationText.trim()) return;

  logger.info(`${PLUGIN_ID}: extracting memory [${label}] (${userMessages.length} user messages)`);

  const memoryDir = path.join(workspaceDir, "memory");
  const existingMemory = await readAllMemory(memoryDir);

  const updates = await extractMemoryUpdates(client, model, conversationText, existingMemory);

  let totalUpdates = 0;
  for (const cat of CATEGORIES) {
    const catUpdates = updates[cat];
    if (!catUpdates || catUpdates.length === 0) continue;

    const existing = existingMemory[cat];
    const updated = applyUpdatesToContent(existing, catUpdates);

    if (updated !== existing) {
      await writeMemoryFile(memoryDir, CATEGORY_FILES[cat], updated);
      totalUpdates += catUpdates.length;
      logger.info(`${PLUGIN_ID}: updated memory/${CATEGORY_FILES[cat]} (+${catUpdates.length})`);
    }
  }

  if (totalUpdates === 0) {
    logger.info?.(`${PLUGIN_ID}: no new memory extracted [${label}]`);
  }
}

// ============================================================================
// Plugin definition
// ============================================================================

const autoMemoryPlugin = {
  id: PLUGIN_ID,
  name: "Auto Memory",
  description:
    "Automatically extracts and updates long-term memory from conversations into categorized memory files.",

  register(api: OpenClawPluginApi) {
    const pluginConfig = (api.pluginConfig ?? {}) as PluginConfig;

    if (pluginConfig.enabled === false) {
      api.logger.info(`${PLUGIN_ID}: disabled via config`);
      return;
    }

    const apiKey = pluginConfig.apiKey || process.env.ANTHROPIC_API_KEY;
    if (!apiKey) {
      api.logger.warn(
        `${PLUGIN_ID}: no API key found. Set ANTHROPIC_API_KEY or configure plugin.apiKey. Plugin disabled.`,
      );
      return;
    }

    const model = pluginConfig.model || DEFAULT_MODEL;
    const minMessages = pluginConfig.minMessages ?? DEFAULT_MIN_MESSAGES;
    const cooldownMs = (pluginConfig.cooldownMinutes ?? DEFAULT_COOLDOWN_MINUTES) * 60 * 1000;

    const client = new Anthropic({ apiKey });

    // Per-session extraction state (in-memory, resets on restart)
    const sessionState = new Map<string, SessionState>();

    function shouldExtract(sessionKey: string, messageCount: number): boolean {
      const state = sessionState.get(sessionKey);
      if (!state) return messageCount >= minMessages;

      const timeSinceLast = Date.now() - state.lastExtractedAt;
      const newMessagesSinceLast = messageCount - state.lastMessageCount;

      return timeSinceLast >= cooldownMs && newMessagesSinceLast >= 2;
    }

    function recordExtraction(sessionKey: string, messageCount: number): void {
      sessionState.set(sessionKey, {
        lastExtractedAt: Date.now(),
        lastMessageCount: messageCount,
      });
    }

    // ------------------------------------------------------------------
    // Hook: agent_end — extract after each conversation turn
    // ------------------------------------------------------------------
    api.on("agent_end", async (event, ctx) => {
      if (!event.success || !event.messages || event.messages.length === 0) return;

      const workspaceDir = ctx.workspaceDir;
      if (!workspaceDir) return;

      const sessionKey = ctx.sessionKey ?? ctx.sessionId ?? "default";
      const messageCount = event.messages.length;

      if (!shouldExtract(sessionKey, messageCount)) return;

      const messages = extractMessagesFromArray(event.messages);
      const userMessages = messages.filter((m) => m.role === "user");
      if (userMessages.length < Math.ceil(minMessages / 2)) return;

      recordExtraction(sessionKey, messageCount);

      try {
        await runExtraction({
          client,
          model,
          workspaceDir,
          messages,
          logger: api.logger,
          label: "agent_end",
        });
      } catch (err) {
        api.logger.warn(`${PLUGIN_ID}: extraction failed (agent_end): ${String(err)}`);
      }
    });

    // ------------------------------------------------------------------
    // Hook: after_compaction — extract from session file before details are lost
    // ------------------------------------------------------------------
    api.on("after_compaction", async (event, ctx) => {
      const sessionFile = event.sessionFile;
      const workspaceDir = ctx.workspaceDir;

      if (!sessionFile || !workspaceDir) return;

      try {
        const messages = await readSessionMessages(sessionFile);
        const userMessages = messages.filter((m) => m.role === "user");
        if (userMessages.length < Math.ceil(minMessages / 2)) return;

        await runExtraction({
          client,
          model,
          workspaceDir,
          messages,
          logger: api.logger,
          label: "compaction",
        });

        // Reset cooldown so agent_end doesn't re-extract the same content immediately
        const sessionKey = ctx.sessionKey ?? ctx.sessionId ?? "default";
        recordExtraction(sessionKey, event.messageCount);
      } catch (err) {
        api.logger.warn(`${PLUGIN_ID}: extraction failed (after_compaction): ${String(err)}`);
      }
    });

    // ------------------------------------------------------------------
    // Hook: before_reset — extract before /new or /reset clears the session
    // ------------------------------------------------------------------
    api.on("before_reset", async (event, ctx) => {
      const workspaceDir = ctx.workspaceDir;
      if (!workspaceDir) return;

      // Try to get messages from the event or session file
      let messages: Array<{ role: string; text: string }> = [];

      if (event.messages && event.messages.length > 0) {
        messages = extractMessagesFromArray(event.messages);
      } else if (event.sessionFile) {
        messages = await readSessionMessages(event.sessionFile);
      }

      const userMessages = messages.filter((m) => m.role === "user");
      if (userMessages.length < Math.ceil(minMessages / 2)) return;

      try {
        await runExtraction({
          client,
          model,
          workspaceDir,
          messages,
          logger: api.logger,
          label: "before_reset",
        });
      } catch (err) {
        api.logger.warn(`${PLUGIN_ID}: extraction failed (before_reset): ${String(err)}`);
      }
    });

    api.registerService({
      id: PLUGIN_ID,
      start: () => {
        api.logger.info(
          `${PLUGIN_ID}: started (model: ${model}, minMessages: ${minMessages}, cooldown: ${cooldownMs / 60000}m)`,
        );
      },
    });
  },
};

export default autoMemoryPlugin;
