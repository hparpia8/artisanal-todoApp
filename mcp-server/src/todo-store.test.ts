import { describe, it, expect, beforeEach, afterEach } from "vitest";
import * as fs from "fs";
import * as os from "os";
import * as path from "path";
import {
  TodoItem,
  readTodos,
  writeTodos,
  findTodo,
  createTodo,
  completeTodo,
  deleteTodo,
  formatTodoList,
} from "./todo-store.js";

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

let tmpDir: string;
let tmpFile: string;

function makeTodo(overrides: Partial<TodoItem> = {}): TodoItem {
  return {
    id: overrides.id ?? "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee",
    title: overrides.title ?? "Buy milk",
    createdAt: overrides.createdAt ?? "2026-03-26T10:00:00.000Z",
    completedAt: overrides.completedAt ?? null,
    isCompleted: overrides.isCompleted ?? false,
  };
}

function sampleList(): TodoItem[] {
  return [
    makeTodo({ id: "id-1", title: "Buy milk" }),
    makeTodo({ id: "id-2", title: "Buy eggs" }),
    makeTodo({
      id: "id-3",
      title: "Walk the dog",
      isCompleted: true,
      completedAt: "2026-03-25T18:00:00.000Z",
    }),
  ];
}

beforeEach(() => {
  tmpDir = fs.mkdtempSync(path.join(os.tmpdir(), "todo-test-"));
  tmpFile = path.join(tmpDir, "todos.json");
});

afterEach(() => {
  fs.rmSync(tmpDir, { recursive: true, force: true });
});

// ---------------------------------------------------------------------------
// Persistence: readTodos / writeTodos
// ---------------------------------------------------------------------------

describe("readTodos", () => {
  it("returns empty array when file does not exist", () => {
    expect(readTodos(tmpFile)).toEqual([]);
  });

  it("returns empty array when file contains invalid JSON", () => {
    fs.writeFileSync(tmpFile, "not-json", "utf-8");
    expect(readTodos(tmpFile)).toEqual([]);
  });

  it("reads a valid todo list", () => {
    const todos = [makeTodo()];
    fs.writeFileSync(tmpFile, JSON.stringify(todos), "utf-8");
    expect(readTodos(tmpFile)).toEqual(todos);
  });
});

describe("writeTodos", () => {
  it("creates directories if needed", () => {
    const nested = path.join(tmpDir, "a", "b", "todos.json");
    writeTodos([makeTodo()], nested);
    expect(fs.existsSync(nested)).toBe(true);
  });

  it("round-trips with readTodos", () => {
    const todos = sampleList();
    writeTodos(todos, tmpFile);
    expect(readTodos(tmpFile)).toEqual(todos);
  });
});

// ---------------------------------------------------------------------------
// findTodo
// ---------------------------------------------------------------------------

