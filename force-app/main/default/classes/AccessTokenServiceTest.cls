@isTest
private class AccessTokenServiceTest {

    @isTest
    static void generatesUniqueTokenAndSavesToLead() {
        Lead l = new Lead(LastName = '테스트', FirstName = '토큰', Company = '개인 고객', Email = 'token-test@example.com');
        insert l;

        Test.startTest();
        List<String> tokens = AccessTokenService.generateTokens(new List<Id>{ l.Id });
        Test.stopTest();

        System.assertEquals(1, tokens.size());
        System.assertEquals(32, tokens[0].length());

        Lead updated = [SELECT AccessToken__c, AccessTokenExpiresAt__c FROM Lead WHERE Id = :l.Id];
        System.assertEquals(tokens[0], updated.AccessToken__c);
        System.assert(updated.AccessTokenExpiresAt__c > System.now().addDays(6));
        System.assert(updated.AccessTokenExpiresAt__c <= System.now().addDays(7));
    }
}
