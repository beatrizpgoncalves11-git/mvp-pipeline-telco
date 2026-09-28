-- Databricks notebook source
-- MAGIC %md
-- MAGIC # 04 · Camada Gold — Modelo Estrela
-- MAGIC
-- MAGIC ```
-- MAGIC                  dim_cliente
-- MAGIC                      │ customer_id
-- MAGIC                      │
-- MAGIC  dim_contrato ── fato_assinaturas ── dim_servicos
-- MAGIC   id_contrato                        id_servicos
-- MAGIC ```
-- MAGIC
-- MAGIC **Granularidade da fato:** 1 linha por cliente (fotografia da assinatura no momento da extração).
-- MAGIC
-- MAGIC **Chaves das dimensões de contrato e serviços:** chave substituta (*surrogate key*) gerada por `xxhash64` sobre a combinação de atributos. Isso é determinístico: a mesma combinação sempre gera a mesma chave.

-- COMMAND ----------

-- Dimensão Cliente: perfil demográfico
CREATE OR REPLACE TABLE workspace.gold.dim_cliente AS
SELECT customer_id, genero, idoso, possui_parceiro, possui_dependentes
FROM workspace.silver.clientes_telco;

-- COMMAND ----------

-- Dimensão Contrato: condições comerciais (combinações distintas)
CREATE OR REPLACE TABLE workspace.gold.dim_contrato AS
SELECT DISTINCT
  xxhash64(tipo_contrato, fatura_digital, metodo_pagamento) AS id_contrato,
  tipo_contrato,
  fatura_digital,
  metodo_pagamento
FROM workspace.silver.clientes_telco;

-- COMMAND ----------

-- Dimensão Serviços: pacote de serviços contratados (combinações distintas)
CREATE OR REPLACE TABLE workspace.gold.dim_servicos AS
SELECT DISTINCT
  xxhash64(servico_telefone, multiplas_linhas, servico_internet, seguranca_online, backup_online,
           protecao_dispositivo, suporte_tecnico, streaming_tv, streaming_filmes) AS id_servicos,
  servico_telefone, multiplas_linhas, servico_internet, seguranca_online, backup_online,
  protecao_dispositivo, suporte_tecnico, streaming_tv, streaming_filmes
FROM workspace.silver.clientes_telco;

-- COMMAND ----------

-- Fato Assinaturas: métricas por cliente
CREATE OR REPLACE TABLE workspace.gold.fato_assinaturas AS
SELECT
  customer_id,
  xxhash64(tipo_contrato, fatura_digital, metodo_pagamento) AS id_contrato,
  xxhash64(servico_telefone, multiplas_linhas, servico_internet, seguranca_online, backup_online,
           protecao_dispositivo, suporte_tecnico, streaming_tv, streaming_filmes) AS id_servicos,
  meses_cliente,
  CASE WHEN meses_cliente <= 12 THEN '01. 0-12 meses'
       WHEN meses_cliente <= 24 THEN '02. 13-24 meses'
       WHEN meses_cliente <= 48 THEN '03. 25-48 meses'
       ELSE '04. 49-72 meses' END                            AS faixa_permanencia,
  cobranca_mensal,
  cobranca_total,
  churn
FROM workspace.silver.clientes_telco;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Catálogo de Dados (Unity Catalog)

-- COMMAND ----------

COMMENT ON TABLE workspace.gold.dim_cliente IS 'Dimensão com o perfil demográfico de cada cliente. Origem: silver.clientes_telco.';
ALTER TABLE workspace.gold.dim_cliente ALTER COLUMN customer_id COMMENT 'Chave primária. Identificador único do cliente';
ALTER TABLE workspace.gold.dim_cliente ALTER COLUMN genero COMMENT 'Masculino | Feminino';
ALTER TABLE workspace.gold.dim_cliente ALTER COLUMN idoso COMMENT 'TRUE se o cliente tem 65 anos ou mais';
ALTER TABLE workspace.gold.dim_cliente ALTER COLUMN possui_parceiro COMMENT 'TRUE se possui cônjuge/parceiro(a)';
ALTER TABLE workspace.gold.dim_cliente ALTER COLUMN possui_dependentes COMMENT 'TRUE se possui dependentes';

COMMENT ON TABLE workspace.gold.dim_contrato IS 'Dimensão com as combinações de condições comerciais do contrato. Origem: silver.clientes_telco.';
ALTER TABLE workspace.gold.dim_contrato ALTER COLUMN id_contrato COMMENT 'Chave primária substituta: xxhash64(tipo_contrato, fatura_digital, metodo_pagamento)';
ALTER TABLE workspace.gold.dim_contrato ALTER COLUMN tipo_contrato COMMENT 'Mensal | Anual | Bienal';
ALTER TABLE workspace.gold.dim_contrato ALTER COLUMN fatura_digital COMMENT 'TRUE se recebe fatura sem papel';
ALTER TABLE workspace.gold.dim_contrato ALTER COLUMN metodo_pagamento COMMENT 'Cheque eletrônico | Cheque postal | Transferência bancária (automática) | Cartão de crédito (automático)';

