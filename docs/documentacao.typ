#set document(
  title: "RevKit — Estúdio de Payloads para Testes Autorizados",
  author: "Lucas Andreatta; Leandro Sakae Kobayashi Ostruka",
)

#set page(
  paper: "a4",
  margin: (x: 2.5cm, y: 2.4cm),
)

#set text(
  lang: "pt",
  font: "Libertinus Serif",
  size: 11pt,
)

#set par(justify: true, leading: 0.7em)

#set heading(numbering: "1.1")

#show heading.where(level: 1): it => {
  v(0.6em)
  text(size: 16pt, weight: "bold", fill: rgb("#0f766e"))[#it]
  v(0.5em)
}

#show heading.where(level: 2): it => {
  v(0.7em)
  text(size: 12.5pt, weight: "bold", fill: rgb("#0f172a"))[#it]
  v(0.2em)
}

#show link: set text(fill: rgb("#0f766e"))

#show raw: set text(font: "Noto Sans Mono", size: 9pt)

// ---------------------------------------------------------------------------
// Capa
// ---------------------------------------------------------------------------

#set page(numbering: none)

#align(center)[
  #v(1.2cm)
  #text(size: 13pt, weight: "bold")[Unifil — Centro Universitário Filadélfia]
  #v(0.2cm)
  #text(size: 10pt)[Londrina — Paraná — Brasil]
  #v(2.2cm)
  #image("logo.png", width: 2.4cm)
  #v(0.8cm)
  #text(size: 26pt, weight: "bold", fill: rgb("#0f766e"))[RevKit]
  #v(0.3cm)
  #text(size: 13pt)[Estúdio de Payloads para Testes Autorizados]
  #v(1.8cm)
  #text(size: 11pt)[Documentação — Projeto de Desenvolvimento de Software I e II]
]

#v(2.5cm)

#align(center)[
  #set text(size: 10.5pt)
  Autores: *Lucas Andreatta e Leandro Sakae Kobayashi Ostruka* \
  Professor: *Fernando Nakagawa* \
  Modalidade: *Dupla* \
  Repositório: #link("https://github.com/andoreatta/revkit")[https://github.com/andoreatta/revkit]
]

#v(1fr)

#align(center)[
  #text(size: 10.5pt)[Londrina \
  2026]
]

#pagebreak()

// ---------------------------------------------------------------------------
// Sumário
// ---------------------------------------------------------------------------

#set page(numbering: "i", number-align: center)

#outline(title: [Sumário], indent: auto)

#pagebreak()

#counter(page).update(1)

#set page(
  numbering: "1",
  number-align: center,
  header: context {
    set text(size: 8pt, fill: rgb("#6b7280"))
    grid(
      columns: (1fr, auto),
      align: (left, right),
      [RevKit — Documentação],
      [Projeto de Desenvolvimento de Software I e II],
    )
    v(-0.35em)
    line(length: 100%, stroke: 0.3pt + rgb("#d1d5db"))
  },
)

// ---------------------------------------------------------------------------
// 1 Introdução
// ---------------------------------------------------------------------------

= Introdução

== Contexto e problema

Ferramentas de geração de payloads costumam apresentar listas de comandos
prontos. Elas são úteis para tarefas pontuais, mas não preservam a combinação
utilizada, não permitem compor transformações e não relacionam o resultado às
características do alvo. Em testes autorizados, é importante registrar o
template, as variáveis, a cadeia de transformações e o contexto de uso.

O RevKit foi desenvolvido para preencher essa lacuna. Ele reúne um catálogo
público de templates, um motor de transformação de strings, validação de
compatibilidade e receitas que reproduzem uma geração completa. O sistema
trabalha apenas com texto: não executa, não spawna processos e não chama
comandos com o payload gerado.

== Objetivo

O objetivo geral é disponibilizar uma aplicação web para compor, visualizar,
validar e copiar payloads de segurança ofensiva em testes autorizados.

Os objetivos específicos são:

- permitir a composição de templates com variáveis no formato `{{NOME}}`;
- aplicar uma cadeia ordenada de transformações com pré-visualização;
- comparar os requisitos das transformações com os metadados do alvo;
- salvar e reabrir receitas completas de geração;
- manter um catálogo público somente leitura e edições privadas por navegador;
- verificar a implementação com testes automatizados e ferramentas de qualidade.

