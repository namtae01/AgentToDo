// 412 "Invalid Config" 원인 좁히기.
// instanceConfig.endpoint 값이 플랫폼 기대치와 다르면 에이전트 설정 로드가 실패할 수 있습니다.
// 여러 후보를 순서대로 시도해 어느 값이 통하는지 확인합니다.
// 실행: sf apex run -o s-test -f scripts/apex/probe_agent_api_endpoints.apex

String AGENT_ID = '0Xxg5000001Q3o5CAC';

List<String> endpoints = new List<String>{
    'https://orgfarm-8ce4f644f3-dev-ed.develop.my.salesforce.com',
    'https://orgfarm-8ce4f644f3-dev-ed.develop.lightning.force.com',
    URL.getOrgDomainUrl().toExternalForm(),
    ''
};

for (String ep : endpoints) {
    Map<String, Object> instanceConfig = new Map<String, Object>{ 'endpoint' => ep };
    Map<String, Object> body = new Map<String, Object>{
        'externalSessionKey' => String.valueOf(Crypto.getRandomLong()) + '-ep',
        'instanceConfig' => instanceConfig,
        'streamingCapabilities' => new Map<String, Object>{ 'chunkTypes' => new List<String>{ 'Text' } },
        'bypassUser' => false
    };

    HttpRequest req = new HttpRequest();
    req.setEndpoint('callout:AgentToDo_Agent_API/einstein/ai-agent/v1/agents/' + AGENT_ID + '/sessions');
    req.setMethod('POST');
    req.setHeader('Content-Type', 'application/json');
    req.setHeader('Accept', 'application/json');
    req.setTimeout(60000);
    req.setBody(JSON.serialize(body));

    try {
        HttpResponse res = new Http().send(req);
        String snippet = res.getBody();
        if (snippet != null && snippet.length() > 200) {
            snippet = snippet.substring(0, 200);
        }
        System.debug('endpoint=[' + ep + '] → ' + res.getStatusCode() + ' | ' + snippet);
    } catch (Exception e) {
        System.debug('endpoint=[' + ep + '] → 예외: ' + e.getMessage());
    }
}

// bypassUser=true 도 한 번 확인합니다 (서비스 에이전트는 전용 사용자가 있으므로 가능할 수 있음)
Map<String, Object> body2 = new Map<String, Object>{
    'externalSessionKey' => String.valueOf(Crypto.getRandomLong()) + '-bypass',
    'instanceConfig' => new Map<String, Object>{
        'endpoint' => 'https://orgfarm-8ce4f644f3-dev-ed.develop.my.salesforce.com'
    },
    'streamingCapabilities' => new Map<String, Object>{ 'chunkTypes' => new List<String>{ 'Text' } },
    'bypassUser' => true
};
HttpRequest req2 = new HttpRequest();
req2.setEndpoint('callout:AgentToDo_Agent_API/einstein/ai-agent/v1/agents/' + AGENT_ID + '/sessions');
req2.setMethod('POST');
req2.setHeader('Content-Type', 'application/json');
req2.setHeader('Accept', 'application/json');
req2.setTimeout(60000);
req2.setBody(JSON.serialize(body2));
try {
    HttpResponse res2 = new Http().send(req2);
    String s2 = res2.getBody();
    if (s2 != null && s2.length() > 200) {
        s2 = s2.substring(0, 200);
    }
    System.debug('bypassUser=true → ' + res2.getStatusCode() + ' | ' + s2);
} catch (Exception e) {
    System.debug('bypassUser=true → 예외: ' + e.getMessage());
}