COMMENT ON TABLE workspace.gold.dim_servicos IS 'Dimensão com as combinações de serviços contratados. Origem: silver.clientes_telco.';
ALTER TABLE workspace.gold.dim_servicos ALTER COLUMN id_servicos COMMENT 'Chave primária substituta: xxhash64 dos 9 atributos de serviço';
ALTER TABLE workspace.gold.dim_servicos ALTER COLUMN servico_telefone COMMENT 'TRUE se possui linha telefônica';
ALTER TABLE workspace.gold.dim_servicos ALTER COLUMN multiplas_linhas COMMENT 'Sim | Não | Sem telefone';
ALTER TABLE workspace.gold.dim_servicos ALTER COLUMN servico_internet COMMENT 'DSL | Fibra óptica | Sem internet';
ALTER TABLE workspace.gold.dim_servicos ALTER COLUMN seguranca_online COMMENT 'Sim | Não | Sem internet';
ALTER TABLE workspace.gold.dim_servicos ALTER COLUMN backup_online COMMENT 'Sim | Não | Sem internet';
ALTER TABLE workspace.gold.dim_servicos ALTER COLUMN protecao_dispositivo COMMENT 'Sim | Não | Sem internet';
ALTER TABLE workspace.gold.dim_servicos ALTER COLUMN suporte_tecnico COMMENT 'Sim | Não | Sem internet';
ALTER TABLE workspace.gold.dim_servicos ALTER COLUMN streaming_tv COMMENT 'Sim | Não | Sem internet';
ALTER TABLE workspace.gold.dim_servicos ALTER COLUMN streaming_filmes COMMENT 'Sim | Não | Sem internet';

COMMENT ON TABLE workspace.gold.fato_assinaturas IS 'Fato com métricas de assinatura e status de churn. Granularidade: 1 linha por cliente. Origem: silver.clientes_telco.';
ALTER TABLE workspace.gold.fato_assinaturas ALTER COLUMN customer_id COMMENT 'Chave estrangeira → dim_cliente';
ALTER TABLE workspace.gold.fato_assinaturas ALTER COLUMN id_contrato COMMENT 'Chave estrangeira → dim_contrato';
ALTER TABLE workspace.gold.fato_assinaturas ALTER COLUMN id_servicos COMMENT 'Chave estrangeira → dim_servicos';
ALTER TABLE workspace.gold.fato_assinaturas ALTER COLUMN meses_cliente COMMENT 'Meses de permanência (0 a 72)';
ALTER TABLE workspace.gold.fato_assinaturas ALTER COLUMN faixa_permanencia COMMENT 'Derivada de meses_cliente: 0-12 | 13-24 | 25-48 | 49-72 meses';
ALTER TABLE workspace.gold.fato_assinaturas ALTER COLUMN cobranca_mensal COMMENT 'Valor mensal cobrado (US$)';
ALTER TABLE workspace.gold.fato_assinaturas ALTER COLUMN cobranca_total COMMENT 'Valor total cobrado desde a contratação (US$)';
ALTER TABLE workspace.gold.fato_assinaturas ALTER COLUMN churn COMMENT 'TRUE se o cliente cancelou';

-- COMMAND ----------

-- MAGIC %md
-- MAGIC ## Validação de integridade do modelo

-- COMMAND ----------

SELECT
  (SELECT COUNT(*) FROM workspace.gold.fato_assinaturas) AS linhas_fato,
  (SELECT COUNT(*) FROM workspace.gold.dim_cliente)      AS linhas_dim_cliente,
  (SELECT COUNT(*) FROM workspace.gold.dim_contrato)     AS linhas_dim_contrato,
  (SELECT COUNT(*) FROM workspace.gold.dim_servicos)     AS linhas_dim_servicos,
  (SELECT COUNT(*) FROM workspace.gold.fato_assinaturas f
     LEFT JOIN workspace.gold.dim_contrato c ON f.id_contrato = c.id_contrato
     WHERE c.id_contrato IS NULL)                         AS orfaos_contrato,
  (SELECT COUNT(*) FROM workspace.gold.fato_assinaturas f
     LEFT JOIN workspace.gold.dim_servicos s ON f.id_servicos = s.id_servicos
     WHERE s.id_servicos IS NULL)                         AS orfaos_servicos;

-- COMMAND ----------

-- MAGIC %md
-- MAGIC **Resultado:** a tabela fato e a dim_cliente têm 7.043
-- MAGIC  linhas cada, e não há registros
-- MAGIC órfãos. O modelo está íntegro.