// Agent API 왕복 검증: 세션 시작 → 메시지 전송 → 세션 종료.
// LWC 연동(3g)에서 Apex 서비스가 하게 될 동작을 그대로 예행합니다.
// 실행: sf apex run -o s-test -f scripts/apex/probe_agent_api_message.apex

String AGENT_ID = '0Xxg5000001Q3o5CAC';
String MY_DOMAIN = 'https://orgfarm-8ce4f644f3-dev-ed.develop.my.salesforce.com';
String BASE = 'callout:AgentToDo_Agent_API/einstein/ai-agent/v1';

// ── 1. 세션 시작 ────────────────────────────────────────────────
HttpRequest start = new HttpRequest();
start.setEndpoint(BASE + '/agents/' + AGENT_ID + '/sessions');
start.setMethod('POST');
start.setHeader('Content-Type', 'application/json');
start.setHeader('Accept', 'application/json');
start.setTimeout(120000);
start.setBody(
    JSON.serialize(
        new Map<String, Object>{
            'externalSessionKey' => String.valueOf(Crypto.getRandomLong()) + '-msg',
            'instanceConfig' => new Map<String, Object>{ 'endpoint' => MY_DOMAIN },
            'streamingCapabilities' => new Map<String, Object>{ 'chunkTypes' => new List<String>{ 'Text' } },
            'bypassUser' => false
        }
    )
);

HttpResponse startRes = new Http().send(start);
if (startRes.getStatusCode() != 200) {
    System.debug('세션 시작 실패: ' + startRes.getStatusCode() + ' ' + startRes.getBody());
    return;
}
Map<String, Object> session = (Map<String, Object>) JSON.deserializeUntyped(startRes.getBody());
String sessionId = (String) session.get('sessionId');
System.debug('세션 시작: ' + sessionId);

// ── 2. 메시지 전송 ──────────────────────────────────────────────
String utterance = '오늘 일정을 브리핑해줘';

HttpRequest msg = new HttpRequest();
msg.setEndpoint(BASE + '/sessions/' + sessionId + '/messages');
msg.setMethod('POST');
msg.setHeader('Content-Type', 'application/json');
msg.setHeader('Accept', 'application/json');
msg.setTimeout(120000);
msg.setBody(
    JSON.serialize(
        new Map<String, Object>{
            'message' => new Map<String, Object>{ 'sequenceId' => 1, 'type' => 'Text', 'text' => utterance }
        }
    )
);

HttpResponse msgRes = new Http().send(msg);
System.debug('메시지 상태: ' + msgRes.getStatusCode());

if (msgRes.getStatusCode() == 200) {
    Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(msgRes.getBody());
    List<Object> messages = (List<Object>) parsed.get('messages');
    for (Object o : messages) {
        Map<String, Object> m = (Map<String, Object>) o;
        System.debug('── 에이전트 응답 ──');
        System.debug(m.get('message'));

        // 실행된 Agent Action 정보 — LWC 가 결과 카드로 그릴 데이터입니다.
        Object result = m.get('result');
        if (result != null && String.valueOf(result) != '()') {
            System.debug('result(액션 실행 정보): ' + JSON.serialize(result));
        }
    }
} else {
    System.debug('본문: ' + msgRes.getBody());
}

// ── 3. 세션 종료 ────────────────────────────────────────────────
HttpRequest done = new HttpRequest();
done.setEndpoint(BASE + '/sessions/' + sessionId);
done.setMethod('DELETE');
done.setHeader('x-session-end-reason', 'UserRequest');
done.setTimeout(60000);
System.debug('세션 종료: ' + new Http().send(done).getStatusCode());
