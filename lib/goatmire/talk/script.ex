defmodule Goatmire.Talk.Script do
  @moduledoc """
  The spoken manuscript parsed into one text-only section per slide.

  The Markdown manuscript remains the human-edited source. It is embedded at
  compile time so a release carries the notes without shipping the whole docs
  tree, and the deck count check makes drift a compile error.
  """

  alias Goatmire.Talk.Deck

  @manuscript_path Path.expand("../../../docs/talk/manuscript.md", __DIR__)
  @external_resource @manuscript_path

  @sections (
              source = File.read!(@manuscript_path)

              ~r/^## (\d+) · (.+?) — (\d{2}:\d{2})\s*$\n(.*?)(?=^---\s*$)/ms
              |> Regex.scan(source)
              |> Enum.map(fn [_, number, title, time, body] ->
                number = String.to_integer(number)

                # Bold and code spans become emphasis; stray markers are dropped.
                rich =
                  body
                  |> String.split(~r/\n\s*\n/)
                  |> Enum.map(&String.trim/1)
                  |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "*(")))
                  |> Enum.map(fn paragraph ->
                    ~r/\*\*(.+?)\*\*|`([^`]+)`|[^*`]+|[*`]/
                    |> Regex.scan(paragraph)
                    |> Enum.map(fn
                      [_, strong] -> {:strong, String.replace(strong, "`", "")}
                      [_, "", code] -> {:strong, code}
                      [text] -> {:text, String.replace(text, ~r/[\*`]/, "")}
                    end)
                    |> Enum.reject(&(elem(&1, 1) == ""))
                  end)

                %{
                  number: number,
                  title: title,
                  time: time,
                  paragraphs: Enum.map(rich, &String.trim(Enum.map_join(&1, fn {_, t} -> t end))),
                  rich: rich
                }
              end)
            )

  if Enum.map(@sections, &{&1.number, &1.title}) != Deck.titles() do
    raise "manuscript slide identities and order must match Goatmire.Talk.Deck"
  end

  @type section :: %{
          number: pos_integer(),
          title: String.t(),
          time: String.t(),
          paragraphs: [String.t()],
          rich: [[{:text | :strong, String.t()}]]
        }

  @doc "All spoken sections in deck order."
  @spec sections() :: [section()]
  def sections, do: @sections

  @doc "One spoken section by slide number."
  @spec section(pos_integer()) :: section() | nil
  def section(number), do: Enum.find(@sections, &(&1.number == number))
end