== Escopo e uso responsável

O RevKit é destinado a laboratórios, CTFs e testes com autorização explícita.
A aplicação apenas gera e valida strings. Não há execução de payloads, coleta de
credenciais, varredura de redes ou qualquer ação contra sistemas reais.

O catálogo público é somente leitura. Alterações são feitas em edições privadas
vinculadas ao cookie do navegador. Não há autenticação de usuários: o cookie é
uma identidade de escopo, não uma barreira de segurança. Apagar o cookie perde
o acesso às edições privadas anteriores.

== Tecnologias utilizadas

#figure(
  table(
    columns: (3.2cm, 1fr),
    inset: 5pt,
    stroke: 0.5pt + rgb("#d1d5db"),
    table.header([*Camada*], [*Tecnologia e uso*]),
    [Interface], [Phoenix 1.8 e LiveView 1.2, com HEEx, Tailwind, daisyUI e Heroicons.],
    [Domínio], [Elixir 1.17+, com módulos puros para template, cadeia e validação.],
    [Persistência], [Ecto 3.13 e SQLite por meio de `ecto_sqlite3`.],
    [Servidor], [Bandit, com endpoints HTTP e WebSocket do Phoenix.],
    [Qualidade], [ExUnit, Credo, Sobelow e Dialyzer, reunidos em `mix precommit`.],
    [Empacotamento], [Docker, release Elixir e volume persistente para o SQLite.],
    [Diagramas], [PlantUML e Graphviz, com fontes versionados no repositório.],
  ),
  caption: [Tecnologias utilizadas no projeto.],
  supplement: [Tabela],
) <tab-stack>

== Organização do documento

A Seção 2 apresenta os requisitos, os casos de uso, a arquitetura, o modelo de
dados, as decisões de implementação e a verificação do sistema. A Seção 3
apresenta a conclusão, os aprendizados, as limitações e os trabalhos futuros.

// ---------------------------------------------------------------------------
// 2 Desenvolvimento
// ---------------------------------------------------------------------------

= Desenvolvimento

== Metodologia

O desenvolvimento foi incremental e organizado em camadas. Primeiro foram
implementados o motor puro e seus testes; depois, os schemas Ecto e o contexto
`Revkit.Catalog`; em seguida, as LiveViews, a validação, o hook de cópia, as
receitas, o catálogo público com edições privadas e os limites do produto. Cada
etapa foi verificada com `mix precommit`, que reúne compilação sem avisos,
formatação, Credo, Sobelow, testes e Dialyzer.

A separação de responsabilidades segue a direção `RevkitWeb → Revkit.Catalog →
Revkit.Repo`, enquanto a interface também usa `Revkit.Engine`. O motor não
depende de Ecto, Phoenix, Repo ou estado de processo. Essa decisão reduz o custo
da pré-visualização e facilita os testes (SOMMERVILLE, 2019).

== Requisitos Funcionais e Não Funcionais

Os requisitos funcionais descrevem o que o usuário pode fazer no sistema. Os
requisitos não funcionais registram restrições de segurança, qualidade,
portabilidade e usabilidade (PRESSMAN; MAXIM, 2021).

#figure(
  table(
    columns: (1.6cm, 1fr),
    inset: 4pt,
    stroke: 0.5pt + rgb("#d1d5db"),
    table.header([*ID*], [*Requisito funcional*]),
    [RF01], [Consultar o catálogo público de payloads e receitas.],
    [RF02], [Criar um payload privado com template, alvo, notas e tags.],
    [RF03], [Criar uma edição privada a partir de um item público, sem alterar o original.],
    [RF04], [Editar ou descartar somente as próprias edições privadas.],
    [RF05], [Compor templates com variáveis no formato `{{NOME}}`.],
    [RF06], [Configurar uma cadeia ordenada de transformações.],
    [RF07], [Exibir pré-visualização do payload em tempo real.],
    [RF08], [Validar compatibilidade com sistema operacional, shell e ferramentas do alvo.],
    [RF09], [Copiar o payload gerado.],
    [RF10], [Salvar uma receita com template, variáveis, cadeia, alvo, notas, tags e favorito.],
    [RF11], [Reabrir uma receita salva com a mesma combinação de geração.],
    [RF12], [Pesquisar e filtrar por texto, favoritos e tag.],
    [RF13], [Aplicar o vocabulário fixo de tags.],
    [RF14], [Favoritar edições privadas.],
    [RF15], [Exibir estados vazios, avisos de compatibilidade e erros de limite.],
  ),
  caption: [Requisitos funcionais do RevKit.],
  supplement: [Tabela],
) <tab-rf>

