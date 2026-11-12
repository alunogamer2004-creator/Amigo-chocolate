# Amigo Chocolate 🍫

Site de sorteio de Amigo Chocolate para a Irmandade dos Auxiliares Jovem.

- Cada pessoa entra só com o **nome** (sem e-mail e sem senha).
- O sorteio é feito **no servidor**, usando Supabase Auth e PostgreSQL.
- Cada pessoa vê apenas o próprio resultado, numa tela de **caça-níquel**.
- Cada pessoa puxa a alavanca uma vez. Depois, o resultado continua disponível para ela.
- Sem limite de valor para o chocolate.

## Como funciona a privacidade

O resultado fica na tabela `assignments`, sem acesso direto pela Data API. A única forma de descobrir quem tirou é a função `reveal()`, que devolve somente o resultado do usuário autenticado. O organizador acompanha quem já revelou, mas não vê os pares pelo site.

Quem tem acesso administrativo ao projeto Supabase consegue consultar os dados do banco. Para preservar a surpresa, não abra a tabela `assignments` durante o evento.

## 1. Criar e configurar o Supabase

1. Crie um projeto Supabase exclusivo para este sorteio.
2. Em **Authentication > Sign In / Providers**, ative **Anonymous Sign-Ins**.
3. Abra `supabase/schema.sql` em um editor de texto.
4. Antes de executar, substitua `TROQUE-ESTE-CODIGO` por um código forte e exclusivo para o organizador. Não use uma senha que você já utiliza em outros serviços.
5. No Supabase, abra **SQL Editor**, crie uma nova consulta, cole o conteúdo do arquivo e clique em **Run**.
6. Em **Project Settings > API Keys**, copie a **Project URL** e a **Publishable key** (`sb_publishable_...`). Se o painel oferecer apenas a chave legada `anon`, ela também é compatível; nunca use `service_role` ou uma chave `secret` no navegador.

O SQL habilita RLS e concede somente os privilégios necessários à role `authenticated`. Os usuários anônimos criados pelo Supabase Auth usam essa role. As tabelas `config` e `assignments` não ficam acessíveis diretamente pela API.

## 2. Configurar o site

Edite `config.js` e preencha os dois valores:

```js
window.APP_CONFIG = {
  SUPABASE_URL: "https://SEU-PROJETO.supabase.co",
  SUPABASE_PUBLISHABLE_KEY: "sb_publishable_SUA-CHAVE-PUBLICA",
};
```

Não compartilhe chaves `secret` ou `service_role` e não as envie ao GitHub.

## 3. Testar localmente

Abra a pasta do projeto no VS Code e use a extensão **Live Server** para abrir `index.html`. Não é necessário instalar React, Node.js, banco local ou ferramentas de build para executar o site.

Faça o teste com pelo menos três navegadores ou perfis diferentes:

1. Cada participante informa o próprio nome.
2. O organizador entra com o código administrativo.
3. Com pelo menos três inscritos, o organizador inicia o sorteio.
4. Cada participante abre o site, toca duas vezes na alavanca e confere o próprio resultado.
5. O organizador pode liberar uma pessoa para revelar novamente ou reabrir as inscrições (isso apaga o sorteio atual).

## 4. Publicar

### GitHub

```bash
git init
git add .
git commit -m "Amigo Chocolate"
git branch -M main
git remote add origin https://github.com/SEU-USUARIO/amigo-chocolate.git
git push -u origin main
```

### Vercel

1. Entre em https://vercel.com e importe o repositório do GitHub.
2. Escolha **Other** como framework.
3. Não configure comando de build; a pasta do projeto é servida diretamente.
4. Clique em **Deploy**.

## Cuidados importantes

- **Use o mesmo aparelho e navegador.** A identidade anônima fica guardada no navegador. Se a pessoa limpar os dados ou trocar de aparelho, não conseguirá acessar a identidade anterior e o resultado antigo. Nesse caso, o organizador precisará decidir como resolver antes de reiniciar o sorteio.
- Quem entrar depois do sorteio não participa dele.
- Qualquer pessoa com o link pode tentar entrar usando o nome de outra pessoa. Combine com o grupo que cada um deve usar o próprio nome; para uma validação mais forte, será necessário adicionar um código individual ou outro método de identificação.
- O Supabase recomenda CAPTCHA/Turnstile para proteger aplicações com inscrições anônimas contra automação e abuso. Para um evento pequeno, teste primeiro; antes de divulgar publicamente, avalie ativar essa proteção.
- Projetos gratuitos podem pausar após períodos de inatividade. Abra o site antes do evento para conferir se está tudo funcionando.
- Depois do evento, considere excluir contas anônimas que não serão mais utilizadas.

## Estrutura

```text
index.html          site (HTML, CSS e JavaScript)
config.js           URL e chave pública do Supabase
supabase/schema.sql tabelas, RLS, permissões e funções do sorteio
README.md           instruções
```
