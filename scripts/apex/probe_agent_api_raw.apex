// Agent API 메시지 응답 원문 확인 — 액션 실행 정보(result)가 오는지 보기 위함.
// 실행: sf apex run -o s-test -f scripts/apex/probe_agent_api_raw.apex

String AGENT_ID = '0Xxg5000001Q3o5CAC';
String MY_DOMAIN = 'https://orgfarm-8ce4f644f3-dev-ed.develop.my.salesforce.com';
String BASE = 'callout:AgentToDo_Agent_API/einstein/ai-agent/v1';

HttpRequest start = new HttpRequest();
start.setEndpoint(BASE + '/agents/' + AGENT_ID + '/sessions');
start.setMethod('POST');
start.setHeader('Content-Type', 'application/json');
start.setTimeout(120000);
start.setBody(
    JSON.serialize(
        new Map<String, Object>{
            'externalSessionKey' => String.valueOf(Crypto.getRandomLong()) + '-raw',
            'instanceConfig' => new Map<String, Object>{ 'endpoint' => MY_DOMAIN },
            'streamingCapabilities' => new Map<String, Object>{ 'chunkTypes' => new List<String>{ 'Text' } },
            'bypassUser' => false
        }
    )
);
HttpResponse startRes = new Http().send(start);
Map<String, Object> session = (Map<String, Object>) JSON.deserializeUntyped(startRes.getBody());
String sessionId = (String) session.get('sessionId');

HttpRequest msg = new HttpRequest();
msg.setEndpoint(BASE + '/sessions/' + sessionId + '/messages');
msg.setMethod('POST');
msg.setHeader('Content-Type', 'application/json');
msg.setTimeout(120000);
msg.setBody(
    JSON.serialize(
        new Map<String, Object>{
            'message' => new Map<String, Object>{
                'sequenceId' => 1,
                'type' => 'Text',
                'text' => '오늘 일정을 브리핑해줘'
            }
        }
    )
);
HttpResponse msgRes = new Http().send(msg);

String rb = msgRes.getBody();
System.debug('LEN=' + rb.length());
Integer chunk = 300;
for (Integer i = 0; i < rb.length(); i += chunk) {
    System.debug('RAW>' + rb.substring(i, Math.min(i + chunk, rb.length())));
}

HttpRequest done = new HttpRequest();
done.setEndpoint(BASE + '/sessions/' + sessionId);
done.setMethod('DELETE');
done.setHeader('x-session-end-reason', 'UserRequest');
done.setTimeout(60000);
new Http().send(done);
