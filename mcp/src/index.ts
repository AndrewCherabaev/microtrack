#!/usr/bin/env node
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { z } from "zod";
import { STATUSES, MicrotrackApi, resolveBaseUrl } from "./api.js";

type Content = { content: Array<{ type: "text"; text: string }>; isError?: boolean };

const baseUrl = resolveBaseUrl(process.argv.slice(2));
const api = new MicrotrackApi(baseUrl);

function json(data: unknown): Content {
  return { content: [{ type: "text", text: JSON.stringify(data, null, 2) }] };
}

function failure(error: unknown): Content {
  const message = error instanceof Error ? error.message : String(error);
  return { content: [{ type: "text", text: message }], isError: true };
}

const server = new McpServer({ name: "microtrack", version: "0.1.0" });
const status = z.enum(STATUSES);

server.registerTool(
  "list_tasks",
  {
    description: `List the tasks on the Microtrack board at ${baseUrl}. Optionally filter by status: new, todo, in_progress, done or archived. Returns id, title, status and timestamps.`,
    inputSchema: { status: status.optional() },
  },
  async ({ status: filter }) => {
    try {
      return json(await api.listTasks(filter));
    } catch (error) {
      return failure(error);
    }
  },
);

server.registerTool(
  "create_task",
  {
    description: "Create a task with the given title through the Microtrack API. The new task always starts in status new.",
    inputSchema: { title: z.string().min(1) },
  },
  async ({ title }) => {
    try {
      return json(await api.createTask(title));
    } catch (error) {
      return failure(error);
    }
  },
);

server.registerTool(
  "set_status",
  {
    description: "Move a task to another status by its id through the Microtrack API. This is the same change as dragging a card on the board.",
    inputSchema: { id: z.number().int().positive(), status },
  },
  async ({ id, status: next }) => {
    try {
      return json(await api.setStatus(id, next));
    } catch (error) {
      return failure(error);
    }
  },
);

await server.connect(new StdioServerTransport());
