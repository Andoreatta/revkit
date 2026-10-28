defmodule Revkit.Engine.Transforms.BashWrapper do
  @moduledoc """
  Wraps the payload in `bash -c`, single-quoting it for the outer shell.

  Single quotes inside the payload are escaped with the `'\\''` sequence so the
  original string reaches bash unchanged.
  """

  @behaviour Revkit.Transform

  @impl true
  def key, do: :bash_wrapper

  @impl true
  def label, do: "Bash wrapper"

  @impl true
  def kind, do: :wrapper

  @impl true
  def apply(input, _options), do: {:ok, "bash -c " <> quote_single(input)}

  @impl true
  def requires, do: ["bash"]

  @impl true
  def pitfalls do
    [
      "Requires bash on the target; shells limited to /bin/sh may fail.",
      "The wrapped process stays attached to the caller's stdin, stdout and stderr.",
      "The payload runs with the privileges of the invoking user."
    ]
  end

  defp quote_single(value), do: "'" <> String.replace(value, "'", "'\\''") <> "'"
end
