require "./microtrack"

store = Microtrack::TaskStore.new(Microtrack.database_path)
Microtrack.run(store)