#figure(
  table(
    columns: (1.6cm, 1fr),
    inset: 4pt,
    stroke: 0.5pt + rgb("#d1d5db"),
    table.header([*ID*], [*Requisito não funcional*]),
    [RNF01], [Não executar, spawnar ou chamar comandos com o payload gerado.],
    [RNF02], [Realizar a pré-visualização em memória, sem gravação no banco.],
    [RNF03], [Manter o catálogo público somente leitura e as alterações em edições privadas por cookie.],
    [RNF04], [Usar cookie de proprietário assinado, `HttpOnly`, `SameSite=Lax` e com validade de um ano.],
    [RNF05], [Adaptar a interface entre 320 px e 1440 px.],
    [RNF06], [Usar SQLite embutido com uma única instância de escrita.],
    [RNF07], [Centralizar limites de campos, variáveis, passos, tags e edições em `Revkit.Limits`.],
    [RNF08], [Aplicar CSP com nonce e bloquear scripts inline sem nonce.],
    [RNF09], [Passar pelo gate `mix precommit` (compilação, formatação, Credo, Sobelow, testes e Dialyzer).],
    [RNF10], [Empacotar em Docker, executar como usuário não-root e expor `/health`.],
  ),
  caption: [Requisitos não funcionais do RevKit.],
  supplement: [Tabela],
) <tab-rnf>

== Casos de Uso

O ator do sistema é o *Usuário*. A @fig-caso apresenta os nove casos de uso;
a @tab-uc resume o objetivo e os requisitos relacionados de cada um.


#[
  #set text(size: 9.5pt)
  #figure(
    table(
      columns: (1.1cm, 3.4cm, 1fr, 2.0cm),
      inset: 3pt,
      stroke: 0.5pt + rgb("#d1d5db"),
      table.header([*ID*], [*Caso de uso*], [*Objetivo*], [*Requisitos*]),
      [UC01], [Consultar catálogo público], [Navegar pelo catálogo público de payloads e receitas.], [RF01],
      [UC02], [Criar payload privado], [Criar um payload com template, alvo, notas e tags.], [RF02, RF13],
      [UC03], [Gerar payload], [Selecionar template, preencher variáveis, configurar a cadeia, visualizar, validar e copiar.], [RF05–RF09],
      [UC04], [Salvar receita], [Persistir nome, template, variáveis, cadeia, alvo, notas, tags e favorito.], [RF10, RF13],
      [UC05], [Reabrir receita], [Restaurar o snapshot completo e pré-visualizar a mesma combinação.], [RF11],
      [UC06], [Criar edição privada], [Copiar um item público para uma edição privada sem alterar o original.], [RF03],
      [UC07], [Editar ou descartar edição privada], [Alterar ou remover somente a própria edição.], [RF04, RF13],
      [UC08], [Pesquisar e filtrar catálogo], [Buscar por texto, favoritos e tag entre itens públicos e edições próprias.], [RF12],
      [UC09], [Favoritar edição privada], [Marcar ou desmarcar uma edição própria como favorita.], [RF14],
    ),
    caption: [Casos de uso do RevKit.],
    supplement: [Tabela],
  ) <tab-uc>
]

O caso UC03 concentra a pré-visualização, a validação e a cópia, mas não grava
no banco. A gravação ocorre apenas em UC04. UC05 restaura template, variáveis,
cadeia, alvo, notas e tags. UC06 cria uma cópia privada sem modificar o item
público. UC07 permite editar ou descartar somente a própria edição. UC08
considera o catálogo público e as edições do cookie atual. UC09 permite
favoritar apenas edições privadas.

