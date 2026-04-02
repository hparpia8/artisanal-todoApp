/**
 * Pure-logic module for todo CRUD — no MCP, no I/O side effects.
 * This is the testable core; index.ts wires it to MCP + filesystem.
 *
 * Storage: SQLite via better-sqlite3.
 * Schema:  todos(id, title, createdAt, completedAt, isCompleted, sortOrder)
 * Dates:   ISO 8601 TEXT, compatible with Swift's ISO8601DateFormatter.
 */

import * as fs from "fs";
import * as os from "os";
import * as path from "path";
import { randomUUID } from "crypto";
import Database from "better-sqlite3";

// ---------------------------------------------------------------------------
// Types — mirror the Swift TodoItem model
// ---------------------------------------------------------------------------

export interface TodoItem {
  id: string;
  title: string;
  createdAt: string; // ISO 8601
  completedAt: string | null;
  isCompleted: boolean;
}

// Row shape returned by better-sqlite3 (SQLite stores booleans as 0/1)
interface TodoRow {
  id: string;
  title: string;
  createdAt: string;
  completedAt: string | null;
  isCompleted: number;
  sortOrder: number;
}

// ---------------------------------------------------------------------------
// Path resolution — detects whether the app is running sandboxed
// ---------------------------------------------------------------------------

const SANDBOX_CONTAINER = path.join(
  os.homedir(),
  "Library",
  "Containers",
  "com.artisanal.todo",
  "Data"
);

const TODO_DIR = fs.existsSync(SANDBOX_CONTAINER)
  ? path.join(
      SANDBOX_CONTAINER,
      "Library",
      "Application Support",
      "ArtisanalTodo"
    )
  : path.join(os.homedir(), "Library", "Application Support", "ArtisanalTodo");

const TODO_PATH = path.join(TODO_DIR, "todos.db");

// ---------------------------------------------------------------------------
// Database helpers
// ---------------------------------------------------------------------------

const CREATE_TABLE_SQL = `
  CREATE TABLE IF NOT EXISTS todos (
    id          TEXT    NOT NULL PRIMARY KEY,
    title       TEXT    NOT NULL,
    createdAt   TEXT    NOT NULL,
    completedAt TEXT,
    isCompleted INTEGER NOT NULL DEFAULT 0,
    sortOrder   INTEGER NOT NULL DEFAULT 0
  )
`;

function openDb(dbPath: string): Database.Database {
  const dir = path.dirname(dbPath);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
  const db = new Database(dbPath);
  db.pragma("journal_mode = WAL");
  db.pragma("busy_timeout = 1000");
  db.exec(CREATE_TABLE_SQL);
  return db;
}

function rowToItem(row: TodoRow): TodoItem {
  return {
    id: row.id,
    title: row.title,
    createdAt: row.createdAt,
    completedAt: row.completedAt,
    isCompleted: row.isCompleted === 1,
  };
}

// ---------------------------------------------------------------------------
// Persistence — public API
// ---------------------------------------------------------------------------

export function readTodos(dbPath: string = TODO_PATH): TodoItem[] {
  try {
    const db = openDb(dbPath);
    const rows = db
      .prepare("SELECT * FROM todos ORDER BY sortOrder ASC")
      .all() as TodoRow[];
    db.close();
    return rows.map(rowToItem);
  } catch {
    return [];
  }
}

export function writeTodos(
  todos: TodoItem[],
  dbPath: string = TODO_PATH
): void {
  const db = openDb(dbPath);
  const deleteAll = db.prepare("DELETE FROM todos");
  const insert = db.prepare(`
    INSERT INTO todos (id, title, createdAt, completedAt, isCompleted, sortOrder)
    VALUES (@id, @title, @createdAt, @completedAt, @isCompleted, @sortOrder)
  `);
  db.transaction(() => {
    deleteAll.run();
    todos.forEach((item, i) =>
      insert.run({ ...item, isCompleted: item.isCompleted ? 1 : 0, sortOrder: i })
    );
  })();
  db.close();
}

// ---------------------------------------------------------------------------
// Lookup helpers — resolve a todo by number, title substring, or UUID
// ---------------------------------------------------------------------------

