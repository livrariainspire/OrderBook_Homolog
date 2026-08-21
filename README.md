# Order Book — Livraria Inspire

Sistema de gestao de pedidos, estoque e vendas da Livraria Inspire.

- **Site (esta pasta):** Nuxt 3, publicado automaticamente pelo GitHub Pages
- **Servidor:** Supabase (banco Postgres, contas, arquivos e a funcao `api`)

## O unico arquivo que voce precisa editar

`public/config.js` — cole ali o endereco e a chave publica do seu projeto Supabase.
Eles ficam em **Supabase > Project Settings > API**.

Depois de salvar, o GitHub reconstroi o site sozinho em 2 a 3 minutos.

## O que ja vem pronto

- `.github/workflows/deploy.yml` — publica o site a cada alteracao
- `supabase/schema.sql` — estrutura completa do banco
- `supabase/functions/api/index.ts` — funcao de administracao de contas

## Perfis de acesso

| Perfil | O que faz |
|---|---|
| Administracao | Aprova cadastros, cadastra unidades e catalogo, redireciona pedidos, ve relatorios e registros |
| Atendimento | Puxa pedidos da fila, informa a quantidade enviada |
| Igreja da Rede | Faz pedidos, controla o estoque, registra vendas |
| Ponto de Partida | Faz pedidos, controla o estoque, registra vendas |