#figure(
  image("diagramas/casos-de-uso.png", width: 100%),
  caption: [Diagrama de Caso de Uso do RevKit.],
  supplement: [Figura],
) <fig-caso>

== Arquitetura

A aplicação é dividida em três camadas. A interface LiveView conversa com o
contexto `Revkit.Catalog`, que é o único módulo de domínio que acessa
`Revkit.Repo`. O contexto usa o Repo para persistir no SQLite. A interface também
usa o motor puro para renderizar, transformar e validar strings.

#figure(
  image("diagramas/arquitetura.png", width: 100%),
  caption: [Arquitetura em camadas do RevKit.],
  supplement: [Figura],
) <fig-arquitetura>

Os diretórios principais são:

- `lib/revkit/engine/` — motor puro de transformação de strings, sem Ecto ou Phoenix.
- `lib/revkit/catalog/` — schemas Ecto e contexto `Revkit.Catalog`; persistência SQLite e escopo por proprietário.
- `lib/revkit_web/` — interface Phoenix/LiveView, rotas, componentes e identidade por cookie.

A direção das dependências é intencional: o motor não conhece a interface nem a
persistência. Isso permite testar template, cadeia e validação sem banco de
dados e sem processo web.

== Modelo de dados e DER

O modelo separa o catálogo público das edições privadas. Em `payloads` e
`recipes`, o campo `owner_id` nulo identifica uma linha pública; quando
preenchido, identifica uma edição privada do cookie. Os campos
`source_payload_id` e `source_recipe_id` apontam para o item público que foi
melhorado.

#figure(
  table(
    columns: (3.1cm, 1fr),
    inset: 4pt,
    stroke: 0.5pt + rgb("#d1d5db"),
    table.header([*Entidade*], [*Papel*]),
    [`payloads`], [Templates públicos e edições privadas de payload.],
    [`recipes`], [Snapshots de geração: template, variáveis, cadeia, alvo, notas e tags.],
    [`tags`], [Vocabulário fixo compartilhado entre payloads e receitas.],
    [`payloads_tags`], [Associação N:N entre payloads e tags.],
    [`recipes_tags`], [Associação N:N entre receitas e tags.],
  ),
  caption: [Entidades principais do modelo de dados.],
  supplement: [Tabela],
) <tab-entidades>

As relações principais são: um payload pode ter várias receitas derivadas por
`recipes.payload_id`; um payload pode apontar para uma receita padrão por
`payloads.recipe_id`; e as colunas `source_payload_id` e `source_recipe_id`
representam edições privadas. As tabelas de associação usam chave primária
composta. O DER utiliza tipos lógicos; no SQLite, `JSON` e `DATETIME` são
armazenados como `TEXT`, e `BOOLEAN` como `INTEGER`.

#figure(
  image("diagramas/der.png", width: 100%),
  caption: [DER do RevKit.],
  supplement: [Figura],
) <fig-der>

== Motor de transformação

O motor é composto por quatro módulos principais:

- `Revkit.Engine.Template` localiza e substitui variáveis `{{NOME}}` literalmente, sem escapar ou executar o conteúdo.
- `Revkit.Engine.Transforms` mantém o registro de transformações disponíveis.
- `Revkit.Engine.Chain` aplica a cadeia em ordem e interrompe no primeiro erro.
- `Revkit.Engine.Validator` agrega requisitos e pontos de atenção e compara com os metadados do alvo.

As transformações disponíveis estão resumidas na @tab-transforms. A
pré-visualização renderiza o template, resolve a cadeia, executa as
transformações e valida o resultado em memória. Nenhuma etapa grava no banco ou
executa o payload. A @fig-seq mostra o fluxo.

#figure(
  table(
    columns: (3.1cm, 1fr, 1fr),
    inset: 4pt,
    stroke: 0.5pt + rgb("#d1d5db"),
    table.header([*Transformação*], [*Efeito*], [*Requisito principal*]),
    [Base64 encode], [Codifica a string em Base64.], [Nenhum para gerar; decodificação no transporte.],
    [URL encode], [Aplica percent-encoding para transporte em URL.], [Nenhum para gerar; decodificação no transporte.],
    [Bash wrapper], [Envolve o comando em `bash -c`.], [Bash no alvo.],
  ),
  caption: [Transformações disponíveis.],
  supplement: [Tabela],
) <tab-transforms>

