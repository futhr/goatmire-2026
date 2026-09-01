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

              ~r/^## (\d+) · .+? — (\d{2}:\d{2})\s*$\n(.*?)(?=^---\s*$)/ms
              |> Regex.scan(source)
              |> Enum.map(fn [_, number, time, body] ->
                number = String.to_integer(number)

                paragraphs =
                  body
                  |> String.split(~r/\n\s*\n/)
                  |> Enum.map(&String.trim/1)
                  |> Enum.reject(&(&1 == "" or String.starts_with?(&1, "*(")))
                  |> Enum.map(fn paragraph ->
                    paragraph
                    |> String.replace(~r/[\*`]/, "")
                    |> String.trim()
                  end)

                %{
                  number: number,
                  title: Deck.title(number),
                  time: time,
                  paragraphs: paragraphs
                }
              end)
            )

  if length(@sections) != Deck.count() do
    raise "manuscript has #{length(@sections)} slide sections; deck has #{Deck.count()}"
  end

  @type section :: %{
          number: pos_integer(),
          title: String.t(),
          time: String.t(),
          paragraphs: [String.t()]
        }

  @doc "All spoken sections in deck order."
  @spec sections() :: [section()]
  def sections, do: @sections

  @doc "One spoken section by slide number."
  @spec section(pos_integer()) :: section() | nil
  def section(number), do: Enum.find(@sections, &(&1.number == number))
end
