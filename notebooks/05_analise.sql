-- Databricks notebook source
-- MAGIC %md
-- MAGIC # 05 · Análise — Respondendo às perguntas de negócio
-- MAGIC
-- MAGIC Todas as consultas usam o modelo estrela da camada Gold.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## P1. Qual a taxa de churn geral e como ela varia por tipo de contrato?

-- COMMAND ----------

SELECT
  COUNT(*)                                   AS clientes,
  SUM(CAST(churn AS INT))                    AS cancelados,
  ROUND(100 * AVG(CAST(churn AS INT)), 1)    AS taxa_churn_pct
FROM workspace.gold.fato_assinaturas;

-- COMMAND ----------

SELECT
  c.tipo_contrato,
  COUNT(*)                                   AS clientes,
  SUM(CAST(f.churn AS INT))                  AS cancelados,
  ROUND(100 * AVG(CAST(f.churn AS INT)), 1)  AS taxa_churn_pct
FROM workspace.gold.fato_assinaturas f
JOIN workspace.gold.dim_contrato c ON f.id_contrato = c.id_contrato
GROUP BY c.tipo_contrato
ORDER BY taxa_churn_pct DESC;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Conclusão P1:** a taxa geral de churn é de 26,5% (1.869 de 7.043 clientes), ou seja,
-- MAGIC cerca de 1 em cada 4 clientes cancelou. O tipo de contrato é o fator mais marcante:
-- MAGIC clientes com contrato mensal cancelam 42,7%, contra 11,3% no anual e apenas 2,8% no
-- MAGIC bienal, uma diferença de cerca de 15 vezes entre o mensal e o bienal. Contratos mais
-- MAGIC longos criam um vínculo que reduz fortemente o cancelamento.
-- MAGIC **Implicação para o negócio:** incentivar a migração do plano mensal para o anual
-- MAGIC (ex.: desconto na mensalidade) tende a ser a ação de retenção com maior potencial.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## P2. Clientes nos primeiros meses de relacionamento cancelam mais?

-- COMMAND ----------

SELECT
  faixa_permanencia,
  COUNT(*)                                 AS clientes,
  SUM(CAST(churn AS INT))                  AS cancelados,
  ROUND(100 * AVG(CAST(churn AS INT)), 1)  AS taxa_churn_pct
FROM workspace.gold.fato_assinaturas
GROUP BY faixa_permanencia
ORDER BY faixa_permanencia;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Conclusão P2:** sim, o risco é muito maior no início do relacionamento. Clientes com
-- MAGIC até 12 meses de casa cancelam 47,4%, e a taxa cai progressivamente (28,7% entre 13 e
-- MAGIC 24 meses; 20,4% entre 25 e 48 meses) até 9,5% entre os clientes com mais de 4 anos.
-- MAGIC O primeiro ano funciona como um "período crítico": quem passa dele tende a permanecer.
-- MAGIC **Implicação para o negócio:** concentrar esforços de retenção nos primeiros meses,
-- MAGIC com acompanhamento no onboarding e contato proativo antes do fim do primeiro ano.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## P3. O método de pagamento está associado ao churn?

-- COMMAND ----------

SELECT
  c.metodo_pagamento,
  COUNT(*)                                   AS clientes,
  ROUND(100 * AVG(CAST(f.churn AS INT)), 1)  AS taxa_churn_pct
FROM workspace.gold.fato_assinaturas f
JOIN workspace.gold.dim_contrato c ON f.id_contrato = c.id_contrato
GROUP BY c.metodo_pagamento
ORDER BY taxa_churn_pct DESC;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Conclusão P3:** o método de pagamento está associado ao churn. Clientes que pagam com
-- MAGIC cheque eletrônico cancelam 45,3%, cerca de 3 vezes mais que os que usam pagamento
-- MAGIC automático (transferência bancária: 16,7%; cartão de crédito: 15,2%). O cheque postal
-- MAGIC fica em uma posição intermediária (19,1%). No pagamento automático, o cliente não
-- MAGIC precisa "decidir pagar" todo mês, o que reduz os momentos em que ele reconsidera o serviço.
-- MAGIC **Implicação para o negócio:** oferecer benefício para quem aderir ao débito automático.
-- MAGIC Importante: a análise mostra associação, não causa. O método de pagamento pode estar
-- MAGIC refletindo outro perfil de cliente (ex.: clientes com contrato mensal).

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## P4. Clientes com serviços de suporte e segurança cancelam menos?
-- MAGIC (Considera apenas clientes com internet, pois os serviços dependem dela.)

-- COMMAND ----------

SELECT
  s.suporte_tecnico,
  s.seguranca_online,
  COUNT(*)                                   AS clientes,
  ROUND(100 * AVG(CAST(f.churn AS INT)), 1)  AS taxa_churn_pct
