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
            AccessToken__c = 'test-token-123456789012345678901',
            AccessTokenExpiresAt__c = System.now().addDays(1)
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
    static void getRecommendationsRejectsExpiredToken() {
        Lead l = [SELECT Id FROM Lead WHERE AccessToken__c = 'test-token-123456789012345678901'];
        l.AccessTokenExpiresAt__c = System.now().addMinutes(-1);
        update l;

        Boolean threw = false;
        try {
            VenuePublicController.getRecommendations('test-token-123456789012345678901');
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, '만료된 링크는 추천 결과를 반환하면 안 된다.');
    }

    @isTest
    static void confirmRejectsRecommendationFromAnotherLead() {
        Lead anotherLead = new Lead(
            LastName = '다른고객',
            Company = '개인 고객',
            AccessToken__c = 'another-token-12345678901234567',
            AccessTokenExpiresAt__c = System.now().addDays(1)
        );
        insert anotherLead;
        Recommendation__c existing = [SELECT Venue__c FROM Recommendation__c LIMIT 1];
        Recommendation__c anotherRecommendation = new Recommendation__c(
            Lead__c = anotherLead.Id,
            Venue__c = existing.Venue__c,
            VenueNameSnapshot__c = '다른 고객의 추천',
            RecommendationType__c = '장소'
        );
        insert anotherRecommendation;

        Boolean threw = false;
        try {
            VenuePublicController.submitDecision(
                'test-token-123456789012345678901',
                'CONFIRM',
                anotherRecommendation.Id
            );
        } catch (AuraHandledException e) {
            threw = true;
        }
        System.assert(threw, '다른 Lead의 추천은 선택할 수 없어야 한다.');
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
