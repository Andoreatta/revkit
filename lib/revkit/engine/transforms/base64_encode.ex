defmodule Revkit.Engine.Transforms.Base64Encode do
  @moduledoc """
  Encodes the payload as standard Base64 (RFC 4648, with padding).
  """

  @behaviour Revkit.Transform

  @impl true
  def key, do: :base64_encode

  @impl true
  def label, do: "Base64 encode"

  @impl true
  def kind, do: :encoding

  @impl true
  def apply(input, _options), do: {:ok, Base.encode64(input)}

  @impl true
  def requires, do: []

  @impl true
  def pitfalls do
    [
      "Base64 is an encoding, not encryption; anyone can reverse it.",
      "Long Base64 blobs are commonly flagged by filters and WAFs."
    ]
  end
end
