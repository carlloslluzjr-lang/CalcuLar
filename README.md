# CalcuLar

Plataforma web responsiva para simulações imobiliárias multiempresa. O navegador acessa o Supabase diretamente usando a chave publicável; autenticação, dados e isolamento entre empresas ficam no Supabase Auth + Postgres/RLS.

## Estado desta entrega

- Landing page pública (`index.html`) e aplicativo separado (`app.html`), com CTAs dos três planos ligados ao cadastro correspondente.
- Interface do aplicativo com identidade CalcuLar, CRM com formulário público de leads, histórico de simulações por cliente, indicadores por corretor, avisos internos e estimativas de ITBI/cartório configuráveis por empresa.
- Simulação de Casa, Imóvel, Terreno, Loteamento e Imóvel comercial.
- SAC, Price, SACOQ Anual 2 crescente mensalmente, SAC/Price corrigidos e método personalizado baseado em SAC.
- Importação de CSV e Excel com prévia, validação e gravação dos perfis por empresa.
- Migrações Supabase com organizações, membros, convites, perfis pessoais editáveis, taxas, empreendimentos, clientes, simulações, propostas, leads e filiais, com RLS e gestão de equipe por papel. As quatro migrações deste projeto foram aplicadas no Supabase hospedado informado pelo proprietário; a estrutura foi conferida no SQL Editor.
- Autenticação Supabase por e-mail e telefone; SMS exige provedor. Login por provedores externos depende de ativar cada provedor nas configurações do Supabase.
- O pacote tem um Supabase local em Docker, com a migração CalcuLar aplicada e contas de demonstração locais. Nenhuma chave administrativa está no navegador.

## Rodar localmente

1. Com Docker Desktop aberto, execute `npm run local:start`. Na primeira vez, ele baixa e inicia o Supabase local e aplica as migrações em `supabase/migrations/`, depois abre o servidor web. Para aplicar uma migração nova a uma instância já iniciada, use `npx supabase migration up --local`.
2. Abra `http://127.0.0.1:8787/` e depois escolha um plano ou clique em **Acessar minha conta**.
3. Para parar o servidor web, use `Ctrl+C` no Terminal. Para parar o banco, execute `npm run db:stop`. Os dados locais ficam nos volumes Docker e persistem entre reinícios.
4. Use as credenciais do arquivo `LOCAL-ACCESS.txt` para entrar como proprietário ou corretor.

A instância local é independente do projeto Supabase hospedado. `supabase-config.js` aponta para localhost; não publique esse arquivo no Site remoto. A referência do projeto hospedado fica em `supabase-config.hosted.example.js`.

## Configurar o Supabase

1. O projeto hospedado já recebeu as migrações base `202611200001_calcular_core.sql` e `202611200002_profile_team_sacoq.sql`, além de `202611210001_internal_features.sql` e `202611210002_branches_reporting.sql`. Em um projeto novo, aplique nessa ordem.
2. Em Authentication, habilite e-mail e os provedores externos que desejar. Login por telefone com código SMS exige provedor e pode gerar cobrança; revise URLs de retorno e confirmação para o domínio final.
3. Copie `supabase-config.hosted.example.js` para `supabase-config.js` apenas depois da migração remota. Use só a chave publicável no navegador; nunca use `service_role`/secret key.
4. O aplicativo precisa usar `supabase-config.js` com a URL e a chave publicável do mesmo projeto. O pacote `dist/` aponta para o projeto hospedado; a configuração local da raiz continua independente.

O formulário de conexão manual do aplicativo é só para prévia local por navegador. A configuração padrão desta pasta usa o banco Supabase em Docker. O diretório `dist/` aponta para o projeto Supabase hospedado. A aplicação das duas migrações novas foi confirmada no Supabase local e remoto.

## Importação de taxas

Use **Baixar modelo CSV** ou uma planilha Excel com colunas compatíveis:

`nome, produto, metodo, juros_aa, indice, indice_aa, vigencia`

Produtos: `casa`, `imovel`, `terreno`, `loteamento`, `comercial`. Métodos: `SAC`, `PRICE`, `SACOQ2`, `SACOQ12`, `SAC_INDEXED`, `PRICE_INDEXED`, `CUSTOM`.

## SACOQ Anual 2

SACOQ Anual 2: parcelas crescem mensalmente pela taxa mensal efetiva informada; o índice escolhido corrige o saldo no início do 13º mês e nos aniversários seguintes, com recálculo das parcelas restantes. `SACOQ12`: os juros mensais ficam acumulados no saldo, sem compor as prestações mensais; no 13º mês e nos ciclos anuais seguintes, são capitalizados junto com o índice escolhido e o saldo é reamortizado pelo prazo restante. No vencimento, a simulação liquida o saldo acumulado. Confira os detalhes de arredondamento e de índice do contrato antes de usar em oferta comercial.

## Limites que ainda dependem de configuração/escopo externo

- Ativação de SMTP/SMS para convites automáticos e revisão das URLs de autenticação no domínio final.
- Termos e política de privacidade finais, revisados pelo responsável da empresa.
- Cobrança recorrente, limites efetivos dos planos e ativação automática após configurar um gateway.
- APIs de consulta de CPF, integração Meta Ads, CRMs/ERPs e envio real de propostas a instituições. As estimativas de ITBI e cartório são informadas pela empresa e precisam de atualização conforme cidade, UF e tabela vigente.
- Auditoria comercial e conferência independente das fórmulas antes de produção.
