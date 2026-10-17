require "./html_minifier"
require "db"
require "sqlite3"
require "time"
require "json"
require "kemal"

module Microtrack
  VERSION = "0.1.0"

  STATUSES = ["new", "todo", "in_progress", "done", "archived"]

  BOARD_HTML = HtmlMinifier.transform({{ read_file("#{__DIR__}/../web/index.html") }})

  def self.database_path : String
    ENV.fetch("MICROTRACK_DB", "./microtrack.db")
  end

  struct Task
    getter id : Int64
    getter title : String
    getter status : String
    getter created_at : String
    getter updated_at : String

    def initialize(@id : Int64, @title : String, @status : String, @created_at : String, @updated_at : String)
    end
  end

  class TaskStore
    getter db : DB::Database

    def initialize(path : String)
      @db = DB.open("sqlite3:#{path}")
      @db.exec(<<-SQL)
        CREATE TABLE IF NOT EXISTS tasks (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          status TEXT NOT NULL DEFAULT 'new',
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
        SQL
    end

    def close : Nil
      @db.close
    end

    def create(title : String) : Task
      if title.strip.empty?
        raise ArgumentError.new("title cannot be blank")
      end
      now = Time.utc.to_rfc3339
      result = @db.exec(
        "INSERT INTO tasks (title, status, created_at, updated_at) VALUES (?, 'new', ?, ?)",
        title, now, now
      )
      Task.new(result.last_insert_id, title, "new", now, now)
    end

    def list : Array(Task)
      @db.query_all("SELECT id, title, status, created_at, updated_at FROM tasks ORDER BY id") do |rs|
        Task.new(
          rs.read(Int64),
          rs.read(String),
          rs.read(String),
          rs.read(String),
          rs.read(String)
        )
      end
    end

    def update_status(id : Int64, status : String) : Task?
      unless STATUSES.includes?(status)
        raise ArgumentError.new("invalid status: #{status}")
      end
      found = @db.query_one?("SELECT title, created_at FROM tasks WHERE id = ?", id, as: {String, String})
      return nil unless found
      title, created_at = found
      now = Time.utc.to_rfc3339
      @db.exec("UPDATE tasks SET status = ?, updated_at = ? WHERE id = ?", status, now, id)
      Task.new(id, title, status, created_at, now)
    end
  end

  def self.task_json(json : JSON::Builder, task : Task) : Nil
    json.object do
      json.field "id", task.id
      json.field "title", task.title
      json.field "status", task.status
      json.field "created_at", task.created_at
      json.field "updated_at", task.updated_at
    end
  end

  def self.task_json(task : Task) : String
    JSON.build do |json|
      Microtrack.task_json(json, task)
    end
  end

  module Api
    record Result, code : Int32, body : String

    def self.tasks_json(tasks : Array(Task)) : String
      JSON.build do |json|
        json.array do
          tasks.each do |task|
            Microtrack.task_json(json, task)
          end
        end
      end
    end

    def self.list(store : TaskStore) : Result
      Result.new(200, tasks_json(store.list))
    end

    def self.field(body : String | Nil, name : String) : String | Nil
      return nil unless body
      parsed = JSON.parse(body)
      value = parsed[name]?
      value && value.as_s?
    end

    def self.create(store : TaskStore, body : String | Nil) : Result
      title = field(body, "title")
      unless title
        return Result.new(400, %q({"error": "title is required"}))
      end
      Result.new(201, Microtrack.task_json(store.create(title)))
    rescue ex : ArgumentError | JSON::ParseException
      Result.new(400, %q({"error": "bad request"}))
    end

    def self.update(store : TaskStore, id_param : String, body : String | Nil) : Result
      id = id_param.to_i64?
      unless id
        return Result.new(404, %q({"error": "not found"}))
      end
      status = field(body, "status")
      return Result.new(400, %q({"error": "status is required"})) unless status
      task = store.update_status(id, status)
      unless task
        return Result.new(404, %q({"error": "not found"}))
      end
      Result.new(200, Microtrack.task_json(task))
    rescue ex : ArgumentError
      Result.new(400, %q({"error": "invalid status"}))
    end
  end

  def self.routes(store : TaskStore) : Nil
    get "/" do |env|
      env.response.content_type = "text/html; charset=utf-8"
      BOARD_HTML
    end

    get "/api/tasks" do |env|
      env.response.content_type = "application/json"
      result = Api.list(store)
      env.response.status_code = result.code
      result.body
    end

    post "/api/tasks" do |env|
      env.response.content_type = "application/json"
      result = Api.create(store, env.request.body.try(&.gets_to_end))
      env.response.status_code = result.code
      result.body
    end

    patch "/api/tasks/:id" do |env|
      env.response.content_type = "application/json"
      id = env.params.url["id"]
      result = Api.update(store, id, env.request.body.try(&.gets_to_end))
      env.response.status_code = result.code
      result.body
    end
  end

  def self.run(store : TaskStore) : Nil
    routes(store)
    Kemal.config.host_binding = "127.0.0.1"
    Kemal.run
  end
end
