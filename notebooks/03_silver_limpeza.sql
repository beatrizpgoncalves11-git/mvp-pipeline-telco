-- Databricks notebook source
-- MAGIC %md
-- MAGIC # 03 · Camada Silver — Limpeza e padronização
-- MAGIC
-- MAGIC **Transformações aplicadas (e por quê):**
-- MAGIC
-- MAGIC | # | Transformação | Motivo |
-- MAGIC |---|---|---|
-- MAGIC | 1 | Renomear colunas para português, padrão `snake_case` | Clareza para o time de negócio e padronização |
-- MAGIC | 2 | `TotalCharges` texto → `DECIMAL(10,2)` | Coluna veio como texto por conter valores em branco |
-- MAGIC | 3 | `TotalCharges` vazio → `0.00` + flag `cobranca_total_imputada` | Os 11 casos são clientes com `tenure = 0` (recém-contratados, ainda sem faturamento) |
-- MAGIC | 4 | Colunas Yes/No → `BOOLEAN` | Tipagem correta para filtros e cálculos |
-- MAGIC | 5 | Categorias traduzidas (ex.: `Month-to-month` → `Mensal`) | Padronização de domínio em português |
-- MAGIC | 6 | `SeniorCitizen` 0/1 → `BOOLEAN` | Estava como número, mas representa sim/não |
-- MAGIC | 7 | `TRIM` + `DISTINCT` | Remover espaços e garantir ausência de duplicatas |

-- COMMAND ----------

-- Função auxiliar de tradução das respostas Yes/No/No ... service
CREATE OR REPLACE FUNCTION workspace.silver.fn_traduz_resposta(valor STRING)
RETURNS STRING
COMMENT 'Traduz respostas da base Telco: Yes→Sim, No→Não, No internet service→Sem internet, No phone service→Sem telefone'
RETURN CASE TRIM(valor)
  WHEN 'Yes'                 THEN 'Sim'
  WHEN 'No'                  THEN 'Não'
  WHEN 'No internet service' THEN 'Sem internet'
  WHEN 'No phone service'    THEN 'Sem telefone'
  ELSE TRIM(valor)
END;

-- COMMAND ----------

CREATE OR REPLACE TABLE workspace.silver.clientes_telco AS
SELECT DISTINCT
  TRIM(customerID)                                              AS customer_id,
  CASE TRIM(gender) WHEN 'Male' THEN 'Masculino'
                    WHEN 'Female' THEN 'Feminino' END           AS genero,
  CAST(SeniorCitizen AS INT) = 1                                AS idoso,
  TRIM(Partner) = 'Yes'                                         AS possui_parceiro,
  TRIM(Dependents) = 'Yes'                                      AS possui_dependentes,
  CAST(tenure AS INT)                                           AS meses_cliente,
  TRIM(PhoneService) = 'Yes'                                    AS servico_telefone,
  workspace.silver.fn_traduz_resposta(MultipleLines)            AS multiplas_linhas,
  CASE TRIM(InternetService) WHEN 'DSL' THEN 'DSL'
                             WHEN 'Fiber optic' THEN 'Fibra óptica'
                             WHEN 'No' THEN 'Sem internet' END  AS servico_internet,
  workspace.silver.fn_traduz_resposta(OnlineSecurity)           AS seguranca_online,
  workspace.silver.fn_traduz_resposta(OnlineBackup)             AS backup_online,
  workspace.silver.fn_traduz_resposta(DeviceProtection)         AS protecao_dispositivo,
  workspace.silver.fn_traduz_resposta(TechSupport)              AS suporte_tecnico,
  workspace.silver.fn_traduz_resposta(StreamingTV)              AS streaming_tv,
  workspace.silver.fn_traduz_resposta(StreamingMovies)          AS streaming_filmes,
  CASE TRIM(Contract) WHEN 'Month-to-month' THEN 'Mensal'
                      WHEN 'One year' THEN 'Anual'
                      WHEN 'Two year' THEN 'Bienal' END         AS tipo_contrato,
  TRIM(PaperlessBilling) = 'Yes'                                AS fatura_digital,
  CASE TRIM(PaymentMethod)
       WHEN 'Electronic check'          THEN 'Cheque eletrônico'
       WHEN 'Mailed check'              THEN 'Cheque postal'
       WHEN 'Bank transfer (automatic)' THEN 'Transferência bancária (automática)'
       WHEN 'Credit card (automatic)'   THEN 'Cartão de crédito (automático)' END AS metodo_pagamento,
  CAST(MonthlyCharges AS DECIMAL(10,2))                         AS cobranca_mensal,
  COALESCE(TRY_CAST(NULLIF(TRIM(CAST(TotalCharges AS STRING)), '') AS DECIMAL(10,2)),
           CAST(0 AS DECIMAL(10,2)))                            AS cobranca_total,
  TRY_CAST(NULLIF(TRIM(CAST(TotalCharges AS STRING)), '') AS DECIMAL(10,2)) IS NULL
                                                                AS cobranca_total_imputada,
  TRIM(Churn) = 'Yes'                                           AS churn,
  current_timestamp()                                           AS _data_processamento
FROM workspace.bronze.telco_churn_raw
WHERE customerID IS NOT NULL;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Catálogo de Dados — documentação no Unity Catalog

-- COMMAND ----------

COMMENT ON TABLE workspace.silver.clientes_telco IS
  'Clientes da operadora (1 linha por cliente), limpos e tipados. Origem: workspace.bronze.telco_churn_raw.';

