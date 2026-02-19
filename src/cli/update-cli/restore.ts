import fs from "node:fs/promises";
import path from "node:path";
import { confirm, isCancel } from "@clack/prompts";
import { resolveConfigPath } from "../../config/paths.js";
import { defaultRuntime } from "../../runtime.js";
import { stylePromptMessage } from "../../terminal/prompt-style.js";
import { theme } from "../../terminal/theme.js";

export type UpdateRestoreOptions = {
  list?: boolean;
  latest?: boolean;
  json?: boolean;
};

const CONFIG_BACKUP_PREFIX = "openclaw.backup-";

async function resolveBackupDir(): Promise<string | null> {
  const configPath = resolveConfigPath();
  if (!configPath) {
    return null;
  }
  return path.dirname(configPath);
}

async function listBackups(dir: string): Promise<string[]> {
  let entries: string[];
  try {
    entries = await fs.readdir(dir);
  } catch {
    return [];
  }
  return entries
    .filter((e) => e.startsWith(CONFIG_BACKUP_PREFIX) && e.endsWith(".json"))
    .sort()
    .reverse(); // newest first
}

function formatBackupLabel(filename: string): string {
  // openclaw.backup-2026-02-19T12-00-00.json → "2026-02-19 12:00:00"
  const raw = filename.replace(CONFIG_BACKUP_PREFIX, "").replace(".json", "");
  const readable = raw.replace(/T/, " ").replace(/-(\d{2})-(\d{2})$/, ":$1:$2");
  return readable;
}

export async function updateRestoreCommand(opts: UpdateRestoreOptions): Promise<void> {
  const dir = await resolveBackupDir();
  if (!dir) {
    if (opts.json) {
      defaultRuntime.log(JSON.stringify({ error: "No config path resolved." }));
    } else {
      defaultRuntime.error("No config file path could be resolved.");
    }
    defaultRuntime.exit(1);
    return;
  }

  const backups = await listBackups(dir);

  if (opts.list) {
    if (opts.json) {
      defaultRuntime.log(
        JSON.stringify(
          { dir, backups: backups.map((f) => ({ file: f, label: formatBackupLabel(f) })) },
          null,
          2,
        ),
      );
    } else if (backups.length === 0) {
      defaultRuntime.log(theme.muted("No config backups found."));
    } else {
      defaultRuntime.log(theme.heading("Available config backups"));
      defaultRuntime.log("");
      for (const f of backups) {
        defaultRuntime.log(`  ${theme.command(f)}  ${theme.muted(formatBackupLabel(f))}`);
      }
      defaultRuntime.log("");
      defaultRuntime.log(
        theme.muted(`Restore with: openclaw update restore --latest  (or specify a file name)`),
      );
    }
    return;
  }

  if (backups.length === 0) {
    if (opts.json) {
      defaultRuntime.log(JSON.stringify({ error: "No backups available." }));
    } else {
      defaultRuntime.log(theme.warn("No config backups found. Run openclaw update to create one."));
    }
    defaultRuntime.exit(0);
    return;
  }

  const target = backups[0]; // newest backup
  const backupPath = path.join(dir, target);
  const configPath = resolveConfigPath()!;

  if (!opts.json) {
    defaultRuntime.log(theme.heading("Restore config backup"));
    defaultRuntime.log("");
    defaultRuntime.log(`  Backup : ${theme.command(target)}  ${theme.muted(formatBackupLabel(target))}`);
    defaultRuntime.log(`  Target : ${theme.muted(configPath)}`);
    defaultRuntime.log("");
  }

  if (!opts.latest) {
    if (!process.stdin.isTTY || opts.json) {
      defaultRuntime.error(
        "Confirmation required. Re-run in a TTY or use --latest to skip the prompt.",
      );
      defaultRuntime.exit(1);
      return;
    }
    const ok = await confirm({
      message: stylePromptMessage(`Overwrite openclaw.json with backup from ${formatBackupLabel(target)}?`),
      initialValue: false,
    });
    if (isCancel(ok) || !ok) {
      defaultRuntime.log(theme.muted("Restore cancelled."));
      defaultRuntime.exit(0);
      return;
    }
  }

  // Snapshot current config before overwriting (so restore itself is reversible)
  try {
    const ts = new Date().toISOString().replace(/[:.]/g, "-").slice(0, 19);
    const preRestorePath = path.join(dir, `${CONFIG_BACKUP_PREFIX}${ts}.json`);
    await fs.copyFile(configPath, preRestorePath);
  } catch {
    // Non-fatal: proceed even if pre-restore snapshot fails
  }

  try {
    await fs.copyFile(backupPath, configPath);
  } catch (err) {
    if (opts.json) {
      defaultRuntime.log(JSON.stringify({ error: String(err) }));
    } else {
      defaultRuntime.error(`Restore failed: ${String(err)}`);
    }
    defaultRuntime.exit(1);
    return;
  }

  if (opts.json) {
    defaultRuntime.log(JSON.stringify({ restored: target, configPath }));
  } else {
    defaultRuntime.log(theme.success(`Config restored from ${target}.`));
    defaultRuntime.log(
      theme.muted("Run openclaw doctor to validate, then openclaw gateway restart to apply."),
    );
  }
}
