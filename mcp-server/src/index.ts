import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { execSync } from "child_process";
import {
  TodoItem,
  readTodos,
  writeTodos,
  createTodo,
  completeTodo,
  uncompleteTodo,
  deleteTodo,
  formatTodoList,
} from "./todo-store.js";

function saveAndNotify(todos: TodoItem[]): void {
  writeTodos(todos);
  try {
    execSync("open artisanaltodo://refresh", { stdio: "ignore" });
  } catch {
    // App is not running — file watcher will catch it on next launch
  }
}

// ---------------------------------------------------------------------------
// MCP server
// ---------------------------------------------------------------------------

const server = new McpServer({
  name: "artisanal-todo",
  version: "1.0.0",
});

const todoQuerySchema = {
  number: z
    .coerce.number()
    .int()
    .positive()
    .optional()
    .describe("Position number from list_todos (e.g. 1, 2, 3)"),
  title: z
    .string()
    .optional()
    .describe("Case-insensitive substring to match against todo titles"),
  id: z
    .string()
    .uuid()
    .optional()
    .describe("UUID — used internally, never shown to the user"),
};

// --- add_todo ---------------------------------------------------------------

server.tool(
  "add_todo",
  "Add a new pending item to the Artisanal Todo app",
  { title: z.string().min(1).max(500).describe("The task to add") },
  async ({ title }) => {
    const todos = readTodos();
    const item = createTodo(title);
    todos.push(item);
    saveAndNotify(todos);
    return {
      content: [{ type: "text", text: `Added: "${item.title}"` }],
    };
  }
);

// --- list_todos -------------------------------------------------------------

server.tool(
  "list_todos",
  "Return all todo items — both pending and completed. Items are numbered so the user can refer to them by number.",
  {},
  async () => {
    const todos = readTodos();
    return {
      content: [
        {
          type: "text",
          text: formatTodoList(todos),
          annotations: { audience: ["assistant"] },
        },
      ],
    };
  }
);

// --- complete_todo ----------------------------------------------------------

server.tool(
  "complete_todo",
  "Mark a todo item as completed. Identify the item by its list number, a title substring, or UUID.",
  todoQuerySchema,
  async (query) => {
    const todos = readTodos();
    const result = completeTodo(todos, query);
    if (!result.isError && result.todos !== todos) {
      saveAndNotify(result.todos);
    }
    return {
      content: [{ type: "text", text: result.message }],
      ...(result.isError ? { isError: true } : {}),
    };
  }
);

// --- uncomplete_todo --------------------------------------------------------

server.tool(
  "uncomplete_todo",
  "Mark a completed todo item as incomplete (undo a completion). Identify the item by its list number, a title substring, or UUID.",
  todoQuerySchema,
  async (query) => {
    const todos = readTodos();
    const result = uncompleteTodo(todos, query);
    if (!result.isError && result.todos !== todos) {
      saveAndNotify(result.todos);
    }
    return {
      content: [{ type: "text", text: result.message }],
      ...(result.isError ? { isError: true } : {}),
    };
  }
);

// --- delete_todo ------------------------------------------------------------

server.tool(
  "delete_todo",
  "Permanently delete a todo item. Identify the item by its list number, a title substring, or UUID.",
  todoQuerySchema,
  async (query) => {
    const todos = readTodos();
    const result = deleteTodo(todos, query);
    if (!result.isError) {
      saveAndNotify(result.todos);
    }
    return {
      content: [{ type: "text", text: result.message }],
      ...(result.isError ? { isError: true } : {}),
    };
  }
);

// ---------------------------------------------------------------------------
// Start
// ---------------------------------------------------------------------------

const transport = new StdioServerTransport();
await server.connect(transport);