FROM workspace.gold.fato_assinaturas f
JOIN workspace.gold.dim_servicos s ON f.id_servicos = s.id_servicos
WHERE s.servico_internet <> 'Sem internet'
GROUP BY s.suporte_tecnico, s.seguranca_online
ORDER BY taxa_churn_pct DESC;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Conclusão P4:** sim. Entre os clientes com internet, quem não contrata nenhum dos dois
-- MAGIC serviços apresenta a maior taxa de churn (49,0%), enquanto quem contrata suporte
-- MAGIC técnico e segurança online cancela apenas 9,0%, uma taxa mais de 5 vezes menor.
-- MAGIC Contratar apenas um dos serviços já reduz o churn para cerca de 22% (22,3% só com
-- MAGIC suporte; 21,3% só com segurança). Serviços adicionais aumentam o valor percebido e a
-- MAGIC dependência do cliente em relação à operadora.
-- MAGIC **Implicação para o negócio:** oferecer suporte técnico e segurança online como
-- MAGIC bônus temporário para clientes novos ou em risco, como ferramenta de retenção.

-- COMMAND ----------

-- Complemento: churn por tipo de internet
SELECT
  s.servico_internet,
  COUNT(*)                                   AS clientes,
  ROUND(100 * AVG(CAST(f.churn AS INT)), 1)  AS taxa_churn_pct,
  ROUND(AVG(f.cobranca_mensal), 2)           AS ticket_medio_mensal
FROM workspace.gold.fato_assinaturas f
JOIN workspace.gold.dim_servicos s ON f.id_servicos = s.id_servicos
GROUP BY s.servico_internet
ORDER BY taxa_churn_pct DESC;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Conclusão (complemento P4):** clientes de fibra óptica cancelam 41,9%, mais que o
-- MAGIC dobro dos clientes DSL (19,0%), apesar de ser o serviço mais moderno. O ticket médio
-- MAGIC da fibra é o mais alto (US$ 91,50, contra US$ 58,10 do DSL). Uma hipótese é que o
-- MAGIC preço ou a qualidade percebida não estejam compatíveis com a expectativa do cliente.
-- MAGIC Os dados não permitem confirmar a causa, mas esse é um ponto que merece investigação.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## P5. Quanto de receita mensal é perdida com o churn e em qual segmento ela se concentra?

-- COMMAND ----------

SELECT
  c.tipo_contrato,
  SUM(CASE WHEN f.churn THEN f.cobranca_mensal ELSE 0 END)                     AS receita_mensal_perdida,
  ROUND(100 * SUM(CASE WHEN f.churn THEN f.cobranca_mensal ELSE 0 END)
        / SUM(SUM(CASE WHEN f.churn THEN f.cobranca_mensal ELSE 0 END)) OVER (), 1) AS pct_da_perda_total,
  ROUND(100 * SUM(CASE WHEN f.churn THEN f.cobranca_mensal ELSE 0 END)
        / SUM(f.cobranca_mensal), 1)                                           AS pct_receita_do_segmento
FROM workspace.gold.fato_assinaturas f
JOIN workspace.gold.dim_contrato c ON f.id_contrato = c.id_contrato
GROUP BY c.tipo_contrato
ORDER BY receita_mensal_perdida DESC;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Conclusão P5:** o churn representa uma perda de US$ 139.130,85 em receita mensal.
-- MAGIC Desse total, 86,9% vem dos contratos mensais, que perdem 47,0% da própria receita do
-- MAGIC segmento. Os contratos anual e bienal, juntos, respondem por apenas 13,1% da perda.
-- MAGIC **Implicação para o negócio:** o problema de receita está concentrado em um único
-- MAGIC segmento, o que torna a ação de retenção mais focada e com retorno mais previsível.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Síntese: perfil de maior risco (cruzando P1, P2 e P3)

-- COMMAND ----------

SELECT
  CASE WHEN c.tipo_contrato = 'Mensal'
        AND f.meses_cliente <= 12
        AND c.metodo_pagamento = 'Cheque eletrônico'
       THEN 'Alto risco (mensal + até 12 meses + cheque eletrônico)'
       ELSE 'Demais clientes' END             AS perfil,
  COUNT(*)                                    AS clientes,
  ROUND(100 * AVG(CAST(f.churn AS INT)), 1)   AS taxa_churn_pct,
  SUM(CASE WHEN f.churn THEN f.cobranca_mensal ELSE 0 END) AS receita_mensal_perdida
FROM workspace.gold.fato_assinaturas f
JOIN workspace.gold.dim_contrato c ON f.id_contrato = c.id_contrato
GROUP BY 1
ORDER BY taxa_churn_pct DESC;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Síntese:** cruzando as três variáveis de maior impacto (contrato mensal, até 12 meses
-- MAGIC de permanência e pagamento por cheque eletrônico), identificamos um grupo de 954
-- MAGIC clientes com churn de 63,1%, cerca de 3 vezes a taxa dos demais (20,8%). Esse grupo
-- MAGIC representa apenas 13,5% da base, mas é responsável por US$ 43.703,15 da receita
-- MAGIC mensal perdida, ou seja, 31,4% de toda a perda.
-- MAGIC **Recomendação:** esse perfil deve ser o público prioritário das ações de retenção,
-- MAGIC combinando migração para contrato anual, adesão ao pagamento automático e
-- MAGIC acompanhamento nos primeiros meses.