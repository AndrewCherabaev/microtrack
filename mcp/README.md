# Microtrack MCP server

The server lets an MCP client (Claude Desktop, Cursor, OpenCode, another agent) work with the same tasks the board shows. It talks to the Microtrack HTTP API over the network and never opens the SQLite file, so the Crystal binary stays the only writer of the database and must be running.

## Build

Run these commands once after a clone or after changing anything in `src/`:

```
cd microtrack-app/mcp
npm install
npm run build
```

The build writes `dist/index.js`. The server needs Node.js 20 or newer for the built-in `fetch`.

## Point the server at a board

By default the server calls `http://localhost:3000`. Any other address comes from one of three ways, in order of priority:

- the `--url` flag, for example `--url http://192.168.1.10:3000`;
- the `--host` and `--port` flags, which build the address as `http://<host>:<port>` and default to `localhost` and `3000`;
- the `MICROTRACK_URL`, `MICROTRACK_HOST` or `MICROTRACK_PORT` environment variables.

## Configure a client

Copy the `mcpServers` object from `config.json` into the client configuration, then correct the path in `args` to point at the built `dist/index.js`. Put the address in `env.MICROTRACK_URL`, or in `args` as `--url`, whichever the client supports.

For OpenCode add the server to `opencode.jsonc` instead:

```jsonc
{
  "mcp": {
    "microtrack": {
      "type": "local",
      "command": ["node", "/Users/andrew/Projects/minitrack/microtrack-app/mcp/dist/index.js", "--url", "http://localhost:3000"],
      "enabled": true
    }
  }
}
```

## Tools

The server exposes three tools.

- `list_tasks`: list the tasks, optionally filtered by status `new`, `todo`, `in_progress`, `done`, `archived`. The filter runs on the client side, because the API returns the full list.
- `create_task`: create a task from a title through `POST /api/tasks`. The task starts in status `new`.
- `set_status`: move a task to another status by id through `PATCH /api/tasks/:id`, the same change as dragging a card.

Every tool returns the task fields as JSON: `id`, `title`, `status`, `created_at`, `updated_at`. A tool answers with `isError` and the API message when the call fails, for example an unknown id.
