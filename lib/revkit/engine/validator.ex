defmodule Revkit.Engine.Validator do
  @moduledoc """
  Aggregates transform requirements and pitfalls into a report.

  This is intentionally metadata-only: `requires/0` and `pitfalls/0` are
  advisory strings, and validation never inspects or executes the payload.
  """

  @typedoc "A target prerequisite, with the transforms that require it."
  @type requirement :: %{name: String.t(), transforms: [module()]}

  @typedoc "A transform warning, with the transforms that raised it."
  @type pitfall :: %{message: String.t(), transforms: [module()]}

  @type warning :: %{type: :unknown_target | :missing_requirement, message: String.t()}

  @type target :: %{
          optional(:os) => String.t() | nil,
          optional(:shell) => String.t() | nil,
          optional(:tools) => [String.t()]
        }

  @type report :: %{
          requires: [requirement()],
          pitfalls: [pitfall()],
          warnings: [warning()],
          compatible: boolean()
        }

  @doc """
  Builds a report from a resolved transform chain and the payload's target
  metadata. Requirements are compared case-insensitively against the declared
  OS, shell, and tools; no target probing or execution is performed.
  """
  @spec validate([{module(), map()}], target()) :: report()
  def validate(chain, target \\ %{}) when is_list(chain) do
    requires = collect(chain, :requires, :name)
    pitfalls = collect(chain, :pitfalls, :message)
    warnings = compatibility_warnings(requires, target)

    %{
      requires: requires,
      pitfalls: pitfalls,
      warnings: warnings,
      compatible: warnings == []
    }
  end

  defp compatibility_warnings(requires, target) do
    capabilities = capabilities(target)

    Enum.flat_map(requires, fn %{name: name} ->
      cond do
        capabilities == [] ->
          [
            %{
              type: :unknown_target,
              message: "Cannot verify \"#{name}\": target metadata is missing."
            }
          ]

        Enum.any?(capabilities, &(String.downcase(&1) == String.downcase(name))) ->
          []

        true ->
          [
            %{
              type: :missing_requirement,
              message: "Requires \"#{name}\", but the target metadata does not declare it."
            }
          ]
      end
    end)
  end

  defp capabilities(target) do
    tools = Map.get(target, :tools, Map.get(target, "tools", [])) |> List.wrap()

    [
      Map.get(target, :os, Map.get(target, "os")),
      Map.get(target, :shell, Map.get(target, "shell")) | tools
    ]
    |> List.wrap()
    |> Enum.filter(&is_binary/1)
    |> Enum.reject(&(&1 == ""))
    |> Enum.uniq()
  end

  defp collect(chain, callback, key) do
    {order, sources} =
      Enum.reduce(chain, {[], %{}}, fn {module, _options}, acc ->
        module
        |> apply(callback, [])
        |> List.wrap()
        |> Enum.reduce(acc, &add_entry(&1, module, &2))
      end)

    order
    |> Enum.reverse()
    |> Enum.map(&to_entry(&1, sources, key))
  end

  defp add_entry(entry, module, {order, sources}) do
    if Map.has_key?(sources, entry) do
      {order, Map.update!(sources, entry, &[module | &1])}
    else
      {[entry | order], Map.put(sources, entry, [module])}
    end
  end

  defp to_entry(entry, sources, key) do
    transforms =
      sources
      |> Map.fetch!(entry)
      |> Enum.reverse()
      |> Enum.uniq()

    %{key => entry, transforms: transforms}
  end
end
