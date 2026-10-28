defmodule Revkit.Engine.Transforms.UrlEncode do
  @moduledoc """
  Percent-encodes the payload using the RFC 3986 unreserved set.

  Spaces become `%20` (not `+`), because form encoding is ambiguous once the
  value is embedded in a shell payload.
  """

  @behaviour Revkit.Transform

  @impl true
  def key, do: :url_encode

  @impl true
  def label, do: "URL encode"

  @impl true
  def kind, do: :encoding

  @impl true
  def apply(input, _options), do: {:ok, URI.encode(input, &URI.char_unreserved?/1)}

  @impl true
  def requires, do: []

  @impl true
  def pitfalls do
    [
      "Percent-encoding is reversible and does not hide the payload.",
      "Spaces become %20; form decoders that expect + will not match."
    ]
  end
end
