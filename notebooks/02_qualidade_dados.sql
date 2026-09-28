-- Databricks notebook source
-- MAGIC %md
-- MAGIC # 02 · Qualidade dos Dados (diagnóstico na camada Bronze)
-- MAGIC
-- MAGIC Antes de transformar, verifica-se **cada atributo** do dado bruto quanto a:
-- MAGIC **Completude · Unicidade · Consistência (domínio) · Acurácia · Outliers**.
-- MAGIC
-- MAGIC Os problemas encontrados aqui orientam as transformações do notebook 03 (Silver).

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 1. Completude — valores nulos ou vazios por coluna

-- COMMAND ----------

SELECT
  coluna,
  SUM(CASE WHEN valor IS NULL OR TRIM(valor) = '' THEN 1 ELSE 0 END)                         AS qtd_nulos_ou_vazios,
  ROUND(100 * SUM(CASE WHEN valor IS NULL OR TRIM(valor) = '' THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct
FROM (
  SELECT
    CAST(customerID AS STRING) AS customerID, CAST(gender AS STRING) AS gender,
    CAST(SeniorCitizen AS STRING) AS SeniorCitizen, CAST(Partner AS STRING) AS Partner,
    CAST(Dependents AS STRING) AS Dependents, CAST(tenure AS STRING) AS tenure,
    CAST(PhoneService AS STRING) AS PhoneService, CAST(MultipleLines AS STRING) AS MultipleLines,
    CAST(InternetService AS STRING) AS InternetService, CAST(OnlineSecurity AS STRING) AS OnlineSecurity,
    CAST(OnlineBackup AS STRING) AS OnlineBackup, CAST(DeviceProtection AS STRING) AS DeviceProtection,
    CAST(TechSupport AS STRING) AS TechSupport, CAST(StreamingTV AS STRING) AS StreamingTV,
    CAST(StreamingMovies AS STRING) AS StreamingMovies, CAST(Contract AS STRING) AS Contract,
    CAST(PaperlessBilling AS STRING) AS PaperlessBilling, CAST(PaymentMethod AS STRING) AS PaymentMethod,
    CAST(MonthlyCharges AS STRING) AS MonthlyCharges, CAST(TotalCharges AS STRING) AS TotalCharges,
    CAST(Churn AS STRING) AS Churn
  FROM workspace.bronze.telco_churn_raw
)
UNPIVOT INCLUDE NULLS (valor FOR coluna IN (
  customerID, gender, SeniorCitizen, Partner, Dependents, tenure, PhoneService, MultipleLines,
  InternetService, OnlineSecurity, OnlineBackup, DeviceProtection, TechSupport, StreamingTV,
  StreamingMovies, Contract, PaperlessBilling, PaymentMethod, MonthlyCharges, TotalCharges, Churn
))
GROUP BY coluna
ORDER BY qtd_nulos_ou_vazios DESC;

-- COMMAND ----------

-- Investigação: quem são os registros com TotalCharges vazio?
SELECT customerID, tenure, MonthlyCharges, TotalCharges, Contract
FROM workspace.bronze.telco_churn_raw
WHERE TotalCharges IS NULL OR TRIM(CAST(TotalCharges AS STRING)) = '';

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Resultado:** apenas a coluna TotalCharges apresentou valores vazios (11 registros,
-- MAGIC 0,16% da base). Todos correspondem a clientes com tenure = 0, ou seja, recém-contratados
-- MAGIC que ainda não foram faturados. Um detalhe reforça essa leitura: 10 desses 11 clientes
-- MAGIC têm contrato bienal e 1 tem contrato anual, o que indica contratos já assinados, mas
-- MAGIC cuja primeira cobrança ainda não aconteceu.
-- MAGIC **Decisão:** substituir o valor vazio por 0 na camada Silver e sinalizar esses registros
-- MAGIC com a flag cobranca_total_imputada. Remover as linhas não foi considerado, para não
-- MAGIC perder clientes válidos da base.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 2. Unicidade — duplicatas

-- COMMAND ----------

SELECT
  COUNT(*)                   AS total_linhas,
  COUNT(DISTINCT customerID) AS clientes_distintos,
  COUNT(*) - COUNT(DISTINCT customerID) AS duplicatas_customer_id
FROM workspace.bronze.telco_churn_raw;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Resultado:** nenhuma duplicata encontrada. A base tem 7.043 linhas e 7.043 valores
-- MAGIC distintos de customerID, o que confirma que cada linha representa um único cliente.
-- MAGIC Mesmo assim, a camada Silver aplica DISTINCT como medida preventiva, caso novas cargas
-- MAGIC tragam registros repetidos.

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 3. Consistência — domínio de valores das colunas categóricas

-- COMMAND ----------

SELECT
  coluna,
  COUNT(DISTINCT valor)            AS qtd_valores_distintos,
  array_sort(collect_set(valor))   AS valores_encontrados
FROM (
  SELECT
    CAST(gender AS STRING) AS gender, CAST(SeniorCitizen AS STRING) AS SeniorCitizen,
    CAST(Partner AS STRING) AS Partner, CAST(Dependents AS STRING) AS Dependents,
    CAST(PhoneService AS STRING) AS PhoneService, CAST(MultipleLines AS STRING) AS MultipleLines,
    CAST(InternetService AS STRING) AS InternetService, CAST(OnlineSecurity AS STRING) AS OnlineSecurity,
    CAST(OnlineBackup AS STRING) AS OnlineBackup, CAST(DeviceProtection AS STRING) AS DeviceProtection,
    CAST(TechSupport AS STRING) AS TechSupport, CAST(StreamingTV AS STRING) AS StreamingTV,
    CAST(StreamingMovies AS STRING) AS StreamingMovies, CAST(Contract AS STRING) AS Contract,
    CAST(PaperlessBilling AS STRING) AS PaperlessBilling, CAST(PaymentMethod AS STRING) AS PaymentMethod,
    CAST(Churn AS STRING) AS Churn
  FROM workspace.bronze.telco_churn_raw
)
UNPIVOT (valor FOR coluna IN (
  gender, SeniorCitizen, Partner, Dependents, PhoneService, MultipleLines, InternetService,
  OnlineSecurity, OnlineBackup, DeviceProtection, TechSupport, StreamingTV, StreamingMovies,
  Contract, PaperlessBilling, PaymentMethod, Churn
))
GROUP BY coluna
ORDER BY coluna;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Resultado:** as 17 colunas categóricas apresentam entre 2 e 4 valores distintos cada,
-- MAGIC todos dentro do esperado. Não foram encontradas variações de escrita (como "yes", "YES"
-- MAGIC ou espaços extras) que representassem a mesma categoria de formas diferentes.
-- MAGIC Três pontos foram tratados na camada Silver:
-- MAGIC - As categorias "No internet service" e "No phone service" não são erros: indicam que
-- MAGIC   o cliente não possui o serviço base. Foram mantidas como categorias próprias
-- MAGIC   ("Sem internet" e "Sem telefone").
-- MAGIC - A coluna SeniorCitizen usa 0/1, enquanto as demais colunas de sim/não usam "Yes"/"No".
-- MAGIC   Para padronizar, todas foram convertidas para o tipo booleano.
-- MAGIC - Todos os valores foram traduzidos para português (ex.: "Month-to-month" → "Mensal").

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 4. Acurácia — valores numéricos fazem sentido?

-- COMMAND ----------

SELECT
  MIN(TRY_CAST(tenure AS INT))            AS tenure_min,
  MAX(TRY_CAST(tenure AS INT))            AS tenure_max,
  MIN(TRY_CAST(MonthlyCharges AS DOUBLE)) AS mensal_min,
  MAX(TRY_CAST(MonthlyCharges AS DOUBLE)) AS mensal_max,
  MIN(TRY_CAST(TotalCharges AS DOUBLE))   AS total_min,
  MAX(TRY_CAST(TotalCharges AS DOUBLE))   AS total_max,
  SUM(CASE WHEN TRY_CAST(tenure AS INT) < 0 THEN 1 ELSE 0 END)                AS tenure_negativo,
  SUM(CASE WHEN TRY_CAST(MonthlyCharges AS DOUBLE) <= 0 THEN 1 ELSE 0 END)    AS mensal_zero_ou_negativo
FROM workspace.bronze.telco_churn_raw;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## 5. Outliers — método IQR (intervalo interquartil)
-- MAGIC Valores abaixo de Q1 − 1,5×IQR ou acima de Q3 + 1,5×IQR são considerados outliers.

-- COMMAND ----------

WITH v AS (
  SELECT coluna, valor
  FROM (
    SELECT
      TRY_CAST(tenure AS DOUBLE)         AS tenure,
      TRY_CAST(MonthlyCharges AS DOUBLE) AS MonthlyCharges,
      TRY_CAST(TotalCharges AS DOUBLE)   AS TotalCharges
    FROM workspace.bronze.telco_churn_raw
  )
  UNPIVOT (valor FOR coluna IN (tenure, MonthlyCharges, TotalCharges))
),
lim AS (
  SELECT coluna,
         percentile_approx(valor, 0.25) AS q1,
         percentile_approx(valor, 0.75) AS q3
  FROM v GROUP BY coluna
)
SELECT
  l.coluna, l.q1, l.q3,
  l.q1 - 1.5 * (l.q3 - l.q1) AS limite_inferior,
  l.q3 + 1.5 * (l.q3 - l.q1) AS limite_superior,
  MIN(v.valor) AS minimo,
  MAX(v.valor) AS maximo,
  SUM(CASE WHEN v.valor < l.q1 - 1.5 * (l.q3 - l.q1)
             OR v.valor > l.q3 + 1.5 * (l.q3 - l.q1) THEN 1 ELSE 0 END) AS qtd_outliers
FROM lim l
JOIN v ON v.coluna = l.coluna
GROUP BY l.coluna, l.q1, l.q3;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Resultado:** tenure entre 0 e 72 meses, cobrança mensal entre US$ 18,25 e US$ 118,75
-- MAGIC e cobrança total entre US$ 18,80 e US$ 8.684,80, faixas coerentes com o negócio de
-- MAGIC telecom. O valor mínimo de tenure = 0 não é um erro: corresponde aos 11 clientes
-- MAGIC recém-contratados identificados na análise de completude.
-- MAGIC O método IQR identificou 0 outliers nas três colunas numéricas. Os limites inferiores
-- MAGIC calculados ficaram negativos, o que é esperado, já que nenhuma dessas medidas pode
-- MAGIC assumir valores abaixo de zero. Portanto, não foi necessário nenhum tratamento de
-- MAGIC valores extremos.