ALTER TABLE workspace.silver.clientes_telco ALTER COLUMN customer_id COMMENT 'Identificador único do cliente. Origem: customerID';
ALTER TABLE workspace.silver.clientes_telco ALTER COLUMN genero COMMENT 'Gênero: Masculino | Feminino. Origem: gender (traduzido)';
ALTER TABLE workspace.silver.clientes_telco ALTER COLUMN idoso COMMENT 'Cliente com 65 anos ou mais. Origem: SeniorCitizen (0/1 → boolean)';
ALTER TABLE workspace.silver.clientes_telco ALTER COLUMN possui_parceiro COMMENT 'Possui cônjuge/parceiro(a). Origem: Partner';
ALTER TABLE workspace.silver.clientes_telco ALTER COLUMN possui_dependentes COMMENT 'Possui dependentes. Origem: Dependents';
ALTER TABLE workspace.silver.clientes_telco ALTER COLUMN meses_cliente COMMENT 'Meses de permanência como cliente (0 a 72). Origem: tenure';
ALTER TABLE workspace.silver.clientes_telco ALTER COLUMN servico_telefone COMMENT 'Possui linha telefônica. Origem: PhoneService';
ALTER TABLE workspace.silver.clientes_telco ALTER COLUMN multiplas_linhas COMMENT 'Sim | Não | Sem telefone. Origem: MultipleLines';
ALTER TABLE workspace.silver.clientes_telco ALTER COLUMN servico_internet COMMENT 'DSL | Fibra óptica | Sem internet. Origem: InternetService';
ALTER TABLE workspace.silver.clientes_telco ALTER COLUMN seguranca_online COMMENT 'Sim | Não | Sem internet. Origem: OnlineSecurity';
ALTER TABLE workspace.silver.clientes_telco ALTER COLUMN backup_online COMMENT 'Sim | Não | Sem internet. Origem: OnlineBackup';
ALTER TABLE workspace.silver.clientes_telco ALTER COLUMN protecao_dispositivo COMMENT 'Sim | Não | Sem internet. Origem: DeviceProtection';
ALTER TABLE workspace.silver.clientes_telco ALTER COLUMN suporte_tecnico COMMENT 'Sim | Não | Sem internet. Origem: TechSupport';
ALTER TABLE workspace.silver.clientes_telco ALTER COLUMN streaming_tv COMMENT 'Sim | Não | Sem internet. Origem: StreamingTV';
ALTER TABLE workspace.silver.clientes_telco ALTER COLUMN streaming_filmes COMMENT 'Sim | Não | Sem internet. Origem: StreamingMovies';
ALTER TABLE workspace.silver.clientes_telco ALTER COLUMN tipo_contrato COMMENT 'Mensal | Anual | Bienal. Origem: Contract';
ALTER TABLE workspace.silver.clientes_telco ALTER COLUMN fatura_digital COMMENT 'Recebe fatura sem papel. Origem: PaperlessBilling';
ALTER TABLE workspace.silver.clientes_telco ALTER COLUMN metodo_pagamento COMMENT 'Cheque eletrônico | Cheque postal | Transferência bancária (automática) | Cartão de crédito (automático). Origem: PaymentMethod';
ALTER TABLE workspace.silver.clientes_telco ALTER COLUMN cobranca_mensal COMMENT 'Valor mensal cobrado (US$). Origem: MonthlyCharges';
ALTER TABLE workspace.silver.clientes_telco ALTER COLUMN cobranca_total COMMENT 'Valor total cobrado desde a contratação (US$). Origem: TotalCharges (vazios → 0)';
ALTER TABLE workspace.silver.clientes_telco ALTER COLUMN cobranca_total_imputada COMMENT 'TRUE quando TotalCharges veio vazio e foi substituído por 0 (clientes com 0 meses)';
ALTER TABLE workspace.silver.clientes_telco ALTER COLUMN churn COMMENT 'Cliente cancelou no último mês. Origem: Churn';
ALTER TABLE workspace.silver.clientes_telco ALTER COLUMN _data_processamento COMMENT 'Data/hora de processamento da camada Silver';

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Validações pós-transformação

-- COMMAND ----------

SELECT
  COUNT(*)                                             AS total_linhas,
  COUNT(DISTINCT customer_id)                          AS clientes_distintos,
  SUM(CASE WHEN cobranca_total IS NULL THEN 1 ELSE 0 END)  AS nulos_cobranca_total,
  SUM(CAST(cobranca_total_imputada AS INT))            AS qtd_imputados,
  SUM(CASE WHEN tipo_contrato IS NULL OR metodo_pagamento IS NULL
            OR servico_internet IS NULL OR genero IS NULL THEN 1 ELSE 0 END) AS categorias_nao_mapeadas
FROM workspace.silver.clientes_telco;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Resultado:** a camada Silver manteve as 7.043 linhas da Bronze, com 7.043 clientes
-- MAGIC distintos (nenhuma duplicata). Após o tratamento, a coluna cobranca_total não tem mais
-- MAGIC nenhum valor nulo, e os 11 registros corrigidos ficaram identificados pela flag
-- MAGIC cobranca_total_imputada. Todas as categorias foram traduzidas corretamente
-- MAGIC (0 valores não mapeados).

-- COMMAND ----------

-- Os registros imputados são todos clientes com 0 meses?
SELECT customer_id, meses_cliente, cobranca_mensal, cobranca_total
FROM workspace.silver.clientes_telco
WHERE cobranca_total_imputada;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Resultado:** confirmado. Os 11 registros imputados têm meses_cliente = 0, ou seja,
-- MAGIC são clientes recém-contratados que ainda não receberam a primeira fatura. Isso
-- MAGIC confirma que substituir o TotalCharges vazio por 0 é coerente com o negócio: esses
-- MAGIC clientes de fato ainda não foram cobrados, embora já tenham um valor mensal definido
-- MAGIC (entre US$ 19,70 e US$ 80,85).