export type FindQuery = {
  id?: string;
  title?: string;
  number?: number;
};

export type FindSuccess = { item: TodoItem; index: number };
export type FindError = { error: string };
export type FindResult = FindSuccess | FindError;

export function findTodo(todos: TodoItem[], query: FindQuery): FindResult {
  if (query.number !== undefined) {
    const idx = query.number - 1; // 1-based → 0-based
    if (idx < 0 || idx >= todos.length) {
      return {
        error: `No todo at #${query.number}. Use list_todos to see current numbers.`,
      };
    }
    return { item: todos[idx], index: idx };
  }

  if (query.id) {
    const idx = todos.findIndex((t) => t.id === query.id);
    if (idx === -1) return { error: `No todo found with that id.` };
    return { item: todos[idx], index: idx };
  }

  if (query.title) {
    const lower = query.title.toLowerCase();
    const matches = todos
      .map((t, i) => ({ item: t, index: i }))
      .filter((e) => e.item.title.toLowerCase().includes(lower));

    if (matches.length === 0)
      return { error: `No todo matching "${query.title}".` };
    if (matches.length === 1) return matches[0];

    const list = matches
      .map((m) => `  ${m.index + 1}. ${m.item.title}`)
      .join("\n");
    return {
      error: `Multiple matches for "${query.title}":\n${list}\nPlease specify by number or a more specific title.`,
    };
  }

  return { error: "Provide a number, title, or id to identify the todo." };
}

// ---------------------------------------------------------------------------
// CRUD operations (pure data transforms — caller handles persistence)
// ---------------------------------------------------------------------------

export function createTodo(title: string): TodoItem {
  return {
    id: randomUUID(),
    title: title.trim(),
    createdAt: new Date().toISOString(),
    completedAt: null,
    isCompleted: false,
  };
}

export function completeTodo(
  todos: TodoItem[],
  query: FindQuery
): { todos: TodoItem[]; message: string; isError?: boolean } {
  const result = findTodo(todos, query);
  if ("error" in result) {
    return { todos, message: result.error, isError: true };
  }
  const { item, index } = result;
  if (item.isCompleted) {
    return { todos, message: `"${item.title}" is already completed.` };
  }
  const updated = [...todos];
  updated[index] = {
    ...item,
    isCompleted: true,
    completedAt: new Date().toISOString(),
  };
  return { todos: updated, message: `Completed: "${item.title}"` };
}

export function uncompleteTodo(
  todos: TodoItem[],
  query: FindQuery
): { todos: TodoItem[]; message: string; isError?: boolean } {
  const result = findTodo(todos, query);
  if ("error" in result) {
    return { todos, message: result.error, isError: true };
  }
  const { item, index } = result;
  if (!item.isCompleted) {
    return { todos, message: `"${item.title}" is not completed.` };
  }
  const updated = [...todos];
  updated[index] = { ...item, isCompleted: false, completedAt: null };
  return { todos: updated, message: `Marked incomplete: "${item.title}"` };
}

export function deleteTodo(
  todos: TodoItem[],
  query: FindQuery
): { todos: TodoItem[]; message: string; isError?: boolean } {
  const result = findTodo(todos, query);
  if ("error" in result) {
    return { todos, message: result.error, isError: true };
  }
  const removed = todos[result.index];
  const updated = todos.filter((_, i) => i !== result.index);
  return { todos: updated, message: `Deleted: "${removed.title}"` };
}

export function formatTodoList(todos: TodoItem[]): string {
  if (todos.length === 0) return "No todos found.";

  const hasPending = todos.some((t) => !t.isCompleted);
  const hasCompleted = todos.some((t) => t.isCompleted);
  const lines: string[] = [];

  if (hasPending) {
    lines.push("**Pending:**");
    for (const [i, t] of todos.entries()) {
      if (!t.isCompleted) lines.push(`${i + 1}. - [ ] ${t.title}`);
    }
  }
  if (hasCompleted) {
    if (lines.length > 0) lines.push("");
    lines.push("**Completed:**");
    for (const [i, t] of todos.entries()) {
      if (t.isCompleted) lines.push(`${i + 1}. - [x] ${t.title}`);
    }
  }

  return lines.join("\n");
}
