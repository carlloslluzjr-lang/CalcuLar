# CalcuLar

Plataforma web responsiva para simulações imobiliárias multiempresa. O navegador acessa o Supabase usando uma chave publicável; autenticação, dados e isolamento entre empresas ficam no Supabase Auth + Postgres/RLS.

## Estado desta entrega

- Landing page em index.html e aplicativo em app.html, com os três planos ligados ao cadastro.
- Interface para operação, simulações, clientes, propostas, taxas, empreendimentos, equipe, configurações e planos.
- Simulação de Casa, Imóvel, Terreno, Loteamento e Imóvel comercial.
- SAC, Price, SACOQ Anual 2 crescente mensalmente, SACOQ anual com acumulado em 12 meses, SAC/Price corrigidos e método personalizado baseado em SAC.
- Importação de CSV e Excel com prévia, validação e gravação dos perfis por empresa.
- Migrações Supabase para empresas, membros, convites, perfis pessoais, taxas, empreendimentos, clientes, simulações e propostas, com RLS e gestão de equipe por papel.
- Autenticação por e-mail/senha e telefone/SMS via Supabase Auth.

## Rodar localmente

1. Com Docker Desktop aberto, execute npm run local:start. O comando inicia o Supabase local e o servidor web.
2. Abra http://127.0.0.1:8787/ e escolha um plano ou clique em Acessar minha conta.
3. Para parar o servidor web, use Ctrl+C. Para parar o banco, execute npm run db:stop.
4. As credenciais de demonstração ficam no arquivo local ignorado LOCAL-ACCESS.txt.

A instância local é independente do projeto Supabase hospedado. A configuração local aponta para localhost; não publique credenciais locais.

## Configurar o Supabase hospedado

1. No SQL Editor do projeto hospedado, aplique em ordem as migrações supabase/migrations/202611200001_calcular_core.sql e supabase/migrations/202611200002_profile_team_sacoq.sql.
2. Habilite e-mail e telefone em Authentication. Para SMS, configure um provedor e revise as URLs de retorno.
3. Configure supabase-config.js com a URL do projeto e somente a chave publicável. Nunca use uma chave secret ou service_role no navegador.

## Importação de taxas

Colunas compatíveis: nome, produto, metodo, juros_aa, indice, indice_aa, vigencia.

Produtos: casa, imovel, terreno, loteamento, comercial. Métodos: SAC, PRICE, SACOQ2, SACOQ12, SAC_INDEXED, PRICE_INDEXED, CUSTOM.

## Métodos SACOQ

SACOQ Anual 2: parcelas crescem mensalmente pela taxa mensal efetiva informada; o índice escolhido corrige o saldo no 13º mês e nos aniversários seguintes, com recálculo das parcelas restantes. SACOQ12: juros mensais acumulados no saldo, sem cobrança mensal nas prestações; no 13º mês e nos ciclos anuais seguintes, são capitalizados com o índice e o saldo é reamortizado pelo prazo restante. A simulação liquida o saldo acumulado no vencimento. Confira os detalhes do contrato antes de usar em oferta comercial.

## Limites atuais

- Cobrança recorrente e ativação automática de planos dependem de configurar um gateway.
- Integrações de consulta de CPF, Meta Ads, CRMs, ERPs, cartórios, ITBI e instituições financeiras ainda dependem de projeto e contratos.
- As fórmulas de financiamento precisam de auditoria independente antes do uso comercial.
