defmodule Revkit.Limits do
  @moduledoc """
  One source of truth for product limits.

  The catalog is intentionally bounded: public content is curated, private
  editions are capped per cookie, and forms stay small and predictable.
  """

  @max_name 120
  @max_description 500
  @max_notes 2_000
  @max_template 4_000
  @max_target 40
  @max_tools 10
  @max_tool_length 60
  @max_variables 12
  @max_variable_name 32
  @max_variable_value 512
  @max_steps 8
  @max_tags 3
  @max_tag_vocabulary 24
  @max_private_editions 50
  @max_search 100

  def max_name, do: @max_name
  def max_description, do: @max_description
  def max_notes, do: @max_notes
  def max_template, do: @max_template
  def max_target, do: @max_target
  def max_tools, do: @max_tools
  def max_tool_length, do: @max_tool_length
  def max_variables, do: @max_variables
  def max_variable_name, do: @max_variable_name
  def max_variable_value, do: @max_variable_value
  def max_steps, do: @max_steps
  def max_tags, do: @max_tags
  def max_tag_vocabulary, do: @max_tag_vocabulary
  def max_private_editions, do: @max_private_editions
  def max_search, do: @max_search
end
