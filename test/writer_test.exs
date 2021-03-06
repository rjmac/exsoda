defmodule ExsodaTest.Writer do
  use ExUnit.Case, async: true
  alias Exsoda.Writer
  alias Exsoda.Reader
  alias Exsoda.Writer.{CreateView, CreateColumn}

  test "can create a create_view operation" do
    w = Writer.write()
    |> Writer.create("a name", %{description: "describes"})

    assert w.operations == [%CreateView{
      name: "a name",
      properties: %{description: "describes"}
    }]
  end

  test "can write with a timeout set" do
    options = Writer.write(recv_timeout: 8000, timeout: 2000)
    |> Writer.create("a name", %{description: "describes"})
    |> Map.get(:opts)

    assert options.recv_timeout == 8000
    assert options.timeout == 2000
  end

  test "running CreateView returns list of results" do
    results = Writer.write()
    |> Writer.create("a name", %{description: "describes"})
    |> Writer.run

    assert [{:ok, _}] = results
  end

  test "running CreateView with no name causes an error" do
    results = Writer.write()
    |> Writer.create("", %{description: "describes"})
    |> Writer.run

    assert [{:error, _}] = results
  end

  test "can create a CreateColumn operation" do
    w = Writer.write()
    |> Writer.create_column("meow-meow", "a name", "text", %{})

    assert w.operations == [%CreateColumn{
      name: "a name",
      dataTypeName: "text",
      fourfour: "meow-meow",
      properties: %{}
    }]
  end

  test "running two CreateColumn ops returns list of results" do
    [{:ok, %{"id" => fourfour}}] = Writer.write()
    |> Writer.create("a name", %{description: "describes"})
    |> Writer.run

    results = Writer.write()
    |> Writer.create_column(fourfour, "a name", "text", %{})
    |> Writer.create_column(fourfour, "a number", "number", %{})
    |> Writer.run

    assert [{:ok, _}, {:ok, _}] = results

    {:ok, view} = Reader.query(fourfour)
    |> Reader.get_view

    col_tuples = view
    |> Map.get("columns", [])
    |> Enum.map(fn column -> {column["name"], column["dataTypeName"]} end)

    assert col_tuples == [
      {"a name", "text"},
      {"a number", "number"}
    ]
  end

  test "running CreateColumn with a bad type causes an error" do
    [{:ok, %{"id" => fourfour}}] = Writer.write()
    |> Writer.create("a name", %{description: "describes"})
    |> Writer.run

    results = Writer.write()
    |> Writer.create_column(fourfour, "name", "not a type", %{})
    |> Writer.run
    assert [{:error, _}] = results
  end

  test "can create Upsert operation" do
    [{:ok, %{"id" => fourfour}}] = Writer.write()
    |> Writer.create("a name", %{description: "describes"})
    |> Writer.run

    [{:ok, _}] = Writer.write()
    |> Writer.create_column(fourfour, "text column", "text", %{})
    |> Writer.run

    results = Writer.write()
    |> Writer.upsert(
      fourfour,
      [%{text_column: "a text value"}, %{text_column: "a second text value"}]
    )
    |> Writer.run

    assert [{:ok, _}] = results

    {:ok, rows_stream} = Reader.query(fourfour)
    |> Reader.run

    assert Enum.into(rows_stream, []) == [[{"text column", "a text value"}], [{"text column", "a second text value"}]]
  end

  test "can do a streaming upsert" do
    [{:ok, %{"id" => fourfour}}] = Writer.write()
    |> Writer.create("a name", %{description: "describes"})
    |> Writer.run

    [{:ok, _}] = Writer.write()
    |> Writer.create_column(fourfour, "text column", "text", %{})
    |> Writer.run

    results = Writer.write()
    |> Writer.upsert(
      fourfour,
      Stream.map(0..8, fn i ->
        %{text_column: "value #{i}"}
      end)
    )
    |> Writer.run

    assert [{:ok, _}] = results

    {:ok, rows_stream} = Reader.query(fourfour)
    |> Reader.run

    assert Enum.into(rows_stream, []) == [
      [{"text column", "value 0"}],
      [{"text column", "value 1"}],
      [{"text column", "value 2"}],
      [{"text column", "value 3"}],
      [{"text column", "value 4"}],
      [{"text column", "value 5"}],
      [{"text column", "value 6"}],
      [{"text column", "value 7"}],
      [{"text column", "value 8"}]
    ]
  end

end
