/**
 * Pure-logic module for todo CRUD — no MCP, no I/O side effects.
 * This is the testable core; index.ts wires it to MCP + filesystem.
 */

import * as fs from "fs";
import * as os from "os";
import * as path from "path";
import { randomUUID } from "crypto";

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

// ---------------------------------------------------------------------------
// Persistence helpers
// ---------------------------------------------------------------------------

const TODO_DIR = path.join(
  os.homedir(),
  "Library",
  "Application Support",
  "ArtisanalTodo"
);
const TODO_PATH = path.join(TODO_DIR, "todos.json");

export function getStorePath(): string {
  return TODO_PATH;
}

export function readTodos(filePath: string = TODO_PATH): TodoItem[] {
  try {
    const data = fs.readFileSync(filePath, "utf-8");
    return JSON.parse(data) as TodoItem[];
  } catch {
    return [];
  }
}

export function writeTodos(
  todos: TodoItem[],
  filePath: string = TODO_PATH
): void {
  const dir = path.dirname(filePath);
  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }
  fs.writeFileSync(filePath, JSON.stringify(todos, null, 2), "utf-8");
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

  const pending = todos.filter((t) => !t.isCompleted);
  const completed = todos.filter((t) => t.isCompleted);
  const lines: string[] = [];

  if (pending.length > 0) {
    lines.push("**Pending:**");
    for (const t of pending) {
      const num = todos.indexOf(t) + 1;
      lines.push(`${num}. - [ ] ${t.title}`);
    }
  }
  if (completed.length > 0) {
    if (lines.length > 0) lines.push("");
    lines.push("**Completed:**");
    for (const t of completed) {
      const num = todos.indexOf(t) + 1;
      lines.push(`${num}. - [x] ${t.title}`);
    }
  }

  return lines.join("\n");
}
