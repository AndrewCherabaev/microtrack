require "./spec_helper"

def with_store(&)
  path = File.tempname("microtrack-test", ".db")
  store = Microtrack::TaskStore.new(path)
  begin
    yield store
  ensure
    store.close
    File.delete(path) if File.exists?(path)
  end
end

describe Microtrack::Api do
  it "lists zero tasks on an empty board" do
    with_store do |store|
      result = Microtrack::Api.list(store)
      result.code.should eq(200)
      result.body.should contain("[]")
    end
  end

  it "lists every task including archived ones" do
    with_store do |store|
      task = store.create("Listed task")
      archived = store.update_status(task.id, "archived").not_nil!
      result = Microtrack::Api.list(store)
      result.code.should eq(200)
      result.body.should contain(archived.title)
      result.body.should contain("archived")
    end
  end

  it "creates a task through the post payload" do
    with_store do |store|
      result = Microtrack::Api.create(store, {"title" => "Via api"}.to_json)
      result.code.should eq(201)
      result.body.should contain("Via api")
      store.list.size.should eq(1)
      store.list.first.status.should eq("new")
    end
  end

  it "rejects a post without a title" do
    with_store do |store|
      nothing = Microtrack::Api.create(store, "{}")
      nothing.code.should eq(400)
      store.list.size.should eq(0)

      blank = Microtrack::Api.create(store, {"title" => "   "}.to_json)
      blank.code.should eq(400)
      store.list.size.should eq(0)
    end
  end

  it "moves a status through the patch payload" do
    with_store do |store|
      task = store.create("Patch target")
      result = Microtrack::Api.update(store, task.id.to_s, {"status" => "in_progress"}.to_json)
      result.code.should eq(200)
      result.body.should contain("in_progress")
      store.list.first.status.should eq("in_progress")
    end
  end

  it "rejects a patch for an unknown id without touching rows" do
    with_store do |store|
      task = store.create("Keeper")
      result = Microtrack::Api.update(store, "777", {"status" => "done"}.to_json)
      result.code.should eq(404)
      store.list.size.should eq(1)
      store.list.first.status.should eq("new")
    end
  end

  it "rejects a patch with a status outside the vocabulary" do
    with_store do |store|
      task = store.create("Guarded")
      result = Microtrack::Api.update(store, task.id.to_s, {"status" => "shipping"}.to_json)
      result.code.should eq(400)
      store.list.first.status.should eq("new")
    end
  end

  it "rejects a patch without a status" do
    with_store do |store|
      task = store.create("No status")
      result = Microtrack::Api.update(store, task.id.to_s, "{}")
      result.code.should eq(400)
      store.list.first.status.should eq("new")
    end
  end
end

describe Microtrack::TaskStore do
  it "creates a task with status new" do
    with_store do |store|
      task = store.create("Ship the beta")
      task.status.should eq("new")
      task.title.should eq("Ship the beta")

      rows = store.list
      rows.size.should eq(1)
      rows.first.id.should eq(task.id)
      rows.first.created_at.should eq(task.created_at)
      rows.first.updated_at.should eq(task.updated_at)
    end
  end

  it "rejects a blank title and stores nothing" do
    with_store do |store|
      expect_raises(ArgumentError) do
        store.create("   ")
      end
      expect_raises(ArgumentError) do
        store.create("")
      end
      store.list.size.should eq(0)
    end
  end

  it "updates a status and leaves untouched rows intact" do
    with_store do |store|
      moved = store.create("Moved task")
      untouched = store.create("Untouched task")

      updated = store.update_status(moved.id, "todo")
      updated.should_not be_nil
      updated = updated.not_nil!
      updated.status.should eq("todo")
      updated.title.should eq("Moved task")
      updated.created_at.should eq(moved.created_at)

      rows = store.list
      rows.size.should eq(2)
      row = rows.find { |t| t.id == moved.id }.not_nil!
      row.status.should eq("todo")
      row.updated_at.should eq(updated.updated_at)
      other = rows.find { |t| t.id == untouched.id }.not_nil!
      other.title.should eq("Untouched task")
      other.status.should eq("new")
      other.created_at.should eq(untouched.created_at)
      other.updated_at.should eq(untouched.updated_at)
    end
  end

  it "rejects an invalid status" do
    with_store do |store|
      task = store.create("Guarded task")
      expect_raises(ArgumentError) do
        store.update_status(task.id, "shipping")
      end
      row = store.list.first
      row.status.should eq("new")
    end
  end

  it "returns nil when updating an unknown id" do
    with_store do |store|
      store.create("Existing task")
      result = store.update_status(-1_i64, "done")
      result.should be_nil
      store.list.size.should eq(1)
    end
  end
end

describe HtmlMinifier do
  it "removes block and line comments and keeps the code" do
    script = "(function () {\n  /* drop me */\n  // and me\n  var x = 1;\n})();"
    HtmlMinifier.minify_script(script).should eq("(function () {\nvar x = 1;\n})();")
  end

  it "minifies style whitespace, comments and spacing around braces" do
    css = "  .card {\n    color: red; /* drop */\n    margin: 0\n  }\n"
    HtmlMinifier.minify_style(css).should eq(".card{color: red;margin: 0}")
  end

  it "collapses whitespace between tags and keeps text nodes" do
    HtmlMinifier.collapse_html("<main>\n  <p>Задача</p>\n</main>").should eq("<main><p>Задача</p></main>")
  end

  it "minifies the html around the script block and keeps a trailing comment" do
    source = "<body>\n  <p>hi</p>\n<script>\n  var x = 1; // trim\n</script>\n</body>"
    HtmlMinifier.transform(source).should eq("<body><p>hi</p><script>var x = 1; // trim</script></body>")
  end
end

describe Microtrack do
  it "embeds the board smaller than the source page and without comments" do
    raw = File.read("web/index.html")
    Microtrack::BOARD_HTML.size.should be < raw.size
    Microtrack::BOARD_HTML.should_not contain("/*")
    Microtrack::BOARD_HTML.should contain("<!DOCTYPE html>")
    Microtrack::BOARD_HTML.should contain("/api/tasks")
  end

  it "reads the database path from the environment" do
    previous = ENV["MICROTRACK_DB"]?
    ENV["MICROTRACK_DB"] = "./tracked.db"
    Microtrack.database_path.should eq("./tracked.db")
    if previous
      ENV["MICROTRACK_DB"] = previous
    else
      ENV.delete("MICROTRACK_DB")
    end
  end

  it "defaults the database path" do
    previous = ENV["MICROTRACK_DB"]?
    ENV.delete("MICROTRACK_DB")
    Microtrack.database_path.should eq("./microtrack.db")
    if previous
      ENV["MICROTRACK_DB"] = previous
    end
  end
end