#figure(
  image("diagramas/sequencia-geracao.png", width: 100%),
  caption: [Sequência de geração e pré-visualização.],
  supplement: [Figura],
) <fig-seq>

== Catálogo e edições privadas

O catálogo público é composto por oito payloads e seis receitas iniciais. Ele é
somente leitura: o botão *Improve* (Melhorar) copia um item para uma edição
privada e vincula a cópia ao cookie atual. Uma edição pode ser editada ou
descartada, mas
o item público permanece visível para todos os navegadores. O índice único
`(owner_id, source_payload_id)` e o equivalente para receitas garantem uma
edição por item público e por cookie.

As tags formam um vocabulário fixo de 24 nomes. Cada payload ou receita pode usar
até três tags. Favoritos também são privados. A @tab-limites resume os
limites centralizados em `Revkit.Limits`.

#figure(
  table(
    columns: (5.2cm, auto),
    inset: 4pt,
    stroke: 0.5pt + rgb("#d1d5db"),
    table.header([*Campo ou recurso*], [*Limite*]),
    [Nome], [120 caracteres],
    [Descrição], [500 caracteres],
    [Notas], [2.000 caracteres],
    [Template], [4.000 caracteres],
    [Variáveis], [12; nome com 32 e valor com 512 caracteres],
    [Passos da cadeia], [8],
    [Tags por item], [3],
    [Vocabulário de tags], [24],
    [Edições privadas por proprietário], [50],
    [Busca], [100 caracteres],
  ),
  caption: [Limites principais do produto.],
  supplement: [Tabela],
) <tab-limites>

== Interface e segurança

A interface é construída com LiveView. O formulário do gerador reúne template,
variáveis, cadeia e metadados do alvo; a pré-visualização é atualizada a cada
alteração. Avisos de compatibilidade aparecem antes do botão de cópia. O botão
de cópia usa um hook colocado no próprio LiveView e lê o valor de um atributo
`data-*`, sem arquivo JavaScript externo.

As páginas de payloads e receitas separam o catálogo público das edições do
cookie atual. Não há exclusão de itens públicos nem criação livre de tags. A
interface se adapta de 320 px a 1440 px e usa componentes compartilhados para
estados vazios, metadados, tags, favoritos e blocos de código.

A segurança segue o escopo do projeto: o sistema gera strings, mas não as
executa. A aplicação usa CSP com nonce, cookie assinado `HttpOnly` e
`SameSite=Lax`, e não expõe API JSON. Como não há autenticação, o cookie é
identidade de escopo, não controle de acesso. Em uma implantação pública, o
acesso deve ser protegido por rede ou proxy autenticado (OWASP, 2026).

== Testes, qualidade e implantação

A suíte possui 142 testes. Os testes do motor são puros e assíncronos; os testes
de banco usam SQLite com sandbox; os testes de LiveView verificam formulários,
navegação, limites, avisos e isolamento entre cookies. O comando
`mix precommit` executa compilação sem avisos, limpeza de dependências não
utilizadas, formatação, Credo, Sobelow, testes e Dialyzer.

A aplicação também foi verificada em 320, 375, 768, 1024 e 1440 px, sem
transbordamento horizontal. A imagem Docker foi construída e testada com
`/health`, migrações, seed do catálogo e execução como usuário não-root.

#figure(
  image("diagramas/implantacao.png", width: 72%),
  caption: [Implantação do RevKit com Docker e SQLite.],
  supplement: [Figura],
) <fig-deploy>

A execução local usa `mix setup` e `mix phx.server`. O Docker usa uma release
Elixir com Bandit, aplica migrações na entrada do container e persiste o SQLite
em `/data/revkit.db`, no volume `revkit_data`. O SQLite é single-writer; por
isso a aplicação deve rodar em uma única instância.

== Dificuldades e decisões

