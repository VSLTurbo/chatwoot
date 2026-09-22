# Tickets internos da Cakto (código nosso, núcleo MIT)

Decisão do Ítalo (22/09/2026): a Cakto sobe ticket entre áreas (Suporte, Suporte TI,
Compliance, Comercial). O Chatwoot só sabe abrir conversa a partir de um cliente; este
módulo cria um **ticket interno**: uma conversa aberta por um atendente, para uma
equipe, sem cliente por trás (ou ligada a uma conversa de cliente). Prefixo `cakto_`,
nada de `enterprise/`. Depende do módulo de SLA (`docs/cakto/sla.md`): o ticket
interno nasce numa caixa própria e herda a política de SLA que cobrir essa caixa.

## Regras

- Existe **uma caixa por conta** chamada `Tickets internos`, canal `Channel::Api`
  (sem webhook), criada sob demanda no primeiro ticket (`CaktoTickets::SetupService`).
  Identificação: `inbox.name == 'Tickets internos'` e `channel_type == 'Channel::Api'`.
  O setup também garante os atributos de conversa (`CustomAttributeDefinition`,
  `attribute_model: conversation_attribute`) `cakto_ticket_titulo` (texto),
  `cakto_ticket_solicitante` (texto), `cakto_ticket_seller` (texto) e
  `cakto_ticket_origem` (texto: número da conversa de cliente relacionada), para
  aparecerem no painel lateral nativo da conversa.
- O **solicitante** é o atendente logado. Ele vira o "contato" do ticket: um `Contact`
  da conta com o e-mail dele (`find_or_create` por e-mail, nome do usuário) e um
  `ContactInbox` na caixa de tickets (`source_id` = e-mail). Assim a área responde
  ao solicitante pelo próprio ticket.
- O ticket é uma `Conversation` na caixa de tickets com: `team_id` (obrigatório,
  equipe da conta), `priority` (low/medium/high/urgent, padrão medium), `status open`,
  `custom_attributes` acima preenchidos, e a primeira mensagem **incoming** do
  contato-solicitante com o conteúdo `**<título>**\n\n<descrição>`. `additional_attributes`
  recebe `{ cakto_ticket: true, solicitante_user_id: <id> }` para filtrar.
- `related_conversation_display_id` (opcional): número da conversa de cliente. Se
  existir na conta, vai para `cakto_ticket_origem` e o ticket recebe uma mensagem de
  atividade "Aberto a partir da conversa #<n>"; a conversa de origem recebe a atividade
  "Ticket interno #<n> aberto para <equipe>". Se não existir: 422.
- Feature flag `cakto_tickets` em `config/features.yml`, **anexada no fim**, com
  `column: feature_flags_ext_1`, `enabled: true`, sem `premium`.
- Atribuição automática dentro da equipe é a nativa (`team.allow_auto_assign`).
- SLA: a política que cobrir a caixa `Tickets internos` vale para o ticket (o listener
  de SLA já trata `conversation_created`). O relatório de SLA ganha `by_team`.

## API (`Api::V1::Accounts::*`, Pundit)

Só quando `Current.account.feature_enabled?('cakto_tickets')`; senão 404.

- `POST /api/v1/accounts/:account_id/cakto_tickets` — qualquer agente da conta.
  Corpo (`cakto_ticket`): `team_id`, `title`, `description`, `priority`,
  `related_conversation_display_id`, `seller`.
  Resposta 200: a conversa no jbuilder padrão de conversa
  (`app/views/api/v1/conversations/partials/_conversation.json.jbuilder`), para o
  frontend navegar por `id` (display_id). Erros de validação: 422 com
  `{ "message": "<texto em português>" }` (título e descrição obrigatórios, equipe
  inválida, conversa relacionada inexistente).
- `GET /api/v1/accounts/:account_id/cakto_tickets/setup` — devolve
  `{ "inbox_id": <id da caixa de tickets ou null>, "teams": [{id, name}] }` (cria a caixa
  se faltar; qualquer agente).
- Relatório de SLA (`GET .../cakto_sla/report`) passa a incluir
  `"by_team": [{ "team_id", "team_name", "conversations", "first_response": {…}, "resolution": {…} }]`
  com o mesmo formato de `by_inbox`.

## Backend: pontos de encaixe

- `app/builders/conversation_builder.rb` (como o Chatwoot monta conversa a partir de
  `contact_inbox` + params), `app/builders/contact_inbox_with_contact_builder.rb`,
  `app/builders/messages/message_builder.rb` (ou `Message.create!` direto com
  `message_type: :incoming, sender: contact`), `app/models/channel/api.rb`,
  `app/models/custom_attribute_definition.rb`, `Conversations::ActivityMessageJob`.
- Serviços: `CaktoTickets::SetupService` (caixa + atributos), `CaktoTickets::CreateService`
  (solicitante → contato → conversa → mensagem → atividades).
- Specs de serviço e request (`spec/services/cakto_tickets/`, `spec/controllers/api/v1/accounts/cakto_tickets_controller_spec.rb`).

## Frontend (`app/javascript/dashboard/`)

- Flag `CAKTO_TICKETS: 'cakto_tickets'` em `featureFlags.js`.
- API client `api/caktoTickets.js` (`create(payload)`, `setup()`).
- Item **"Novo ticket interno"** no `Sidebar.vue` (ícone `i-lucide-ticket-plus`), visível
  a todo agente com a flag, que abre um modal (`components-next` Dialog) com: área
  (select das equipes vindas de `GET .../cakto_tickets/setup`), título, descrição
  (textarea), prioridade (baixa/média/alta/urgente), seller (texto, opcional),
  conversa relacionada (número, opcional). Ao salvar: fecha, mostra toast e navega
  para a conversa criada (`conversation` route com `conversation_id` = display_id).
- No cabeçalho da conversa de cliente, ação **"Abrir ticket interno"** que abre o mesmo
  modal com a conversa relacionada já preenchida.
- Card da lista: quando `additional_attributes.cakto_ticket` é true, mostrar um selo
  pequeno "Ticket interno" ao lado das etiquetas (componente `CaktoTicketBadge.vue`).
- Relatório de SLA (`CaktoSlaReports.vue`): terceira tabela "Por equipe" lendo `by_team`.
- i18n `pt_BR/caktoTickets.json` e `en/caktoTickets.json` (+ `SIDEBAR.CAKTO_TICKETS`).
  Português natural, sem travessão longo.
- Testes vitest do store/modal (padrão dos vizinhos) e do selo.
