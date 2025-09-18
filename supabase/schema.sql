-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.annotation_tag_entity (
  id character varying NOT NULL,
  name character varying NOT NULL,
  createdAt timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updatedAt timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  CONSTRAINT annotation_tag_entity_pkey PRIMARY KEY (id)
);
CREATE TABLE public.auth_identity (
  userId uuid,
  providerId character varying NOT NULL,
  providerType character varying NOT NULL,
  createdAt timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updatedAt timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  CONSTRAINT auth_identity_pkey PRIMARY KEY (providerType, providerId),
  CONSTRAINT auth_identity_userId_fkey FOREIGN KEY (userId) REFERENCES public.user(id)
);
CREATE TABLE public.auth_provider_sync_history (
  id integer NOT NULL DEFAULT nextval('auth_provider_sync_history_id_seq'::regclass),
  providerType character varying NOT NULL,
  runMode text NOT NULL,
  status text NOT NULL,
  startedAt timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
  endedAt timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
  scanned integer NOT NULL,
  created integer NOT NULL,
  updated integer NOT NULL,
  disabled integer NOT NULL,
  error text,
  CONSTRAINT auth_provider_sync_history_pkey PRIMARY KEY (id)
);
CREATE TABLE public.credentials_entity (
  name character varying NOT NULL,
  data text NOT NULL,
  type character varying NOT NULL,
  createdAt timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updatedAt timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  id character varying NOT NULL,
  isManaged boolean NOT NULL DEFAULT false,
  CONSTRAINT credentials_entity_pkey PRIMARY KEY (id)
);
CREATE TABLE public.data_store (
  id character varying NOT NULL,
  name character varying NOT NULL,
  projectId character varying NOT NULL,
  sizeBytes integer NOT NULL DEFAULT 0,
  createdAt timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updatedAt timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  CONSTRAINT data_store_pkey PRIMARY KEY (id),
  CONSTRAINT FK_74fdb2d31889a91da14bb711b35 FOREIGN KEY (projectId) REFERENCES public.project(id)
);
CREATE TABLE public.data_store_column (
  id character varying NOT NULL,
  name character varying NOT NULL,
  type character varying NOT NULL,
  index integer NOT NULL,
  dataStoreId character varying NOT NULL,
  createdAt timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updatedAt timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  CONSTRAINT data_store_column_pkey PRIMARY KEY (id),
  CONSTRAINT FK_07172caded772d9c9d1a96d8317 FOREIGN KEY (dataStoreId) REFERENCES public.data_store(id)
);
CREATE TABLE public.event_destinations (
  id uuid NOT NULL,
  destination jsonb NOT NULL,
  createdAt timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updatedAt timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  CONSTRAINT event_destinations_pkey PRIMARY KEY (id)
);
CREATE TABLE public.execution_annotation_tags (
  annotationId integer NOT NULL,
  tagId character varying NOT NULL,
  CONSTRAINT execution_annotation_tags_pkey PRIMARY KEY (tagId, annotationId),
  CONSTRAINT FK_a3697779b366e131b2bbdae2976 FOREIGN KEY (tagId) REFERENCES public.annotation_tag_entity(id),
  CONSTRAINT FK_c1519757391996eb06064f0e7c8 FOREIGN KEY (annotationId) REFERENCES public.execution_annotations(id)
);
CREATE TABLE public.execution_annotations (
  id integer NOT NULL DEFAULT nextval('execution_annotations_id_seq'::regclass),
  executionId integer NOT NULL,
  vote character varying,
  note text,
  createdAt timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updatedAt timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  CONSTRAINT execution_annotations_pkey PRIMARY KEY (id),
  CONSTRAINT FK_97f863fa83c4786f19565084960 FOREIGN KEY (executionId) REFERENCES public.execution_entity(id)
);
CREATE TABLE public.execution_data (
  executionId integer NOT NULL,
  workflowData json NOT NULL,
  data text NOT NULL,
  CONSTRAINT execution_data_pkey PRIMARY KEY (executionId),
  CONSTRAINT execution_data_fk FOREIGN KEY (executionId) REFERENCES public.execution_entity(id)
);
CREATE TABLE public.execution_entity (
  id integer NOT NULL DEFAULT nextval('execution_entity_id_seq'::regclass),
  finished boolean NOT NULL,
  mode character varying NOT NULL,
  retryOf character varying,
  retrySuccessId character varying,
  startedAt timestamp with time zone,
  stoppedAt timestamp with time zone,
  waitTill timestamp with time zone,
  status character varying NOT NULL,
  workflowId character varying NOT NULL,
  deletedAt timestamp with time zone,
  createdAt timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  CONSTRAINT execution_entity_pkey PRIMARY KEY (id),
  CONSTRAINT fk_execution_entity_workflow_id FOREIGN KEY (workflowId) REFERENCES public.workflow_entity(id)
);
CREATE TABLE public.execution_metadata (
  id integer NOT NULL DEFAULT nextval('execution_metadata_temp_id_seq'::regclass),
  executionId integer NOT NULL,
  key character varying NOT NULL,
  value text NOT NULL,
  CONSTRAINT execution_metadata_pkey PRIMARY KEY (id),
  CONSTRAINT FK_31d0b4c93fb85ced26f6005cda3 FOREIGN KEY (executionId) REFERENCES public.execution_entity(id)
);
CREATE TABLE public.folder (
  id character varying NOT NULL,
  name character varying NOT NULL,
  parentFolderId character varying,
  projectId character varying NOT NULL,
  createdAt timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updatedAt timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  CONSTRAINT folder_pkey PRIMARY KEY (id),
  CONSTRAINT FK_804ea52f6729e3940498bd54d78 FOREIGN KEY (parentFolderId) REFERENCES public.folder(id),
  CONSTRAINT FK_a8260b0b36939c6247f385b8221 FOREIGN KEY (projectId) REFERENCES public.project(id)
);
CREATE TABLE public.folder_tag (
  folderId character varying NOT NULL,
  tagId character varying NOT NULL,
  CONSTRAINT folder_tag_pkey PRIMARY KEY (tagId, folderId),
  CONSTRAINT FK_94a60854e06f2897b2e0d39edba FOREIGN KEY (folderId) REFERENCES public.folder(id),
  CONSTRAINT FK_dc88164176283de80af47621746 FOREIGN KEY (tagId) REFERENCES public.tag_entity(id)
);
CREATE TABLE public.insights_by_period (
  id integer GENERATED ALWAYS AS IDENTITY NOT NULL,
  metaId integer NOT NULL,
  type integer NOT NULL,
  value integer NOT NULL,
  periodUnit integer NOT NULL,
  periodStart timestamp with time zone DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT insights_by_period_pkey PRIMARY KEY (id),
  CONSTRAINT FK_6414cfed98daabbfdd61a1cfbc0 FOREIGN KEY (metaId) REFERENCES public.insights_metadata(metaId)
);
CREATE TABLE public.insights_metadata (
  metaId integer GENERATED ALWAYS AS IDENTITY NOT NULL,
  workflowId character varying,
  projectId character varying,
  workflowName character varying NOT NULL,
  projectName character varying NOT NULL,
  CONSTRAINT insights_metadata_pkey PRIMARY KEY (metaId),
  CONSTRAINT FK_1d8ab99d5861c9388d2dc1cf733 FOREIGN KEY (workflowId) REFERENCES public.workflow_entity(id),
  CONSTRAINT FK_2375a1eda085adb16b24615b69c FOREIGN KEY (projectId) REFERENCES public.project(id)
);
CREATE TABLE public.insights_raw (
  id integer GENERATED ALWAYS AS IDENTITY NOT NULL,
  metaId integer NOT NULL,
  type integer NOT NULL,
  value integer NOT NULL,
  timestamp timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT insights_raw_pkey PRIMARY KEY (id),
  CONSTRAINT FK_6e2e33741adef2a7c5d66befa4e FOREIGN KEY (metaId) REFERENCES public.insights_metadata(metaId)
);
CREATE TABLE public.installed_nodes (
  name character varying NOT NULL,
  type character varying NOT NULL,
  latestVersion integer NOT NULL DEFAULT 1,
  package character varying NOT NULL,
  CONSTRAINT installed_nodes_pkey PRIMARY KEY (name),
  CONSTRAINT FK_73f857fc5dce682cef8a99c11dbddbc969618951 FOREIGN KEY (package) REFERENCES public.installed_packages(packageName)
);
CREATE TABLE public.installed_packages (
  packageName character varying NOT NULL,
  installedVersion character varying NOT NULL,
  authorName character varying,
  authorEmail character varying,
  createdAt timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updatedAt timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  CONSTRAINT installed_packages_pkey PRIMARY KEY (packageName)
);
CREATE TABLE public.invalid_auth_token (
  token character varying NOT NULL,
  expiresAt timestamp with time zone NOT NULL,
  CONSTRAINT invalid_auth_token_pkey PRIMARY KEY (token)
);
CREATE TABLE public.knowledge.embeddings (
  knowledge.embeddings ( text NOT NULL,
  CONSTRAINT knowledge.embeddings_pkey PRIMARY KEY (knowledge.embeddings ()
);
CREATE TABLE public.migrations (
  id integer NOT NULL DEFAULT nextval('migrations_id_seq'::regclass),
  timestamp bigint NOT NULL,
  name character varying NOT NULL,
  CONSTRAINT migrations_pkey PRIMARY KEY (id)
);
CREATE TABLE public.processed_data (
  workflowId character varying NOT NULL,
  context character varying NOT NULL,
  createdAt timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updatedAt timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  value text NOT NULL,
  CONSTRAINT processed_data_pkey PRIMARY KEY (workflowId, context),
  CONSTRAINT FK_06a69a7032c97a763c2c7599464 FOREIGN KEY (workflowId) REFERENCES public.workflow_entity(id)
);
CREATE TABLE public.project (
  id character varying NOT NULL,
  name character varying NOT NULL,
  type character varying NOT NULL,
  createdAt timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updatedAt timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  icon json,
  description character varying,
  CONSTRAINT project_pkey PRIMARY KEY (id)
);
CREATE TABLE public.project_relation (
  projectId character varying NOT NULL,
  userId uuid NOT NULL,
  role character varying NOT NULL,
  createdAt timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updatedAt timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  CONSTRAINT project_relation_pkey PRIMARY KEY (projectId, userId),
  CONSTRAINT FK_5f0643f6717905a05164090dde7 FOREIGN KEY (userId) REFERENCES public.user(id),
  CONSTRAINT FK_61448d56d61802b5dfde5cdb002 FOREIGN KEY (projectId) REFERENCES public.project(id)
);
CREATE TABLE public.role (
  slug character varying NOT NULL,
  displayName text,
  description text,
  roleType text,
  systemRole boolean NOT NULL DEFAULT false,
  CONSTRAINT role_pkey PRIMARY KEY (slug)
);
CREATE TABLE public.role_scope (
  roleSlug character varying NOT NULL,
  scopeSlug character varying NOT NULL,
  CONSTRAINT role_scope_pkey PRIMARY KEY (roleSlug, scopeSlug),
  CONSTRAINT FK_role FOREIGN KEY (roleSlug) REFERENCES public.role(slug),
  CONSTRAINT FK_scope FOREIGN KEY (scopeSlug) REFERENCES public.scope(slug)
);
CREATE TABLE public.scope (
  slug character varying NOT NULL,
  displayName text,
  description text,
  CONSTRAINT scope_pkey PRIMARY KEY (slug)
);
CREATE TABLE public.settings (
  key character varying NOT NULL,
  value text NOT NULL,
  loadOnStartup boolean NOT NULL DEFAULT false,
  CONSTRAINT settings_pkey PRIMARY KEY (key)
);
CREATE TABLE public.shared_credentials (
  credentialsId character varying NOT NULL,
  projectId character varying NOT NULL,
  role text NOT NULL,
  createdAt timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updatedAt timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  CONSTRAINT shared_credentials_pkey PRIMARY KEY (projectId, credentialsId),
  CONSTRAINT FK_416f66fc846c7c442970c094ccf FOREIGN KEY (credentialsId) REFERENCES public.credentials_entity(id),
  CONSTRAINT FK_812c2852270da1247756e77f5a4 FOREIGN KEY (projectId) REFERENCES public.project(id)
);
CREATE TABLE public.shared_workflow (
  workflowId character varying NOT NULL,
  projectId character varying NOT NULL,
  role text NOT NULL,
  createdAt timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updatedAt timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  CONSTRAINT shared_workflow_pkey PRIMARY KEY (workflowId, projectId),
  CONSTRAINT FK_a45ea5f27bcfdc21af9b4188560 FOREIGN KEY (projectId) REFERENCES public.project(id),
  CONSTRAINT FK_daa206a04983d47d0a9c34649ce FOREIGN KEY (workflowId) REFERENCES public.workflow_entity(id)
);
CREATE TABLE public.tag_entity (
  name character varying NOT NULL,
  createdAt timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updatedAt timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  id character varying NOT NULL,
  CONSTRAINT tag_entity_pkey PRIMARY KEY (id)
);
CREATE TABLE public.test_case_execution (
  id character varying NOT NULL,
  testRunId character varying NOT NULL,
  executionId integer,
  status character varying NOT NULL,
  runAt timestamp with time zone,
  completedAt timestamp with time zone,
  errorCode character varying,
  errorDetails json,
  metrics json,
  createdAt timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updatedAt timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  inputs json,
  outputs json,
  CONSTRAINT test_case_execution_pkey PRIMARY KEY (id),
  CONSTRAINT FK_8e4b4774db42f1e6dda3452b2af FOREIGN KEY (testRunId) REFERENCES public.test_run(id),
  CONSTRAINT FK_e48965fac35d0f5b9e7f51d8c44 FOREIGN KEY (executionId) REFERENCES public.execution_entity(id)
);
CREATE TABLE public.test_run (
  id character varying NOT NULL,
  workflowId character varying NOT NULL,
  status character varying NOT NULL,
  errorCode character varying,
  errorDetails json,
  runAt timestamp with time zone,
  completedAt timestamp with time zone,
  metrics json,
  createdAt timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updatedAt timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  CONSTRAINT test_run_pkey PRIMARY KEY (id),
  CONSTRAINT FK_d6870d3b6e4c185d33926f423c8 FOREIGN KEY (workflowId) REFERENCES public.workflow_entity(id)
);
CREATE TABLE public.user (
  id uuid NOT NULL DEFAULT uuid_in((OVERLAY(OVERLAY(md5((((random())::text || ':'::text) || (clock_timestamp())::text)) PLACING '4'::text FROM 13) PLACING to_hex((floor(((random() * (((11 - 8) + 1))::double precision) + (8)::double precision)))::integer) FROM 17))::cstring),
  email character varying UNIQUE,
  firstName character varying,
  lastName character varying,
  password character varying,
  personalizationAnswers json,
  createdAt timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updatedAt timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  settings json,
  disabled boolean NOT NULL DEFAULT false,
  mfaEnabled boolean NOT NULL DEFAULT false,
  mfaSecret text,
  mfaRecoveryCodes text,
  role text NOT NULL,
  lastActiveAt date,
  roleSlug character varying NOT NULL DEFAULT 'global:member'::character varying,
  CONSTRAINT user_pkey PRIMARY KEY (id),
  CONSTRAINT FK_eaea92ee7bfb9c1b6cd01505d56 FOREIGN KEY (roleSlug) REFERENCES public.role(slug)
);
CREATE TABLE public.user_api_keys (
  id character varying NOT NULL,
  userId uuid NOT NULL,
  label character varying NOT NULL,
  apiKey character varying NOT NULL,
  createdAt timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updatedAt timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  scopes json,
  CONSTRAINT user_api_keys_pkey PRIMARY KEY (id),
  CONSTRAINT FK_e131705cbbc8fb589889b02d457 FOREIGN KEY (userId) REFERENCES public.user(id)
);
CREATE TABLE public.variables (
  key character varying NOT NULL UNIQUE,
  type character varying NOT NULL DEFAULT 'string'::character varying,
  value character varying,
  id character varying NOT NULL,
  CONSTRAINT variables_pkey PRIMARY KEY (id)
);
CREATE TABLE public.webhook_entity (
  webhookPath character varying NOT NULL,
  method character varying NOT NULL,
  node character varying NOT NULL,
  webhookId character varying,
  pathLength integer,
  workflowId character varying NOT NULL,
  CONSTRAINT webhook_entity_pkey PRIMARY KEY (method, webhookPath),
  CONSTRAINT fk_webhook_entity_workflow_id FOREIGN KEY (workflowId) REFERENCES public.workflow_entity(id)
);
CREATE TABLE public.workflow_entity (
  name character varying NOT NULL,
  active boolean NOT NULL,
  nodes json NOT NULL,
  connections json NOT NULL,
  createdAt timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updatedAt timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  settings json,
  staticData json,
  pinData json,
  versionId character,
  triggerCount integer NOT NULL DEFAULT 0,
  id character varying NOT NULL,
  meta json,
  parentFolderId character varying DEFAULT NULL::character varying,
  isArchived boolean NOT NULL DEFAULT false,
  CONSTRAINT workflow_entity_pkey PRIMARY KEY (id),
  CONSTRAINT fk_workflow_parent_folder FOREIGN KEY (parentFolderId) REFERENCES public.folder(id)
);
CREATE TABLE public.workflow_history (
  versionId character varying NOT NULL,
  workflowId character varying NOT NULL,
  authors character varying NOT NULL,
  createdAt timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  updatedAt timestamp with time zone NOT NULL DEFAULT CURRENT_TIMESTAMP(3),
  nodes json NOT NULL,
  connections json NOT NULL,
  CONSTRAINT workflow_history_pkey PRIMARY KEY (versionId),
  CONSTRAINT FK_1e31657f5fe46816c34be7c1b4b FOREIGN KEY (workflowId) REFERENCES public.workflow_entity(id)
);
CREATE TABLE public.workflow_statistics (
  count integer DEFAULT 0,
  latestEvent timestamp with time zone,
  name character varying NOT NULL,
  workflowId character varying NOT NULL,
  rootCount integer DEFAULT 0,
  CONSTRAINT workflow_statistics_pkey PRIMARY KEY (workflowId, name),
  CONSTRAINT fk_workflow_statistics_workflow_id FOREIGN KEY (workflowId) REFERENCES public.workflow_entity(id)
);
CREATE TABLE public.workflows_tags (
  workflowId character varying NOT NULL,
  tagId character varying NOT NULL,
  CONSTRAINT workflows_tags_pkey PRIMARY KEY (tagId, workflowId),
  CONSTRAINT fk_workflows_tags_tag_id FOREIGN KEY (tagId) REFERENCES public.tag_entity(id),
  CONSTRAINT fk_workflows_tags_workflow_id FOREIGN KEY (workflowId) REFERENCES public.workflow_entity(id)
);