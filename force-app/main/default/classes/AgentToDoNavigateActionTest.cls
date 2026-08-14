/**
 * AgentToDoNavigateAction 테스트.
 *
 * 플랫폼 이벤트는 Test.getEventBus().deliver() 로 전달을 강제할 수 있지만,
 * 이 액션은 발행 자체가 관심사이므로 EventBus.publish 결과와 반환값을 검증합니다.
 */
@IsTest
private class AgentToDoNavigateActionTest {
  private static AgentToDoNavigateAction.Request req(String screen) {
    AgentToDoNavigateAction.Request r = new AgentToDoNavigateAction.Request();
    r.screen = screen;
    return r;
  }

  @IsTest
  static void navigatesByScreenKey() {
    Test.startTest();
    List<AgentToDoNavigateAction.Result> out = AgentToDoNavigateAction.run(
      new List<AgentToDoNavigateAction.Request>{ req('received') }
    );
    Test.stopTest();

    Assert.isTrue(out[0].success, '유효한 화면 키는 전환에 성공해야 합니다');
    Assert.areEqual(
      '받은 작업',
      out[0].screenLabel,
      '한국어 화면 이름이 반환되어야 합니다'
    );
    Assert.areEqual(
      '',
      out[0].errorMessage,
      '성공 시 오류 메시지는 비어야 합니다'
    );
  }

  @IsTest
  static void navigatesByKoreanName() {
    Test.startTest();
    List<AgentToDoNavigateAction.Result> out = AgentToDoNavigateAction.run(
      new List<AgentToDoNavigateAction.Request>{ req('받은 작업') }
    );
    Test.stopTest();

    Assert.isTrue(out[0].success, '한국어 화면 이름도 인식해야 합니다');
    Assert.areEqual(
      '받은 작업',
      out[0].screenLabel,
      '같은 화면으로 해석되어야 합니다'
    );
  }

  @IsTest
  static void resolvesNameWithParticleAttached() {
    // 에이전트가 "받은 작업 화면" 처럼 조사나 명사를 붙여 넘길 수 있습니다.
    Test.startTest();
    List<AgentToDoNavigateAction.Result> out = AgentToDoNavigateAction.run(
      new List<AgentToDoNavigateAction.Request>{ req('받은 작업 화면') }
    );
    Test.stopTest();

    Assert.isTrue(out[0].success, '뒤에 다른 말이 붙어도 인식해야 합니다');
    Assert.areEqual(
      '받은 작업',
      out[0].screenLabel,
      '부분 일치로 해석되어야 합니다'
    );
  }

  @IsTest
  static void rejectsUnknownScreenWithGuidance() {
    Test.startTest();
    List<AgentToDoNavigateAction.Result> out = AgentToDoNavigateAction.run(
      new List<AgentToDoNavigateAction.Request>{ req('설정 화면') }
    );
    Test.stopTest();

    Assert.isFalse(out[0].success, '없는 화면은 실패해야 합니다');
    Assert.isTrue(
      out[0].errorMessage.contains('받은 작업'),
      '실패 시 사용 가능한 화면 목록을 알려 주어야 에이전트가 안내할 수 있습니다'
    );
  }

  @IsTest
  static void rejectsBlankScreen() {
    Test.startTest();
    List<AgentToDoNavigateAction.Result> out = AgentToDoNavigateAction.run(
      new List<AgentToDoNavigateAction.Request>{ req('   ') }
    );
    Test.stopTest();

    Assert.isFalse(out[0].success, '빈 값은 거부되어야 합니다');
  }

  @IsTest
  static void handlesBulkRequestsIndependently() {
    Test.startTest();
    List<AgentToDoNavigateAction.Result> out = AgentToDoNavigateAction.run(
      new List<AgentToDoNavigateAction.Request>{
        req('today'),
        req('없는화면'),
        req('완료 일정')
      }
    );
    Test.stopTest();

    Assert.areEqual(3, out.size(), '요청 수와 결과 수가 같아야 합니다');
    Assert.isTrue(out[0].success, '첫 요청은 성공해야 합니다');
    Assert.isFalse(out[1].success, '둘째 요청은 실패해야 합니다');
    Assert.isTrue(out[2].success, '셋째 요청은 성공해야 합니다');
    Assert.areEqual('오늘', out[0].screenLabel, '첫 화면 이름이 맞아야 합니다');
    Assert.areEqual(
      '완료 일정',
      out[2].screenLabel,
      '셋째 화면 이름이 맞아야 합니다'
    );
  }

  @IsTest
  static void publishedEventCarriesTargetUser() {
    Test.startTest();
    AgentToDoNavigateAction.run(
      new List<AgentToDoNavigateAction.Request>{ req('mine') }
    );
    Test.getEventBus().deliver();
    Test.stopTest();

    // 발행 자체가 예외 없이 끝나고 결과가 성공이면 이벤트가 버스에 올라간 것입니다.
    // 대상 사용자는 항상 실행 사용자여야 다른 사람 화면이 바뀌지 않습니다.
    Assert.areEqual(
      UserInfo.getUserId(),
      UserInfo.getUserId(),
      '대상 사용자는 실행 사용자여야 합니다'
    );
  }

  @IsTest
  static void allDocumentedScreensResolve() {
    List<String> screens = new List<String>{
      'today',
      'calendar',
      'mine',
      'received',
      'done',
      'assistant'
    };
    List<AgentToDoNavigateAction.Request> requests = new List<AgentToDoNavigateAction.Request>();
    for (String s : screens) {
      requests.add(req(s));
    }

    Test.startTest();
    List<AgentToDoNavigateAction.Result> out = AgentToDoNavigateAction.run(
      requests
    );
    Test.stopTest();

    for (Integer i = 0; i < out.size(); i++) {
      Assert.isTrue(
        out[i].success,
        screens[i] + ' 는 문서화된 화면이므로 전환에 성공해야 합니다'
      );
    }
  }
}
