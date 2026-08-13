# Phase 3e — Agent API 연동을 위한 수동 설정

> ## ⚠️ 진행 중 확인된 두 가지 제약 (2026-08-13)
>
> **1. Agent API 는 "Agentforce (Default)" 유형 에이전트를 지원하지 않습니다.**
> 공식 제약 문서: _"The Agent API isn't supported for agents of type 'Agentforce (Default)'."_
> `AgentforceEmployeeAgent` = `BotDefinition.Type = InternalCopilot` = "Agentforce (Default)" 입니다.
> 이 조합으로 세션을 시작하면 `412 Precondition Failed: Unable to load agent config: Invalid Config`
> 가 반환됩니다. → `AgentforceServiceAgent` 로 만들어야 합니다.
>
> **2. 게시된 에이전트의 `agent_type` 은 변경할 수 없습니다.**
> 플랫폼 오류: _"You can't modify 'agent_type' after first version is published."_
> 유형을 바꾸려면 새 `developer_name` 으로 새 에이전트를 만들어야 합니다.
>
> **1-보정. 유형 전환만으로는 412 가 해결되지 않았습니다.**
> `AgentforceServiceAgent`(`BotDefinition.Type = ExternalCopilot`) 로 새로 만들어
> 게시·활성화까지 마쳤는데도 동일한 412 `Invalid Config` 가 반환됩니다.
> 남은 원인은 **에이전트에 Connection 이 하나도 없다는 것**으로 보입니다
> (Agentforce Builder → Explorer → Connections 가 비어 있음).
> `.agent` 파일에도 `connection` 블록이 없습니다.
>
> **3. 이 PC 의 네트워크에서 `test.api.salesforce.com` / `dev.api.salesforce.com` 이 차단돼 있습니다.**
> `sf agent publish` 는 신규 에이전트 생성 시 `api.salesforce.com` 에 POST 한 뒤
> 404 가 나면 위 두 호스트로 폴백하는데, 차단 때문에 연결 타임아웃으로 죽습니다.
> `api.salesforce.com` 자체는 정상 접근됩니다 (HTTP 404 응답 확인).

AgentToDo LWC 앱이 Agentforce 에이전트를 호출하려면 org에 OAuth 자격 증명이 있어야 합니다.
이 문서의 1~2단계는 **Setup UI에서만 가능한 작업**이라 직접 하셔야 합니다.
3단계부터는 자동으로 처리합니다.

## 이 시점의 확정된 값

| 항목                              | 값                                                                                  |
| --------------------------------- | ----------------------------------------------------------------------------------- |
| 에이전트 API 이름                 | `AgentToDo_Assistant`                                                               |
| **AGENT_ID** (`BotDefinition.Id`) | `0Xxg5000001Q00bCAC`                                                                |
| 버전 / 상태                       | v1 / **Active**                                                                     |
| My Domain URL                     | `https://orgfarm-8ce4f644f3-dev-ed.develop.my.salesforce.com`                       |
| 토큰 엔드포인트                   | `https://orgfarm-8ce4f644f3-dev-ed.develop.my.salesforce.com/services/oauth2/token` |
| Agent API 호스트                  | `https://api.salesforce.com`                                                        |
| Run As 사용자                     | `ktnam.eafc6020fb96@agentforce.com` (남 경태)                                       |

---

## 1단계 — External Client App 생성 (수동)

**Setup → 빠른 찾기에 `External Client App` → External Client Apps Manager → New External Client App**

기본 정보:

| 필드                     | 값                    |
| ------------------------ | --------------------- |
| External Client App Name | `AgentToDo Agent API` |
| API Name                 | `AgentToDo_Agent_API` |
| Contact Email            | `ktnam@i2max.co.kr`   |
| Distribution State       | `Local`               |

**API (Enable OAuth Settings)** 섹션:

1. **Enable OAuth** 체크
2. Callback URL — 클라이언트 자격 증명 흐름에서는 쓰이지 않지만 입력이 필요합니다:
   `https://orgfarm-8ce4f644f3-dev-ed.develop.my.salesforce.com/services/oauth2/callback`
3. **OAuth Scopes** — 다음 두 개를 선택합니다:
   - `Access the Salesforce API Platform (sfap_api)` ← **Agent API 호출에 반드시 필요**
   - `Manage user data via APIs (api)`
4. **Enable Client Credentials Flow** 체크
5. **Issue JSON Web Token (JWT)-based access tokens** 체크

저장합니다.

## 2단계 — Run As 사용자 지정과 자격 증명 확보 (수동)

방금 만든 앱을 열고:

1. **Policies 탭 → Edit → OAuth Policies → App Authorization**
   - **Run As** = `남 경태 (ktnam.eafc6020fb96@agentforce.com)`
   - 저장
2. **Settings 탭 → OAuth Settings → Consumer Key and Secret** 버튼
   - **Consumer Key**와 **Consumer Secret**을 복사해 둡니다

> ⚠️ Run As 사용자가 곧 에이전트의 실행 사용자입니다.
> Agent Spec에 적어둔 대로, 이 사용자가 소유한 일정만 에이전트가 보게 됩니다.

---

## 3단계 이후 — 자동 처리

Consumer Key와 Secret을 알려 주시면 다음을 진행합니다:

| 단계 | 내용                                                                                              |
| ---- | ------------------------------------------------------------------------------------------------- |
| 3f   | External Credential(OAuth 2.0 · Client Credentials) + Named Credential `AgentToDo_Agent_API` 등록 |
| 3g   | `AgentToDoAgentService` Apex 작성 — 세션 시작 / 메시지 전송 / 세션 종료                           |
| 3g   | `agentAssistantDrawer` LWC 를 실제 에이전트에 배선하고 Action 결과 카드 렌더링                    |

Secret은 메타데이터로 배포하지 않고 Setup UI의 External Credential 주체(Principal)에
직접 입력하는 방식으로 처리합니다. 소스 트리에 비밀값이 남지 않습니다.

---

## 호출 계약 (참고)

```
POST   https://api.salesforce.com/einstein/ai-agent/v1/agents/0Xxg5000001Q00bCAC/sessions
POST   https://api.salesforce.com/einstein/ai-agent/v1/sessions/{SESSION_ID}/messages
DELETE https://api.salesforce.com/einstein/ai-agent/v1/sessions/{SESSION_ID}
```

세션 시작 본문:

```json
{
  "externalSessionKey": "<UUID>",
  "instanceConfig": {
    "endpoint": "https://orgfarm-8ce4f644f3-dev-ed.develop.my.salesforce.com"
  },
  "streamingCapabilities": { "chunkTypes": ["Text"] },
  "bypassUser": false
}
```

### `bypassUser`를 false 로 두는 이유

게시 직후 `sf agent preview start --api-name AgentToDo_Assistant` 를 실행했을 때
Agent API가 다음과 같이 거부했습니다:

```
Bad Request: Invalid user ID provided on start session
POST v6.0.0/agents/0Xxg5000001Q00bCAC/sessions
```

`AgentforceEmployeeAgent` 에는 `default_agent_user`(에이전트 전용 실행 사용자)가 없습니다.
따라서 `bypassUser: true`(에이전트 전용 사용자 사용)로 두면 지정할 사용자가 없어 실패합니다.
`false` 로 두어야 **토큰에 묶인 Run As 사용자**가 실행 주체가 됩니다.

스트리밍 엔드포인트(`/messages/stream`, SSE)는 Apex 콜아웃에서 다루기 어려워 동기 엔드포인트를 씁니다.
