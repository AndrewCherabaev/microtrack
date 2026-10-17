# microtrack

A local task board that runs as one binary. The Crystal server serves a single HTML page with inline CSS and JavaScript, keeps the tasks in one SQLite file, and answers a small JSON API. The page title is `µtrack`.

A task has a title, one status, and two timestamps. The statuses are `new`, `todo`, `in_progress`, `done` and `archived`. The board shows one column per status and hides the `archived` column behind a toggle. You create a task through a modal, move a card by dragging it to another column, and the board refreshes from the server every 30 seconds. The modal pauses the refresh while it is open, so a refresh never clears what you are typing.

The repository lives at https://github.com/AndrewCherabaev/microtrack. Clone it with:

```
git clone https://github.com/AndrewCherabaev/microtrack
```

## Run

```
cd microtrack-app
shards install
shards run
```

The board answers on `http://127.0.0.1:3000`. The database file is `./microtrack.db` in the working directory of the binary. Set `MICROTRACK_DB` if you want another path.

## Build

```
shards build --release --no-debug
```

The command turns on `-O3` optimization, single-module code generation and no debug symbols. The result is `bin/microtrack`. Read `../ARCHITECTURE.md` for the reason the build does not use `--static` or `--mcpu=native`.

## Test

```
crystal spec
```

## API

- `GET /` returns the embedded page.
- `GET /api/tasks` returns all tasks as a JSON array.
- `POST /api/tasks` with `{"title": "..."}` creates a task in status `new`.
- `PATCH /api/tasks/:id` with `{"status": "..."}` moves a task to another status. An unknown id answers 404, an unknown status answers 400, a blank title answers 400.

## MCP server

The folder `mcp/` holds a separate TypeScript server. It lets an MCP client, for example an AI agent, call the same API. The client never opens the database file. Build it with `npm install` and `npm run build`, and read `mcp/README.md` for the client configuration.

## Maintainer

AndrewCherabaev