describe("findTodo", () => {
  const todos = sampleList();

  describe("by number", () => {
    it("finds by 1-based position", () => {
      const result = findTodo(todos, { number: 2 });
      expect("item" in result && result.item.title).toBe("Buy eggs");
      expect("index" in result && result.index).toBe(1);
    });

    it("returns error for out-of-range number", () => {
      const result = findTodo(todos, { number: 99 });
      expect("error" in result).toBe(true);
    });

    it("returns error for number 0", () => {
      const result = findTodo(todos, { number: 0 });
      expect("error" in result).toBe(true);
    });
  });

  describe("by id", () => {
    it("finds by exact UUID", () => {
      const result = findTodo(todos, { id: "id-2" });
      expect("item" in result && result.item.title).toBe("Buy eggs");
    });

    it("returns error for unknown UUID", () => {
      const result = findTodo(todos, { id: "nonexistent" });
      expect("error" in result).toBe(true);
    });
  });

  describe("by title", () => {
    it("finds by case-insensitive substring", () => {
      const result = findTodo(todos, { title: "walk" });
      expect("item" in result && result.item.title).toBe("Walk the dog");
    });

    it("returns error when no match", () => {
      const result = findTodo(todos, { title: "zzz" });
      expect("error" in result).toBe(true);
    });

    it("returns error when multiple matches with disambiguation list", () => {
      const result = findTodo(todos, { title: "Buy" });
      expect("error" in result).toBe(true);
      if ("error" in result) {
        expect(result.error).toContain("Multiple matches");
        expect(result.error).toContain("Buy milk");
        expect(result.error).toContain("Buy eggs");
      }
    });
  });

  it("returns error when no query fields provided", () => {
    const result = findTodo(todos, {});
    expect("error" in result).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// createTodo
// ---------------------------------------------------------------------------

describe("createTodo", () => {
  it("creates a pending item with trimmed title", () => {
    const item = createTodo("  Fix login bug  ");
    expect(item.title).toBe("Fix login bug");
    expect(item.isCompleted).toBe(false);
    expect(item.completedAt).toBeNull();
    expect(item.id).toBeTruthy();
    expect(item.createdAt).toBeTruthy();
  });
});

// ---------------------------------------------------------------------------
// completeTodo
// ---------------------------------------------------------------------------

describe("completeTodo", () => {
  it("marks a pending item as completed", () => {
    const todos = sampleList();
    const result = completeTodo(todos, { number: 1 });
    expect(result.isError).toBeUndefined();
    expect(result.message).toContain("Completed");
    expect(result.todos[0].isCompleted).toBe(true);
    expect(result.todos[0].completedAt).toBeTruthy();
  });

  it("returns message if already completed", () => {
    const todos = sampleList();
    const result = completeTodo(todos, { number: 3 }); // "Walk the dog" is already done
    expect(result.message).toContain("already completed");
    expect(result.isError).toBeUndefined();
  });

  it("returns error for invalid query", () => {
    const result = completeTodo(sampleList(), { title: "zzz" });
    expect(result.isError).toBe(true);
  });

  it("does not mutate the original array", () => {
    const todos = sampleList();
    const original = JSON.parse(JSON.stringify(todos));
    completeTodo(todos, { number: 1 });
    expect(todos).toEqual(original);
  });
});

// ---------------------------------------------------------------------------
// deleteTodo
// ---------------------------------------------------------------------------

describe("deleteTodo", () => {
  it("removes the item and returns its title", () => {
    const todos = sampleList();
    const result = deleteTodo(todos, { number: 2 });
    expect(result.isError).toBeUndefined();
    expect(result.message).toContain("Buy eggs");
    expect(result.todos).toHaveLength(2);
    expect(result.todos.find((t) => t.title === "Buy eggs")).toBeUndefined();
  });

  it("returns error for invalid query", () => {
    const result = deleteTodo(sampleList(), { number: 99 });
    expect(result.isError).toBe(true);
  });
});

// ---------------------------------------------------------------------------
// formatTodoList
// ---------------------------------------------------------------------------

describe("formatTodoList", () => {
  it('returns "No todos found." for empty list', () => {
    expect(formatTodoList([])).toBe("No todos found.");
  });

  it("shows numbered pending and completed sections", () => {
    const output = formatTodoList(sampleList());
    expect(output).toContain("**Pending:**");
    expect(output).toContain("1. - [ ] Buy milk");
    expect(output).toContain("2. - [ ] Buy eggs");
    expect(output).toContain("**Completed:**");
    expect(output).toContain("3. - [x] Walk the dog");
  });

  it("omits completed section when all pending", () => {
    const todos = [makeTodo({ title: "Task A" })];
    const output = formatTodoList(todos);
    expect(output).toContain("**Pending:**");
    expect(output).not.toContain("**Completed:**");
  });

  it("omits pending section when all completed", () => {
    const todos = [makeTodo({ title: "Done", isCompleted: true, completedAt: "2026-03-26T10:00:00Z" })];
    const output = formatTodoList(todos);
    expect(output).not.toContain("**Pending:**");
    expect(output).toContain("**Completed:**");
  });
});
