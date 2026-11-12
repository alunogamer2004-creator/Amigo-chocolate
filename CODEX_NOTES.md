# Contexto do projeto — Amigo Chocolate

Este arquivo serve como contexto de continuidade para agentes Codex que trabalharem neste repositório.

## Repositório e publicação

- Repositório: `https://github.com/alunogamer2004-creator/Amigo-chocolate`
- Branch principal: `main`
- O commit inicial foi publicado e a configuração do Supabase foi enviada no commit `b1e35d3` (`Configure Supabase project`).
- A publicação na Vercel foi solicitada, mas ainda depende do login na conta Vercel e do deploy final.

## Supabase

- Project ref: `bnaxljcwtjncqujdovof`
- URL do projeto: `https://bnaxljcwtjncqujdovof.supabase.co`
- `config.js` já contém a URL e uma chave **publishable**. Essa chave é apropriada para código de navegador; nunca substituir por uma chave `secret` ou `service_role`.
- Logins anônimos foram habilitados.
- O esquema em `supabase/schema.sql` foi aplicado ao banco remoto.
- As tabelas `game`, `config`, `players` e `assignments` foram verificadas com RLS habilitado.
- A conexão pública ao endpoint de autenticação foi validada com HTTP 200.

## Segurança importante

- Não registre tokens pessoais, senhas do banco, chaves `secret`/`service_role` nem o código administrativo do sorteio neste repositório.
- O código administrativo foi definido diretamente no banco e deve ser guardado somente pelo organizador. Caso seja perdido, ele deve ser trocado no banco por uma operação administrativa segura.
- Um token pessoal do Supabase foi compartilhado durante a configuração. O proprietário deve revogá-lo em **Supabase Dashboard → Account Tokens** e criar outro se ainda precisar de acesso automatizado.
- O arquivo `supabase/schema.sql` continua com o marcador `TROQUE-ESTE-CODIGO` de propósito. Não grave o código real no Git/GitHub.

## Como validar o app

1. Sirva `index.html` localmente (por exemplo, com Live Server) ou faça deploy na Vercel.
2. Em pelo menos três perfis/navegadores diferentes, entre com nomes distintos.
3. Com o código administrativo, execute o sorteio.
4. Confirme que cada perfil só revela o próprio resultado e que a revelação permanece disponível depois.

## Próxima ação: Vercel

1. Fazer login em `https://vercel.com/login`.
2. Na pasta do projeto, executar `vercel --prod` (ou importar o repositório pelo painel da Vercel).
3. Selecionar **Other** como framework, sem comando de build, pois o projeto é estático.
4. Abrir a URL de produção e refazer o teste de autenticação anônima.

## Observação sobre a CLI do Supabase

Nesta máquina, a CLI do Supabase apresentou `HttpClientError: Transport error` ao acessar `api.supabase.com`, embora chamadas HTTPS diretas à API tenham funcionado. A configuração foi concluída pela Management API. Antes de depender da CLI para novas alterações, diagnostique a rede/certificados ou use a Management API/MCP autenticado.
