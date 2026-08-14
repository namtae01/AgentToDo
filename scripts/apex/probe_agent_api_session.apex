// Agent API 인증 체인 검증.
// 실행: sf apex run -o s-test -f scripts/apex/probe_agent_api_session.apex
//
// 검증 대상:
//   Named Credential → External Credential → External Client App(client credentials)
//   → 토큰 발급 → https://api.salesforce.com 로 세션 시작
//
// 성공하면 sessionId 가 돌아옵니다. 실패하면 상태 코드와 본문으로 원인을 판정합니다.

String AGENT_ID = '0Xxg5000001Q3o5CAC';  // AgentToDo_Svc_Assistant (ExternalCopilot)
String MY_DOMAIN = 'https://orgfarm-8ce4f644f3-dev-ed.develop.my.salesforce.com';

// externalSessionKey 는 호출자가 만드는 임의의 고유 키입니다.
String sessionKey = String.valueOf(Crypto.getRandomLong()).replace('-', '') + '-probe';

Map<String, Object> body = new Map<String, Object>{
    'externalSessionKey' => sessionKey,
    'instanceConfig' => new Map<String, Object>{ 'endpoint' => MY_DOMAIN },
    'streamingCapabilities' => new Map<String, Object>{ 'chunkTypes' => new List<String>{ 'Text' } },
    // 직원용 에이전트에는 전용 실행 사용자가 없으므로 false 여야 합니다.
    // true 로 두면 "Invalid user ID provided on start session" 으로 거부됩니다.
    'bypassUser' => false
};

HttpRequest req = new HttpRequest();
req.setEndpoint('callout:AgentToDo_Agent_API/einstein/ai-agent/v1/agents/' + AGENT_ID + '/sessions');
req.setMethod('POST');
req.setHeader('Content-Type', 'application/json');
req.setHeader('Accept', 'application/json');
req.setTimeout(120000);
req.setBody(JSON.serialize(body));

System.debug('요청 → ' + req.getEndpoint());

HttpResponse res;
try {
    res = new Http().send(req);
} catch (Exception e) {
    System.debug('콜아웃 예외: ' + e.getTypeName() + ' — ' + e.getMessage());
    return;
}

System.debug('상태: ' + res.getStatusCode() + ' ' + res.getStatus());
String responseBody = res.getBody();
System.debug('본문: ' + (responseBody != null && responseBody.length() > 1500 ? responseBody.substring(0, 1500) : responseBody));

if (res.getStatusCode() == 200) {
    Map<String, Object> parsed = (Map<String, Object>) JSON.deserializeUntyped(responseBody);
    System.debug('✅ 세션 시작 성공. sessionId = ' + parsed.get('sessionId'));

    // 열어 둔 세션은 바로 닫습니다.
    String sid = (String) parsed.get('sessionId');
    if (String.isNotBlank(sid)) {
        HttpRequest del = new HttpRequest();
        del.setEndpoint('callout:AgentToDo_Agent_API/einstein/ai-agent/v1/sessions/' + sid);
        del.setMethod('DELETE');
        del.setHeader('x-session-end-reason', 'UserRequest');
        del.setTimeout(60000);
        HttpResponse delRes = new Http().send(del);
        System.debug('세션 종료 상태: ' + delRes.getStatusCode());
    }
} else if (res.getStatusCode() == 401) {
    System.debug('❌ 401 — 토큰 발급 또는 주체 접근 권한 문제입니다.');
} else {
    System.debug('❌ 예상치 못한 응답입니다.');
}
