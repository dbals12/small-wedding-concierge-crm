@isTest
private class LeadConversionServiceTest {

    @TestSetup
    static void setup() {
        VenueType__c vt = new VenueType__c(Name = '레스토랑');
        insert vt;

        Venue__c v = new Venue__c(
            Name = '테스트 확정 장소',
            District__c = '마포구',
            MaxCapacity__c = 45,
            FoodRating__c = 4.5,
            PricePerPerson__c = 55000,
            StationWalkMin__c = 5,
            VenueType__c = vt.Id
        );
        insert v;
    }

    @isTest
    static void convertsWithCorrectRecordTypeWhenPaymentConfirmed() {
        Venue__c v = [SELECT Id FROM Venue__c LIMIT 1];
        Lead l = new Lead(
            LastName = '테스트',
            FirstName = '전환검증',
            Company = '개인 고객',
            Email = 'convert-test@example.com',
            SelectedPackage__c = '베이직',
            PaymentConfirmed__c = true,
            SelectedVenueFromWeb__c = v.Id
        );
        insert l;

        Test.startTest();
        List<String> results = LeadConversionService.convertLeadsWithPackage(new List<Id>{ l.Id });
        Test.stopTest();

        System.assert(results[0].startsWith('전환 성공'), '결제 확인+장소 확정 시 전환에 성공해야 한다: ' + results[0]);

        Lead converted = [SELECT IsConverted, ConvertedOpportunityId FROM Lead WHERE Id = :l.Id];
        System.assert(converted.IsConverted);

        Opportunity opp = [SELECT RecordType.DeveloperName, StageName, ConfirmedVenue__c FROM Opportunity WHERE Id = :converted.ConvertedOpportunityId];
        System.assertEquals('Basic_Package', opp.RecordType.DeveloperName);
        System.assertEquals('장소 확정', opp.StageName);
        System.assertEquals(v.Id, opp.ConfirmedVenue__c);
    }

    @isTest
    static void blocksConversionWhenPaymentNotConfirmed() {
        Venue__c v = [SELECT Id FROM Venue__c LIMIT 1];
        Lead l = new Lead(
            LastName = '테스트',
            FirstName = '결제전',
            Company = '개인 고객',
            Email = 'convert-nopay@example.com',
            SelectedPackage__c = '스탠다드',
            PaymentConfirmed__c = false,
            SelectedVenueFromWeb__c = v.Id
        );
        insert l;

        Test.startTest();
        List<String> results = LeadConversionService.convertLeadsWithPackage(new List<Id>{ l.Id });
        Test.stopTest();

        System.assert(results[0].startsWith('전환 실패'), '결제 미확인 시 전환이 막혀야 한다');

        Lead notConverted = [SELECT IsConverted FROM Lead WHERE Id = :l.Id];
        System.assert(!notConverted.IsConverted);
    }

    @isTest
    static void blocksConversionWhenVenueNotSelected() {
        Lead l = new Lead(
            LastName = '테스트',
            FirstName = '장소미정',
            Company = '개인 고객',
            Email = 'convert-novenue@example.com',
            SelectedPackage__c = '프리미엄',
            PaymentConfirmed__c = true
        );
        insert l;

        Test.startTest();
        List<String> results = LeadConversionService.convertLeadsWithPackage(new List<Id>{ l.Id });
        Test.stopTest();

        System.assert(results[0].startsWith('전환 실패'), '확정 장소가 없으면 전환이 막혀야 한다');
    }
}
