Leia este documento em: [English](README.md) | [Português (Brasil)](README.pt-BR.md)

# RevKit

RevKit é um estúdio de payloads em Phoenix/LiveView para compor, validar e
copiar strings de payload de segurança ofensiva em testes autorizados. É um
fluxo puramente textual: nada é executado.

## Identificação

- **Disciplina:** Projeto de Desenvolvimento de Software I e II
- **Modalidade:** Individual
- **Autor:** Lucas Andreatta
- **Repositório:** https://github.com/andoreatta/revkit

## Status

- **Parte I — Documentação:** disponível no [PDF](docs/documentacao.pdf).
- **Parte II — Implementação:** aplicação Phoenix/LiveView funcional, verificada
  com `mix precommit` e empacotada para Docker.

## Stack

**Elixir, Phoenix, LiveView, Ecto e SQLite.**

## O que o sistema faz

- Compõe templates de reverse shell, bind shell, wrappers e encoders com
  placeholders `{{VARIAVEL}}` e metadados do alvo.
- Renderiza uma cadeia ordenada de transformações com pré-visualização e cópia.
- Valida a compatibilidade com o sistema operacional, shell e ferramentas
  declarados para o alvo, exibindo requisitos e pontos de atenção antes da
  cópia.
- Salva receitas completas de geração e mantém um catálogo público somente
  leitura com edições privadas por cookie.

## Como executar

**Requisitos:** Elixir 1.17+ e OTP 27+. O SQLite é embutido via `ecto_sqlite3`;
não é necessário subir um banco de dados separado.

### Local

```bash
mix setup
mix phx.server
```

Acesse <http://localhost:4000>. O comando `mix setup` instala as dependências,
cria, migra e popula o banco SQLite, e compila os assets.

Testes e verificação de qualidade:

```bash
mix test
mix precommit
```

Para recriar o banco e recarregar o catálogo inicial:

```bash
mix ecto.reset
```

### Docker

```bash
cp .env.example .env
# Gere um segredo e coloque-o em SECRET_KEY_BASE no .env:
openssl rand -base64 48
docker compose up --build
```

Acesse <http://localhost:4000>. O Compose escuta em `127.0.0.1:4000` por padrão
e persiste o SQLite no volume `revkit_data`. O Docker inicia com o catálogo
vazio; carregue o catálogo inicial com:

```bash
docker compose exec revkit /app/bin/seed
```

Para parar:

```bash
docker compose down     # mantém o volume SQLite
docker compose down -v  # apaga o volume
```

## Documentação

- [Documentação completa (PDF)](docs/documentacao.pdf)
- [Diagramas do projeto](docs/diagramas/) — caso de uso, DER, arquitetura,
  sequência e implantação.

O PDF contém os Requisitos Funcionais e Não Funcionais, o Diagrama de Caso de
Uso, o DER e os demais diagramas de apoio. Regenere os diagramas e o PDF com
`./docs/build.sh`.

## Vídeos de defesa

- **Parte I — Documentação:** [link do vídeo](INSERIR_LINK_VIDEO_PARTE_I)
- **Parte II — Implementação:** [link do vídeo](INSERIR_LINK_VIDEO_PARTE_II)

## Estrutura do projeto

- `lib/revkit/engine/` — motor puro de transformação de strings; sem Ecto,
  Phoenix ou efeitos colaterais.
- `lib/revkit/catalog/` — schemas Ecto e contexto `Revkit.Catalog`;
  persistência SQLite e consultas com escopo por proprietário.
- `lib/revkit_web/` — interface Phoenix/LiveView, rotas, componentes e
  identidade por cookie.

## Escopo e observações

- O projeto apenas gera e valida strings; nunca executa payloads.
- Não há autenticação nem API JSON. Um cookie assinado limita as edições
  privadas a um navegador; ele não é uma barreira de segurança, e apagar o
  cookie perde o acesso a essas edições.
- O SQLite não suporta múltiplos escritores simultâneos; execute uma única
  instância da aplicação.
