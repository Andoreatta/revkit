defmodule Revkit.Engine.Template do
  @moduledoc """
  Pure variable substitution for payload templates.

  Variables use `{{NAME}}` placeholders. Rendering is literal substitution: no
  escaping, shell interpretation, or execution is performed.
  """

  @placeholder ~r/\{\{([A-Za-z_][A-Za-z0-9_]*)\}\}/

  @doc """
  Returns unique placeholder names in first-seen order.
  """
  @spec variables(String.t()) :: [String.t()]
  def variables(template) when is_binary(template) do
    @placeholder
    |> Regex.scan(template, capture: :all_but_first)
    |> List.flatten()
    |> Enum.uniq()
  end

  @doc """
  Substitutes placeholder values into `template`.

  Missing or blank variables are reported together instead of substituting
  partial output.
  """
  @spec render(String.t(), map()) ::
          {:ok, String.t()} | {:error, {:missing_variables, [String.t()]}}
  def render(template, variables) when is_binary(template) and is_map(variables) do
    values = Map.new(variables, fn {key, value} -> {to_string(key), value} end)
    names = variables(template)

    missing =
      Enum.filter(names, fn name ->
        Map.get(values, name) in [nil, ""]
      end)

    if missing == [] do
      rendered =
        Regex.replace(@placeholder, template, fn _, name ->
          values |> Map.fetch!(name) |> to_string()
        end)

      {:ok, rendered}
    else
      {:error, {:missing_variables, missing}}
    end
  end
end
