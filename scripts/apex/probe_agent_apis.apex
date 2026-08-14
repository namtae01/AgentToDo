// org에서 실제로 사용 가능한 Agentforce 관련 Apex 클래스를 탐지합니다.
// Type.forName 은 없는 클래스에 대해 컴파일 오류 대신 null 을 돌려주므로
// 여러 후보를 한 번에 안전하게 확인할 수 있습니다.
// 실행: sf apex run -o s-test -f scripts/apex/probe_agent_apis.apex

Map<String, List<String>> candidates = new Map<String, List<String>>{
    'ConnectApi' => new List<String>{
        'AgentInteraction',
        'EinsteinLlm',
        'BotVersionActivation',
        'Bots',
        'AiAgent',
        'AgentApi',
        'EinsteinAgent'
    },
    'System' => new List<String>{ 'Http', 'HttpRequest' },
    'Auth' => new List<String>{ 'SessionManagement' }
};

for (String ns : candidates.keySet()) {
    for (String cls : candidates.get(ns)) {
        Type t = Type.forName(ns, cls);
        System.debug('PROBE ' + ns + '.' + cls + ' => ' + (t == null ? 'NOT FOUND' : 'AVAILABLE'));
    }
}

// 조직에 등록된 Named Credential / External Credential 확인
System.debug('NamedCredential 수: ' + [SELECT COUNT() FROM NamedCredential]);

// 현재 사용자가 접근 가능한 Agentforce 에이전트(BotDefinition) 확인
for (BotDefinition b : [SELECT DeveloperName, MasterLabel, Type FROM BotDefinition LIMIT 20]) {
    System.debug('BOT ' + b.DeveloperName + ' | ' + b.MasterLabel + ' | ' + b.Type);
}
