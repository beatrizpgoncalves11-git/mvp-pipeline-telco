-- Databricks notebook source
-- MAGIC %md
-- MAGIC # 01 · Camada Bronze — Ingestão dos dados brutos
-- MAGIC
-- MAGIC **Objetivo:** criar a estrutura do Lakehouse (schemas `bronze`, `silver`, `gold`) e carregar o CSV **exatamente como veio da fonte**, apenas adicionando metadados de controle (data de ingestão e fonte).
-- MAGIC
-- MAGIC **Fonte:** Kaggle — *Telco Customer Churn* (dados de exemplo da IBM).
-- MAGIC
-- MAGIC **Ordem de execução:**
-- MAGIC 1. Rodar a célula de criação dos schemas e do volume
-- MAGIC 2. Upload manual do CSV no volume `workspace.bronze.raw_files` (ver célula abaixo)
-- MAGIC 3. Rodar as demais células

-- COMMAND ----------

-- Estrutura de camadas da Arquitetura Medalhão
CREATE SCHEMA IF NOT EXISTS workspace.bronze COMMENT 'Camada Bronze: dados brutos, exatamente como recebidos da fonte, com metadados de ingestão';
CREATE SCHEMA IF NOT EXISTS workspace.silver COMMENT 'Camada Silver: dados limpos, tipados, padronizados e sem duplicatas';
CREATE SCHEMA IF NOT EXISTS workspace.gold   COMMENT 'Camada Gold: modelo estrela (fato e dimensões) pronto para análise';

-- Volume para armazenar o arquivo bruto
CREATE VOLUME IF NOT EXISTS workspace.bronze.raw_files COMMENT 'Arquivos brutos (CSV) enviados manualmente a partir do Kaggle';

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ### Upload do arquivo bruto
-- MAGIC O arquivo CSV do Kaggle foi enviado manualmente pela interface do Databricks
-- MAGIC (Catalog → workspace → bronze → Volumes → raw_files → Upload to this volume)
-- MAGIC e ficou armazenado como `telco_churn.csv.csv`.

-- COMMAND ----------

-- Confirma que o arquivo está no volume
LIST '/Volumes/workspace/bronze/raw_files/';

-- COMMAND ----------

-- Carga Bronze: dado como veio + metadados de controle
CREATE OR REPLACE TABLE workspace.bronze.telco_churn_raw AS
SELECT
  *,
  current_timestamp()                                AS _data_ingestao,
  'Kaggle - Telco Customer Churn (IBM Sample Data)'  AS _fonte
FROM read_files(
  '/Volumes/workspace/bronze/raw_files/telco_churn.csv.csv',
  format => 'csv',
  header => true
);

COMMENT ON TABLE workspace.bronze.telco_churn_raw IS
  'Dados brutos de clientes de uma operadora de telecom (1 linha por cliente), carregados sem alterações a partir do CSV do Kaggle. Colunas _data_ingestao e _fonte adicionadas para rastreabilidade.';

-- COMMAND ----------

-- Verificação da carga: resultado obtido de 7.043 linhas, igual ao arquivo original
SELECT COUNT(*) AS total_linhas FROM workspace.bronze.telco_churn_raw;

-- COMMAND ----------

DESCRIBE TABLE workspace.bronze.telco_churn_raw;

-- COMMAND ----------

SELECT * FROM workspace.bronze.telco_churn_raw LIMIT 10;