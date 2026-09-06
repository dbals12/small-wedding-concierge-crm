@isTest
private class VenuePublicControllerTest {

    @TestSetup
    static void setup() {
        VenueType__c vt = new VenueType__c(Name = '레스토랑');
        insert vt;

        Venue__c v = new Venue__c(
            Name = '테스트 지도 장소',
            District__c = '마포구',
            MaxCapacity__c = 45,
            FoodRating__c = 4.5,
            PricePerPerson__c = 55000,
            StationWalkMin__c = 5,
            VenueType__c = vt.Id,
            Coordinates__Latitude__s = 37.5563,
            Coordinates__Longitude__s = 126.9236
        );
        insert v;

        Lead l = new Lead(
            LastName = '테스트',
            FirstName = '지도',
            Company = '개인 고객',
            Email = 'map-test@example.com',
            AccessToken__c = 'test-token-123456789012345678901'
        );
        insert l;

        insert new Recommendation__c(
            Lead__c = l.Id,
            Venue__c = v.Id,
            VenueNameSnapshot__c = v.Name,
            MatchScore__c = 100,
            Rank__c = 1,
            ReasonText__c = '테스트 추천 이유',
            RecommendationType__c = '장소'
        );
    }

    @isTest
    static void getRecommendationsReturnsOnlyMatchingLead() {
        Test.startTest();
        List<VenuePublicController.VenueRecommendationWrapper> results =
            VenuePublicController.getRecommendations('test-token-123456789012345678901');
        Test.stopTest();

        System.assertEquals(1, results.size());
        System.assertEquals('테스트 지도 장소', results[0].venueName);
        System.assertEquals(37.5563, results[0].latitude);
    }

    @isTest
    static void getRecommendationsThrowsForInvalidToken() {
        Boolean threw = false;
        try {
            VenuePublicController.getRecommendations('nonexistent-token');
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw);
    }

    @isTest
    static void submitDecisionConfirmSetsVenueAndStatus() {
        Recommendation__c rec = [SELECT Id FROM Recommendation__c LIMIT 1];

        Test.startTest();
        String result = VenuePublicController.submitDecision('test-token-123456789012345678901', 'CONFIRM', rec.Id);
        Test.stopTest();

        System.assertEquals('OK', result);
        Lead l = [SELECT Status, SelectedVenueFromWeb__c FROM Lead WHERE AccessToken__c = 'test-token-123456789012345678901'];
        System.assertEquals('결제 대기', l.Status);
        System.assertNotEquals(null, l.SelectedVenueFromWeb__c);

        // 팔로업 Task는 이메일 발송 성공 여부(조직의 일일 발송 한도 등 외부 요인)와 무관하게 항상 생성된다.
        // 이메일이 성공하면 setSaveAsActivity로 로그성 Task가 하나 더 남아 2개가 될 수도 있다.
        List<Task> tasks = [SELECT Id FROM Task WHERE WhoId = :l.Id];
        System.assert(tasks.size() >= 1);
    }

    @isTest
    static void submitDecisionVisitSetsStatus() {
        Test.startTest();
        VenuePublicController.submitDecision('test-token-123456789012345678901', 'VISIT', null);
        Test.stopTest();

        Lead l = [SELECT Status FROM Lead WHERE AccessToken__c = 'test-token-123456789012345678901'];
        System.assertEquals('답사 예정', l.Status);
    }
}
