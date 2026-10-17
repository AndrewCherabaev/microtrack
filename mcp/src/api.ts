export const STATUSES = ["new", "todo", "in_progress", "done", "archived"] as const;

export type Status = (typeof STATUSES)[number];

export interface Task {
  id: number;
  title: string;
  status: Status;
  created_at: string;
  updated_at: string;
}

export const DEFAULT_BASE_URL = "http://localhost:3000";

export function flagValue(args: string[], name: string): string | undefined {
  const index = args.indexOf(name);
  return index === -1 ? undefined : args[index + 1];
}

export function resolveBaseUrl(args: string[]): string {
  const explicit = flagValue(args, "--url") ?? process.env.MICROTRACK_URL;
  if (explicit) {
    return explicit.replace(/\/+$/, "");
  }
  const host = flagValue(args, "--host") ?? process.env.MICROTRACK_HOST;
  const port = flagValue(args, "--port") ?? process.env.MICROTRACK_PORT;
  if (host || port) {
    return `http://${host ?? "localhost"}:${port ?? "3000"}`;
  }
  return DEFAULT_BASE_URL;
}

export class MicrotrackApi {
  constructor(private readonly baseUrl: string) {}

  async listTasks(status?: Status): Promise<Task[]> {
    const tasks = await this.request<Task[]>("/api/tasks");
    return status ? tasks.filter((task) => task.status === status) : tasks;
  }

  async createTask(title: string): Promise<Task> {
    return this.request<Task>("/api/tasks", { method: "POST", body: { title } });
  }

  async setStatus(id: number, status: Status): Promise<Task> {
    return this.request<Task>(`/api/tasks/${id}`, { method: "PATCH", body: { status } });
  }

  private async request<T>(path: string, options: { method?: string; body?: unknown } = {}): Promise<T> {
    const response = await fetch(this.baseUrl + path, {
      method: options.method ?? "GET",
      headers: options.body ? { "Content-Type": "application/json" } : {},
      body: options.body ? JSON.stringify(options.body) : undefined,
    });
    if (!response.ok) {
      const detail = (await response.json().catch(() => null)) as { error?: string } | null;
      throw new Error(detail?.error ?? `${response.status} from ${path}`);
    }
    return (await response.json()) as T;
  }
}