- Manter o motor puro enquanto a interface precisava de pré-visualização em tempo real.
- Modelar catálogo público e edições privadas sem autenticação, usando um cookie assinado.
- Limitar tags e campos para evitar curadoria aberta e manter o catálogo previsível.
- Testar o isolamento entre cookies sem transformar o cookie em conta de usuário.
- Equilibrar CSP, hook de cópia e formulários LiveView sem scripts inline sem nonce.

// ---------------------------------------------------------------------------
// 3 Conclusão
// ---------------------------------------------------------------------------

= Conclusão

O RevKit cumpriu o objetivo de oferecer um estúdio de payloads para testes
autorizados, com catálogo público, edições privadas, receitas reproduzíveis,
pré-visualização, validação e cópia. A implementação manteve a geração de
strings separada da execução e documentou as decisões de escopo e segurança.

Aprendemos a importância de separar um domínio puro das camadas de interface e
persistência. Essa separação tornou o motor simples de testar e permitiu que a
pré-visualização no LiveView fosse rápida e previsível. Também aprofundamos o uso
de LiveView para estado, formulários e atualizações em tempo real, de Ecto e
SQLite para migrations e consultas com escopo, e de testes automatizados para
verificar comportamentos de cookie.

Aprendemos, ainda, que decisões de produto afetam a arquitetura: tornar o catálogo
público somente leitura exigiu um modelo de edições privadas; limitar tags e
campos exigiu uma fonte única de limites; e a ausência de autenticação tornou
necessário documentar claramente que o cookie não é uma barreira de segurança.

As principais limitações são a ausência de contas e autenticação, a perda das
edições ao apagar o cookie, a ausência de exclusão do catálogo público e o uso de
uma única instância SQLite. Como trabalhos futuros, podem ser adicionados
autenticação e propriedade durável, auditoria, exportação e importação de
receitas, novas transformações, integração contínua e proteção TLS em produção.

// ---------------------------------------------------------------------------
// Referências
// ---------------------------------------------------------------------------

#pagebreak()

#heading(level: 1, numbering: none)[Referências]

#set text(size: 10pt)
#set par(hanging-indent: 1.5em)

ASSOCIAÇÃO BRASILEIRA DE NORMAS TÉCNICAS. *NBR 6023*: informação e documentação: referências: elaboração. Rio de Janeiro: ABNT, 2018.

DOCKER. *Docker documentation*. Disponível em: #link("https://docs.docker.com/")[https://docs.docker.com/]. Acesso em: 28 out. 2026.

ECTO. *Ecto documentation*. Disponível em: #link("https://hexdocs.pm/ecto/")[https://hexdocs.pm/ecto/]. Acesso em: 28 out. 2026.

ELIXIR. *Elixir documentation*. Disponível em: #link("https://elixir-lang.org/docs.html")[https://elixir-lang.org/docs.html]. Acesso em: 28 out. 2026.

OWASP. *Web Security Testing Guide*. Disponível em: #link("https://owasp.org/www-project-web-security-testing-guide/")[https://owasp.org/www-project-web-security-testing-guide/]. Acesso em: 28 out. 2026.

PHOENIX. *Phoenix Framework documentation*. Disponível em: #link("https://hexdocs.pm/phoenix/")[https://hexdocs.pm/phoenix/]. Acesso em: 28 out. 2026.

PHOENIX LIVEVIEW. *Phoenix LiveView documentation*. Disponível em: #link("https://hexdocs.pm/phoenix_live_view/")[https://hexdocs.pm/phoenix_live_view/]. Acesso em: 28 out. 2026.

PLANTUML. *PlantUML documentation*. Disponível em: #link("https://plantuml.com/")[https://plantuml.com/]. Acesso em: 28 out. 2026.

PRESSMAN, Roger S.; MAXIM, Bruce R. *Engenharia de software*: uma abordagem profissional. 9. ed. Porto Alegre: AMGH, 2021.

SOMMERVILLE, Ian. *Engenharia de software*. 10. ed. São Paulo: Pearson, 2019.

SQLITE. *SQLite documentation*. Disponível em: #link("https://www.sqlite.org/docs.html")[https://www.sqlite.org/docs.html]. Acesso em: 28 out. 2026.
